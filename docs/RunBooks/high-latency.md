# Runbook: Transaction API High Latency

**Alert Name:** `TransactionAPIHighLatency`  
**Severity:** Critical  
**SLO Impact:** API Latency  

---

## 🚨 Alert Description

The Transaction API P95 latency has exceeded 200ms for 10 consecutive minutes, breaching the latency SLO.

**Threshold:** P95 latency > 200ms for 10 minutes  
**SLO Target:** P95 < 200ms, P99 < 500ms  
**User Impact:** Slow response times, degraded user experience

---

## 📊 Quick Diagnosis

### Check Current Latency

**PromQL Queries:**
```promql
# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) * 1000

# P99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) * 1000

# P50 latency (median)
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) * 1000

# Latency by endpoint
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) by (endpoint) * 1000
```

### Identify Slow Endpoints

```promql
# Top 5 slowest endpoints
topk(5, histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) by (endpoint))
```

---

## 🔍 Investigation Steps

### Step 1: Identify the Bottleneck

Check these components in order:

```bash
# 1. Check pod resource usage
kubectl top pods -l app=transaction-api

# 2. Check database query latency
```

**PromQL:**
```promql
histogram_quantile(0.95, rate(db_query_duration_seconds_bucket{app="transaction-api"}[5m])) * 1000
```

```bash
# 3. Check request volume
```

**PromQL:**
```promql
sum(rate(http_requests_total{app="transaction-api"}[5m]))
```

```bash
# 4. Check error rate (errors often cause retries/slowness)
```

**PromQL:**
```promql
(sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
 sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100
```

### Step 2: Check Application Logs

```bash
# Look for slow query warnings
kubectl logs -l app=transaction-api --tail=200 | grep -i "slow\|timeout\|latency"

# Check for specific slow operations
kubectl logs -l app=transaction-api --tail=500 | grep -E "(took|duration|elapsed)" | grep -v "ms" | grep "s"

# Look for external API timeouts
kubectl logs -l app=transaction-api --tail=200 | grep -i "external\|timeout\|upstream"
```

### Step 3: Analyze Traffic Patterns

```bash
# Check if there's a traffic spike
# PromQL: sum(rate(http_requests_total{app="transaction-api"}[5m]))

# Check request distribution by endpoint
# PromQL: sum(rate(http_requests_total{app="transaction-api"}[5m])) by (endpoint)

# Check if specific user causing load
kubectl logs -l app=transaction-api --tail=1000 | cut -d' ' -f1 | sort | uniq -c | sort -rn | head -20
```

---

## 🛠️ Common Causes & Solutions

### Cause 1: High CPU Usage

**Symptoms:**
- CPU utilization > 80%
- High request processing time
- Pods showing throttling in metrics

**Diagnosis:**
```bash
# Check CPU usage
kubectl top pods -l app=transaction-api

# Check CPU throttling
kubectl describe pod <pod-name> | grep -i cpu
```

**Solution:**
```bash
# Immediate: Scale horizontally
kubectl scale deployment transaction-api --replicas=5

# Verify scaling
kubectl get pods -l app=transaction-api -w

# Permanent: Increase CPU limits
kubectl set resources deployment transaction-api \
  --limits=cpu=2000m \
  --requests=cpu=1000m

# Or update via Helm
helm upgrade transaction-api ./helm/transaction-api \
  --set resources.limits.cpu=2000m \
  --set resources.requests.cpu=1000m
```

**ETA to Resolution:** 3-5 minutes

**Expected Outcome:** Latency drops by 30-50%

---

### Cause 2: Slow Database Queries

**Symptoms:**
- High database query latency (P95 > 100ms)
- Database connection pool at high utilization
- Specific endpoints with database calls are slow

**Diagnosis:**
```bash
# Check database query latency
# PromQL: histogram_quantile(0.95, rate(db_query_duration_seconds_bucket[5m])) * 1000

# Connect to database and find slow queries
kubectl port-forward <postgres-pod> 5432:5432

psql -h localhost -U postgresql -d transactions
```

**PostgreSQL queries:**
```sql
-- Find slow running queries
SELECT pid, now() - query_start AS duration, state, query 
FROM pg_stat_activity 
WHERE state != 'idle' AND now() - query_start > interval '1 second'
ORDER BY duration DESC 
LIMIT 10;

-- Check for missing indexes
SELECT schemaname, tablename, indexname, idx_scan 
FROM pg_stat_user_indexes 
WHERE idx_scan = 0 AND schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY relname;

-- Check table statistics
SELECT schemaname, tablename, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum 
FROM pg_stat_user_tables 
ORDER BY n_dead_tup DESC 
LIMIT 10;
```

