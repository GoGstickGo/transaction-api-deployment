# Runbook: Transaction API High Error Rate

**Alert Name:** `TransactionAPIHighErrorRate`  
**Severity:** Critical  
**SLO Impact:** API Availability  

---

## 🚨 Alert Description

The Transaction API error rate (5xx responses) has exceeded 1% for the last 5 minutes, breaching the availability SLO.

**Threshold:** Error rate > 1% for 5 minutes  
**SLO Target:** 99.95% availability (0.05% error budget)

---

## 📊 Quick Diagnosis

### Step 1: Check Current Error Rate
```bash
# Port forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Or use this query directly
```

**PromQL Query:**
```promql
(sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
 sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100
```

### Step 2: Identify Error Types
```promql
# Count by status code
sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) by (status)

# Count by endpoint
sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) by (endpoint)
```

### Step 3: Check Recent Changes
```bash
# Check recent deployments
kubectl rollout history deployment/transaction-api

# Check current rollout status
kubectl rollout status deployment/transaction-api

# Get recent events
kubectl get events --sort-by='.lastTimestamp' -n default | grep transaction-api | tail -20
```

---

## 🔍 Investigation Steps

### 1. Check Application Logs (First Priority)

```bash
# Get logs from all pods
kubectl logs -l app=transaction-api --tail=100 --timestamps

# Follow logs in real-time
kubectl logs -l app=transaction-api -f

# Check for specific error patterns
kubectl logs -l app=transaction-api --tail=500 | grep -i error

# Check specific pod
kubectl logs <pod-name> --tail=200
```

**Look for:**
- Stack traces
- Database connection errors
- Timeout errors
- Out of memory errors
- Unhandled exceptions

### 2. Check Pod Health

```bash
# Check pod status
kubectl get pods -l app=transaction-api

# Describe pods for detailed info
kubectl describe pods -l app=transaction-api

# Check resource usage
kubectl top pods -l app=transaction-api
```

**Red Flags:**
- Pods in CrashLoopBackOff
- Pods being OOMKilled
- High CPU/memory usage
- Frequent restarts

### 3. Check Database Connectivity

```bash
# Check database error rate
```

**PromQL Query:**
```promql
sum(rate(db_query_errors_total{app="transaction-api"}[5m]))
```

```bash
# Test database connection from pod
kubectl exec -it <transaction-api-pod> -- curl http://localhost:8080/health

# Check PostgreSQL status
kubectl get pods -l app=postgresql
kubectl logs -l app=postgresql --tail=50
```

### 4. Check Dependencies

```bash
# Check if external services are responding
kubectl exec -it <transaction-api-pod> -- curl -I <external-service-url>

# Check network policies
kubectl get networkpolicies -n default
```

### 5. Review Recent Deployments

```bash
# Get deployment history
kubectl rollout history deployment/transaction-api

# Check current image
kubectl get deployment transaction-api -o jsonpath='{.spec.template.spec.containers[0].image}'

# Compare with previous version
kubectl rollout history deployment/transaction-api --revision=<previous-revision>
```

---

## 🛠️ Common Causes & Solutions

### Cause 1: Recent Deployment with Bugs

**Symptoms:**
- Error rate spiked immediately after deployment
- Logs show new application errors
- Previous version was stable

**Solution:**
```bash
# Rollback to previous version
kubectl rollout undo deployment/transaction-api

# Verify rollback
kubectl rollout status deployment/transaction-api

# Monitor error rate
# Should drop within 2-3 minutes
```

**Follow-up:**
- Review code changes in the failed deployment
- Add/improve integration tests
- Conduct postmortem

---

### Cause 2: Database Connection Issues

**Symptoms:**
- Logs show "connection refused" or "timeout" errors
- High database error rate
- Database pods restarting

**Solution:**
```bash
# Check database pod status
kubectl get pods -l app=postgresql
kubectl describe pod <postgres-pod>

# Check database logs
kubectl logs <postgres-pod> --tail=100

# Restart database if needed (last resort)
kubectl delete pod <postgres-pod>

# Scale up connection pool (if exhausted)
# Update application config and redeploy
```

**Temporary Mitigation:**
```bash
# Scale down API to reduce load on DB
kubectl scale deployment transaction-api --replicas=2
```

---

### Cause 3: Resource Exhaustion (CPU/Memory)

**Symptoms:**
- Pods showing high CPU/memory usage
- Slow response times
- OOMKilled events in pod events

**Solution:**
```bash
# Check resource usage
kubectl top pods -l app=transaction-api

# Increase resources temporarily
kubectl set resources deployment transaction-api \
  --limits=cpu=2000m,memory=2Gi \
  --requests=cpu=1000m,memory=1Gi

# Scale horizontally
kubectl scale deployment transaction-api --replicas=5
```

