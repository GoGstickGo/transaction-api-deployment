# Runbook: Database Connection Failures

**Alert Name:** `DatabaseConnectionFailures`  
**Severity:** Critical  
**Component:** Database  

---

## 🚨 Alert Description

Database query error rate exceeds 0.1%, indicating connectivity or query execution issues between Transaction API and PostgreSQL.

**Threshold:** DB error rate > 0.1% for 5 minutes  
**Impact:** Transaction failures, degraded service performance

---

## 📊 Quick Diagnosis

### Check Database Error Rate

**PromQL Queries:**
```promql
# Current error rate
(sum(rate(db_query_errors_total{app="transaction-api"}[5m])) / 
 sum(rate(db_queries_total{app="transaction-api"}[5m]))) * 100

# Errors by operation type
sum(rate(db_query_errors_total{app="transaction-api"}[5m])) by (operation)

# Errors by error type
sum(rate(db_query_errors_total{app="transaction-api"}[5m])) by (error_type)
```

### Check Connection Pool Status

```promql
# Connection pool utilization
(db_connections_active{app="transaction-api"} / 
 db_connections_max{app="transaction-api"}) * 100

# Active vs idle connections
db_connections_active{app="transaction-api"}
db_connections_idle{app="transaction-api"}
```

---

## 🔍 Investigation Steps

### Step 1: Check Application Logs

```bash
# Get database-related errors
kubectl logs -l app=transaction-api --tail=200 | grep -i "database\|postgres\|connection"

# Look for specific error patterns
kubectl logs -l app=transaction-api --tail=500 | grep -E "(ECONNREFUSED|timeout|deadlock|duplicate key)"

# Check all pods
for pod in $(kubectl get pods -l app=transaction-api -o name); do
  echo "=== $pod ==="
  kubectl logs $pod --tail=50 | grep -i error
done
```

**Common Error Patterns:**
- `ECONNREFUSED` - Database not accepting connections
- `Connection timeout` - Network/firewall issue
- `Too many connections` - Connection pool exhausted
- `Deadlock detected` - Transaction conflict
- `Authentication failed` - Credential issue

### Step 2: Check Database Pod Status

```bash
# Check PostgreSQL pod health
kubectl get pods -l app=postgresql

# Describe pod for events
kubectl describe pod <postgres-pod>

# Check PostgreSQL logs
kubectl logs -l app=postgresql --tail=100

# Check for common issues
kubectl logs -l app=postgresql --tail=500 | grep -i "error\|fatal\|panic\|connection\|authentication"
```

### Step 3: Test Database Connectivity

```bash
# From Transaction API pod
kubectl exec -it <transaction-api-pod> -- /bin/sh

# Try connecting to database (inside pod)
nc -zv postgresql 5432
# or
curl -v telnet://postgresql:5432

# Try psql connection
apk add postgresql-client  # if Alpine
psql -h postgresql -U postgres_exporter -d postgres -c "SELECT 1;"
```

### Step 4: Check Database Performance

```bash
# Port forward to access database
kubectl port-forward <postgres-pod> 5432:5432

# Connect and check status
psql -h localhost -U postgresql -d postgres

# Inside psql:
```

**PostgreSQL Diagnostic Queries:**
```sql
-- Check active connections
SELECT count(*) FROM pg_stat_activity;

-- Check connections by state
SELECT state, count(*) 
FROM pg_stat_activity 
GROUP BY state;

-- Check long-running queries
SELECT pid, now() - query_start AS duration, query 
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY duration DESC 
LIMIT 10;

-- Check for locks/deadlocks
SELECT * FROM pg_locks WHERE NOT granted;

-- Check database size
SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) 
FROM pg_database 
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Check connection limits
SHOW max_connections;
```

---

## 🛠️ Common Causes & Solutions

### Cause 1: Database Pod Crashed/Restarted

**Symptoms:**
- PostgreSQL pod not in Running state
- Recent restart in pod status
- Connection refused errors in API logs

**Solution:**
```bash
# Check pod status
kubectl get pod <postgres-pod>

# If pod is in bad state, check logs
kubectl logs <postgres-pod> --previous

# If needed, delete pod to force restart
kubectl delete pod <postgres-pod>

# Monitor pod startup
kubectl get pod <postgres-pod> -w

# Verify database is accepting connections
kubectl exec -it <postgres-pod> -- psql -U postgresql -d postgres -c "SELECT 1;"
```