**Solution:**

**Immediate (if specific slow query identified):**
```sql
-- Kill long-running query (emergency only)
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'active' AND now() - query_start > interval '30 seconds';
```

**Short-term:**
```sql
-- Run VACUUM ANALYZE
VACUUM ANALYZE;

-- Update statistics
ANALYZE;
```

**Long-term:**
```sql
-- Add missing indexes (example)
CREATE INDEX CONCURRENTLY idx_transactions_created_at ON transactions(created_at);
CREATE INDEX CONCURRENTLY idx_transactions_from_account ON transactions(from_account);
CREATE INDEX CONCURRENTLY idx_transactions_status ON transactions(status);

-- Optimize query plans
EXPLAIN ANALYZE SELECT * FROM transactions WHERE created_at > NOW() - INTERVAL '1 day';
```

**ETA to Resolution:** 10-30 minutes

**Expected Outcome:** Database query latency drops significantly

---

### Cause 3: Memory Pressure / Garbage Collection

**Symptoms:**
- Memory usage > 80%
- Periodic latency spikes
- GC pauses in logs (if Java/Node.js)

**Diagnosis:**
```bash
# Check memory usage
kubectl top pods -l app=transaction-api

# Check for OOM events
kubectl describe pods -l app=transaction-api | grep -i "OOM"

# Check logs for GC activity (Node.js example)
kubectl logs -l app=transaction-api --tail=500 | grep -i "gc\|garbage"
```

**Solution:**
```bash
# Increase memory limits
kubectl set resources deployment transaction-api \
  --limits=memory=2Gi \
  --requests=memory=1Gi

# Restart pods to clear memory
kubectl rollout restart deployment transaction-api

# Monitor during restart
kubectl get pods -l app=transaction-api -w
```

**ETA to Resolution:** 5-10 minutes

---

### Cause 4: External API/Service Delays

**Symptoms:**
- Specific endpoints calling external services are slow
- Timeout errors in logs
- Correlation with external service status

**Diagnosis:**
```bash
# Check logs for external service calls
kubectl logs -l app=transaction-api --tail=500 | grep -i "external\|http\|api"

# Check if specific external service is slow
kubectl exec -it <transaction-api-pod> -- curl -w "@curl-format.txt" -o /dev/null -s https://external-service.com/api
```

**curl-format.txt:**
```
    time_namelookup:  %{time_namelookup}\n
       time_connect:  %{time_connect}\n
    time_appconnect:  %{time_appconnect}\n
   time_pretransfer:  %{time_pretransfer}\n
      time_redirect:  %{time_redirect}\n
 time_starttransfer:  %{time_starttransfer}\n
                    ----------\n
         time_total:  %{time_total}\n
```

**Solution:**

**Immediate:**
```bash
# Implement circuit breaker if available
kubectl set env deployment/transaction-api CIRCUIT_BREAKER_ENABLED=true

# Reduce timeout for external calls
kubectl set env deployment/transaction-api EXTERNAL_API_TIMEOUT=5000
```

**Short-term:**
```
# Add retry logic with exponential backoff
# Implement caching for external API responses
# Use async/non-blocking calls where possible
```

**Long-term:**
```
# Implement proper circuit breaker pattern
# Add fallback mechanisms
# Cache external API responses
# Consider moving to async processing
```

**ETA to Resolution:** 5-15 minutes (depends on solution)

---

### Cause 5: High Request Volume (Traffic Spike)

**Symptoms:**
- Sudden increase in request rate
- All endpoints showing increased latency
- Resource usage trending upward

**Diagnosis:**
```bash
# Check current request rate
# PromQL: sum(rate(http_requests_total{app="transaction-api"}[5m]))

# Compare to baseline
# PromQL: sum(rate(http_requests_total{app="transaction-api"}[1h]))

# Check source of traffic
kubectl logs -l app=transaction-api --tail=2000 | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
```

**Solution:**
```bash
# Scale up immediately
kubectl scale deployment transaction-api --replicas=8

# Enable autoscaling if not already enabled
kubectl autoscale deployment transaction-api --cpu-percent=70 --min=3 --max=10

# If malicious traffic, apply rate limiting
kubectl annotate ingress transaction-api \
  nginx.ingress.kubernetes.io/limit-rps="100"

# Monitor effect
kubectl get hpa transaction-api -w
```

**ETA to Resolution:** 3-5 minutes

---

### Cause 6: Database Connection Pool Saturation

**Symptoms:**
- Connection pool at or near max
- Queries waiting for available connections
- Intermittent database errors

**Diagnosis:**
```promql
# Check connection pool utilization
(db_connections_active{app="transaction-api"} / db_connections_max{app="transaction-api"}) * 100

# Check active connections
db_connections_active{app="transaction-api"}
```