---

### Cause 4: External Dependency Failure

**Symptoms:**
- Logs show timeouts to external services
- Error rate correlates with external service issues
- Specific endpoints failing

**Solution:**
```bash
# Enable circuit breaker (if implemented)
# Or temporarily disable non-critical external calls

# Scale up to handle retries
kubectl scale deployment transaction-api --replicas=5

# If payment provider down, enable fallback mode
kubectl set env deployment/transaction-api FALLBACK_MODE=true
```

---

### Cause 5: Invalid Request Patterns / DDoS

**Symptoms:**
- Unusual traffic patterns
- Specific endpoints receiving excessive requests
- Logs show validation errors

**Solution:**
```bash
# Check request rate by endpoint
# PromQL: sum(rate(http_requests_total{app="transaction-api"}[5m])) by (endpoint)

# Apply rate limiting (if available)
kubectl annotate ingress transaction-api \
  nginx.ingress.kubernetes.io/limit-rps="100"

# Block malicious IPs at ingress level
# (depends on your ingress controller)
```

---

## ⚡ Immediate Actions (First 5 Minutes)

1. **Acknowledge Alert** in PagerDuty/Slack
2. **Check Grafana Dashboard** for visual context
3. **Review Recent Deployments** (last 1 hour)
4. **Check Application Logs** for error patterns
5. **Assess Impact:**
   - How many users affected?
   - Which endpoints failing?
   - Is it getting worse?

---

## 🎯 Mitigation Strategies

### If Recent Deployment is Cause:
```bash
# Immediate rollback
kubectl rollout undo deployment/transaction-api
```
**ETA to Resolution:** 2-3 minutes

### If Database Issues:
```bash
# Scale down to reduce load
kubectl scale deployment transaction-api --replicas=2
# Investigate and fix database
```
**ETA to Resolution:** 10-30 minutes

### If Resource Exhaustion:
```bash
# Quick horizontal scale
kubectl scale deployment transaction-api --replicas=5
```
**ETA to Resolution:** 3-5 minutes

### If External Dependency:
```bash
# Enable fallback/degraded mode
# Contact external service provider
# Implement circuit breaker
```
**ETA to Resolution:** Depends on external service

---

## ✅ Verification Steps

After applying fix, verify error rate returns to normal:

```bash
# Check error rate (should be < 0.1%)
# PromQL: (sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
#          sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100

# Check pod status
kubectl get pods -l app=transaction-api

# Monitor logs
kubectl logs -l app=transaction-api -f --tail=50

# Test endpoint manually
curl -X POST https://transaction-api/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{"from_account":"ACC001","to_account":"ACC002","amount":100,"type":"transfer"}'
```

**Expected Results:**
- Error rate drops below 0.1% within 5 minutes
- All pods Running and Ready
- No errors in logs
- Manual API test succeeds

---

## 📝 Post-Incident Actions

### 1. Update Status Page
```
[RESOLVED] Transaction API experiencing elevated error rates
- Impact: ~X% of transactions failed
- Duration: HH:MM - HH:MM UTC
- Root Cause: [Brief description]
- Resolution: [What was done]
```

### 2. Document Incident
Create ticket with:
- Timeline of events
- Root cause analysis
- Actions taken
- Time to detection
- Time to resolution

### 3. Schedule Postmortem (if impact > 10 minutes)
- What happened?
- Why did it happen?
- How was it detected?
- How was it resolved?
- What are the action items?

### 4. Update Monitoring
- Were alerts accurate?
- Did we have enough visibility?
- Do we need additional alerts?

---

## 🔗 Related Alerts

- **TransactionAPIDown** - Complete service outage
- **TransactionAPIHighLatency** - Slow response times
- **DatabaseConnectionFailures** - Database connectivity issues
- **TransactionProcessingFailureHigh** - Transaction-specific failures

---

## 📞 Escalation Path

| Time Elapsed | Action |
|--------------|--------|
| 0-5 min | On-call engineer investigates |
| 5-15 min | Engage backend team lead |
| 15-30 min | Engage engineering manager + database team |
| 30+ min | Incident commander + executive notification |

**Emergency Contacts:**
- Backend Team Lead: [Slack channel / phone]
- Database Team: [Slack channel / phone]
- Engineering Manager: [Phone]

---

## 📚 Additional Resources

- [Transaction API Architecture Diagram](link)
- [Database Connection Pool Configuration](link)
- [Deployment Procedures](link)
- [Previous Incidents](link)

---

**Last Updated:** 2025-11-02  
**Owner:** SRE Team  
**Review Frequency:** Quarterly