**ETA to Resolution:** 2-5 minutes

---

### Cause 2: Connection Pool Exhausted

**Symptoms:**
- "too many connections" in logs
- High connection pool utilization (>95%)
- All connections active, none idle

**Immediate Fix:**
```bash
# Scale down API temporarily to reduce load
kubectl scale deployment transaction-api --replicas=2

# Wait 30 seconds for connections to drain

# Scale back up
kubectl scale deployment transaction-api --replicas=3
```

**Permanent Fix:**
```bash
# Option A: Increase PostgreSQL max_connections
kubectl exec -it <postgres-pod> -- psql -U postgresql -d postgres

ALTER SYSTEM SET max_connections = 200;  -- Increase from default 100
SELECT pg_reload_conf();

# Option B: Increase application connection pool
# Update application config (via ConfigMap or Helm values)
# Redeploy application

# Option C: Optimize queries to use fewer connections
# Review slow queries and add connection pooling logic
```

**ETA to Resolution:** 5-10 minutes

---

### Cause 3: Database Performance Issues (Slow Queries)

**Symptoms:**
- Query timeouts in logs
- High database query latency
- Long-running queries in pg_stat_activity

**Diagnosis:**
```sql
-- Find slow queries
SELECT pid, now() - query_start AS duration, state, query 
FROM pg_stat_activity 
WHERE state != 'idle' AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;

-- Check table bloat
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
LIMIT 10;

-- Check missing indexes
SELECT schemaname, tablename, attname, n_distinct, correlation 
FROM pg_stats 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n_distinct DESC NULLS LAST 
LIMIT 20;
```

**Solution:**
```bash
# Kill long-running queries (emergency)
kubectl exec -it <postgres-pod> -- psql -U postgresql -d postgres

SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'active' AND now() - query_start > interval '1 minute';

# Run VACUUM ANALYZE (for table bloat)
VACUUM ANALYZE;

# Add missing indexes (requires application knowledge)
CREATE INDEX CONCURRENTLY idx_transactions_timestamp ON transactions(created_at);
```

**ETA to Resolution:** 10-30 minutes

---

### Cause 4: Network/Connectivity Issues

**Symptoms:**
- Intermittent connection failures
- "Connection timeout" errors
- Some pods can connect, others cannot

**Diagnosis:**
```bash
# Check network connectivity from each pod
for pod in $(kubectl get pods -l app=transaction-api -o name); do
  echo "Testing from $pod"
  kubectl exec $pod -- nc -zv postgresql 5432
done

# Check DNS resolution
kubectl exec -it <transaction-api-pod> -- nslookup postgresql

# Check service endpoints
kubectl get endpoints postgresql
```

**Solution:**
```bash
# Check if service is pointing to correct pods
kubectl get svc postgresql -o yaml
kubectl get pods -l app=postgresql --show-labels

# Restart CoreDNS if DNS issues
kubectl rollout restart deployment/coredns -n kube-system

# Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>

# Temporarily disable network policy to test (last resort)
kubectl delete networkpolicy <policy-name>
```

**ETA to Resolution:** 10-20 minutes

---

### Cause 5: Authentication/Permission Issues

**Symptoms:**
- "Authentication failed" in logs
- "Permission denied" errors
- Specific queries failing

**Solution:**
```bash
# Verify credentials are correct
kubectl get secret transaction-api-secret -o jsonpath='{.data.db-password}' | base64 -d

# Test connection with credentials
kubectl exec -it <transaction-api-pod> -- env | grep -i db

# Check PostgreSQL user permissions
kubectl exec -it <postgres-pod> -- psql -U postgresql -d postgres

\du postgres_exporter
-- Verify pg_monitor role is granted

-- Re-grant permissions if needed
GRANT pg_monitor TO postgres_exporter;
GRANT SELECT ON pg_stat_database TO postgres_exporter;
GRANT CONNECT ON DATABASE postgres TO postgres_exporter;
GRANT CONNECT ON DATABASE transactions TO postgres_exporter;
```

**ETA to Resolution:** 5-10 minutes

---

### Cause 6: Database Disk Full

**Symptoms:**
- "No space left on device" errors
- Database pod in Error state
- Cannot write to database