**Solution:**
```bash
# Immediate: Scale down to reduce load
kubectl scale deployment transaction-api --replicas=2

# Increase connection pool size in application
kubectl set env deployment/transaction-api DB_POOL_SIZE=50

# Or update via ConfigMap/Helm
# Then scale back up
kubectl scale deployment transaction-api --replicas=3
```

**ETA to Resolution:** 5-10 minutes

---

### Cause 7: N+1 Query Problem

**Symptoms:**
- Specific endpoints with database joins are slow
- High number of database queries per request
- Linear scaling of latency with result set size

**Diagnosis:**
```bash
# Check query count per request
kubectl logs -l app=transaction-api --tail=1000 | grep "query" | wc -l

# Look for patterns in logs
kubectl logs -l app=transaction-api --tail=500 | grep "SELECT"
```

**Solution:**
```
# Code fix required - use eager loading
# Example for ORM:
# - Sequelize: include relations
# - TypeORM: relations in find options
# - Prisma: include in query

# Deploy fixed version
kubectl set image deployment/transaction-api \
  transaction-api=gcr.io/project/transaction-api:v1.2.4-fix-nplus1
```

**ETA to Resolution:** Requires code deployment (30-60 min)

---

## ⚡ Quick Wins (Try These First)

If root cause is unclear, try these in order:

```bash
# 1. Scale horizontally (safest, fastest)
kubectl scale deployment transaction-api --replicas=5
# Wait 2-3 minutes, check if latency improves

# 2. Restart pods (clears memory/connections)
kubectl rollout restart deployment transaction-api
# Wait 3-5 minutes

# 3. Run database VACUUM (if not done recently)
kubectl exec -it <postgres-pod> -- psql -U postgresql -d transactions -c "VACUUM ANALYZE;"

# 4. Clear application cache (if applicable)
kubectl exec -it <transaction-api-pod> -- curl -X POST http://localhost:8080/admin/cache/clear
```

---

## ✅ Verification Steps

After applying fix:

```bash
# 1. Check P95 latency (should be < 200ms)
# PromQL: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) * 1000

# 2. Check P99 latency (should be < 500ms)
# PromQL: histogram_quantile(0.99, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m])) * 1000

# 3. Test endpoint manually
time curl -X POST https://transaction-api/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{"from_account":"ACC001","to_account":"ACC002","amount":100,"type":"transfer"}'
# Should complete in < 200ms

# 4. Monitor Grafana dashboard
# All latency metrics should be trending down

# 5. Check resource usage
kubectl top pods -l app=transaction-api
# Should be < 70% CPU, < 80% memory
```

---

## 📊 Monitor for 30 Minutes

After resolution, watch these metrics:

```promql
# Latency trend
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m]))

# Request rate
sum(rate(http_requests_total{app="transaction-api"}[5m]))

# Error rate
(sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
 sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100

# Resource usage
avg(rate(container_cpu_usage_seconds_total{pod=~"transaction-api-.*"}[5m])) * 100
```

---

## 📝 Post-Incident Actions

1. **Identify root cause** from investigation
2. **Document in incident ticket** with timeline
3. **Create Jira tickets** for permanent fixes:
   - Add missing database indexes
   - Optimize slow queries
   - Implement caching
   - Add circuit breakers
4. **Review and update** resource limits if needed
5. **Schedule postmortem** if SLO breached
6. **Update capacity planning** if traffic spike

---

## 🔍 Prevention Strategies

### Performance Testing
- Regular load testing with realistic traffic
- Benchmark all endpoints quarterly
- Profile application for hotspots

### Database Optimization
- Regular EXPLAIN ANALYZE on common queries
- Automated index recommendations
- Connection pool monitoring

### Capacity Planning
- Set up HPA (Horizontal Pod Autoscaler)
- Monitor trends for proactive scaling
- Regular resource limit reviews

### Code Reviews
- Check for N+1 queries
- Review external API timeouts
- Validate query efficiency

---

## 📞 Escalation Path

| Time | Action |
|------|--------|
| 0-10 min | On-call engineer investigates |
| 10-20 min | Backend team lead engaged |
| 20-30 min | Performance team + DBA engaged |
| 30+ min | Engineering manager + product notified |

---

## 📚 Related Resources

- [High Error Rate Runbook](./high-error-rate.md)
- [Database Performance Guide](link)
- [Query Optimization Checklist](link)
- [Capacity Planning Dashboard](link)

---

**Last Updated:** 2025-11-02  
**Owner:** SRE Team / Backend Team  
**Review Frequency:** Quarterly