**Solution:**
```bash
# Check disk usage on PostgreSQL pod
kubectl exec -it <postgres-pod> -- df -h

# Check PVC status
kubectl get pvc -l app=postgresql

# Temporary: Clean up old WAL files
kubectl exec -it <postgres-pod> -- du -sh /var/lib/postgresql/data/pg_wal/
# (PostgreSQL should auto-clean, but can be forced)

# Permanent: Increase PVC size
kubectl edit pvc postgresql-data
# Increase storage size

# Or create new larger PVC and migrate
```

**ETA to Resolution:** 30-60 minutes (includes PVC resize)

---

## ⚡ Immediate Mitigation (If Root Cause Unknown)

If you can't quickly identify the root cause:

```bash
# 1. Scale down to reduce load
kubectl scale deployment transaction-api --replicas=1

# 2. Restart database pod
kubectl delete pod <postgres-pod>

# 3. Wait for services to stabilize
kubectl get pods -w

# 4. Gradually scale back up
kubectl scale deployment transaction-api --replicas=2
# Wait 2 minutes, check error rate
kubectl scale deployment transaction-api --replicas=3

# 5. Monitor closely
kubectl logs -l app=transaction-api -f | grep -i error
```

**ETA to Mitigation:** 5-10 minutes

---

## ✅ Verification Steps

After fixing, verify database connectivity is restored:

```bash
# 1. Check error rate (should be < 0.01%)
# PromQL: (sum(rate(db_query_errors_total{app="transaction-api"}[5m])) / 
#          sum(rate(db_queries_total{app="transaction-api"}[5m]))) * 100

# 2. Check connection pool utilization (should be < 80%)
# PromQL: (db_connections_active{app="transaction-api"} / 
#          db_connections_max{app="transaction-api"}) * 100

# 3. Test database connection manually
kubectl exec -it <transaction-api-pod> -- \
  psql -h postgresql -U postgres_exporter -d postgres -c "SELECT version();"

# 4. Check application logs (no errors)
kubectl logs -l app=transaction-api --tail=100 | grep -i error

# 5. Test transaction creation
curl -X POST https://transaction-api/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{"from_account":"ACC001","to_account":"ACC002","amount":100,"type":"transfer"}'
```

---

## 📊 Monitoring After Resolution

Monitor these metrics for 30 minutes:

```promql
# Database error rate
rate(db_query_errors_total{app="transaction-api"}[5m])

# Connection pool health
db_connections_active{app="transaction-api"}
db_connections_idle{app="transaction-api"}

# Query latency
histogram_quantile(0.95, rate(db_query_duration_seconds_bucket{app="transaction-api"}[5m]))

# Transaction success rate
(sum(rate(transactions_total{app="transaction-api",status="success"}[5m])) / 
 sum(rate(transactions_total{app="transaction-api"}[5m]))) * 100
```

---

## 📝 Post-Incident Actions

1. **Document root cause** in incident ticket
2. **Review slow queries** and optimize if needed
3. **Check if connection pool sizing is adequate**
4. **Review database resource limits**
5. **Update monitoring thresholds** if needed
6. **Add automated remediation** if issue is common
7. **Schedule postmortem** if impact > 15 minutes

---

## 🔍 Prevention Strategies

### Connection Pool Optimization
- Monitor pool utilization trends
- Implement connection timeout policies
- Add connection retry logic with exponential backoff

### Query Performance
- Regular EXPLAIN ANALYZE on slow queries
- Add appropriate indexes
- Implement query timeout limits
- Use connection pooling (PgBouncer)

### Database Maintenance
- Schedule regular VACUUM ANALYZE
- Monitor table bloat
- Set up automated backups
- Plan for capacity increases

### Monitoring Improvements
- Alert on connection pool > 80%
- Alert on slow queries > 5 seconds
- Track query patterns over time
- Monitor disk space usage

---

## 📞 Escalation Path

| Time | Action |
|------|--------|
| 0-5 min | On-call engineer investigates |
| 5-10 min | Database team notified |
| 10-20 min | Backend team lead engaged |
| 20-30 min | Engineering manager + DBA engaged |
| 30+ min | Incident commander + executive notification |

**Emergency Contacts:**
- Database Team: [Slack #database-oncall]
- Backend Team: [Slack #backend-oncall]
- Platform Team: [Slack #platform-oncall]

---

## 📚 Related Resources

- [PostgreSQL Performance Tuning Guide](link)
- [Connection Pool Configuration](link)
- [Database Backup and Recovery](link)
- [High Error Rate Runbook](./high-error-rate.md)

---

**Last Updated:** 2025-11-02  
**Owner:** Database Team / SRE Team  
**Review Frequency:** Quarterly
