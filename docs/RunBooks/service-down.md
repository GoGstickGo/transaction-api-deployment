# Runbook: Transaction API Down

**Alert Name:** `TransactionAPIDown`  
**Severity:** Critical  
**Impact:** Complete service outage  

---

## 🚨 Alert Description

The Transaction API service is completely down. Prometheus cannot scrape metrics, indicating all instances are unreachable.

**Threshold:** Service down for 2+ minutes  
**Impact:** 100% of users unable to process transactions

---

## ⚡ IMMEDIATE ACTIONS (First 60 Seconds)

```bash
# 1. Check pod status
kubectl get pods -l app=transaction-api

# 2. Check if ANY pods are running
kubectl get pods -l app=transaction-api --field-selector=status.phase=Running

# 3. Quick pod count
kubectl get deployment transaction-api
```

**Expected Output Issues:**
- No pods running (0/3 ready)
- Pods in CrashLoopBackOff
- Pods in Error/Pending state
- Deployment shows 0 available replicas

---

## 🔍 Diagnosis Decision Tree

```
Is deployment showing 0/X ready?
├─ YES → Are there any pods at all?
│   ├─ NO → Deployment scaled to 0 or deleted → See Section A
│   └─ YES → Pods exist but not ready
│       ├─ CrashLoopBackOff → See Section B
│       ├─ Pending → See Section C
│       ├─ Error → See Section D
│       └─ ImagePullBackOff → See Section E
└─ NO → Deployment exists but Prometheus can't reach
    └─ Network/Service issue → See Section F
```

---

## 📋 Section A: Deployment Scaled to 0 or Missing

### Check Deployment

```bash
# Verify deployment exists
kubectl get deployment transaction-api

# Check recent events
kubectl get events --sort-by='.lastTimestamp' | grep transaction-api | tail -20

# Check if someone scaled it down
kubectl get deployment transaction-api -o jsonpath='{.spec.replicas}'
```

### Solution

```bash
# Scale up immediately
kubectl scale deployment transaction-api --replicas=3

# Wait for pods to start
kubectl rollout status deployment/transaction-api

# Verify
kubectl get pods -l app=transaction-api
```

**ETA to Recovery:** 1-2 minutes

### If Deployment Deleted

```bash
# Check if Helm release still exists
helm list -n default | grep transaction-api

# Redeploy using Helm
helm upgrade --install transaction-api ./helm/transaction-api -n default

# Or via Terraform
cd terraform && terraform apply -target=helm_release.transaction_api
```

**ETA to Recovery:** 3-5 minutes

---

## 📋 Section B: Pods in CrashLoopBackOff

### Diagnosis

```bash
# Check pod status and restarts
kubectl get pods -l app=transaction-api

# Get detailed pod description
kubectl describe pod <pod-name>

# Check recent logs (before crash)
kubectl logs <pod-name> --previous

# Check current logs
kubectl logs <pod-name> --tail=100
```

### Common Causes

#### 1. Application Startup Failure

**Symptoms in logs:**
- "Failed to connect to database"
- "Configuration error"
- "Port already in use"
- Stack trace on startup

**Solution:**
```bash
# Check environment variables
kubectl get deployment transaction-api -o yaml | grep -A 20 env:

# Check ConfigMap/Secret
kubectl get configmap transaction-api-config -o yaml
kubectl get secret transaction-api-secret -o yaml

# If config is wrong, fix and rollout
kubectl edit deployment transaction-api
# Or update via Helm/Terraform
```

#### 2. Database Connection Failure

**Symptoms in logs:**
- "ECONNREFUSED"
- "Connection timeout"
- "Authentication failed"

**Solution:**
```bash
# Check database status
kubectl get pods -l app=postgresql
kubectl logs -l app=postgresql --tail=50

# Test connectivity from API pod
kubectl run -it --rm debug --image=postgres:13 --restart=Never -- \
  psql -h postgresql -U postgresql -d postgres

# If database down, restart it
kubectl delete pod <postgres-pod>
```

#### 3. Memory/Resource Issues

**Symptoms:**
- Pod description shows "OOMKilled"
- Exit code 137 in pod status

**Solution:**
```bash
# Increase memory limits
kubectl set resources deployment transaction-api \
  --limits=memory=2Gi \
  --requests=memory=1Gi

# Monitor rollout
kubectl rollout status deployment/transaction-api
```

**ETA to Recovery:** 2-5 minutes

---

## 📋 Section C: Pods in Pending State

### Diagnosis

```bash
# Check why pods are pending
kubectl describe pod <pod-name> | grep -A 10 Events

# Check node status
kubectl get nodes

# Check resource availability
kubectl top nodes
```

### Common Causes

#### 1. Insufficient Resources

**Symptoms in events:**
- "Insufficient cpu"
- "Insufficient memory"

**Solution:**
```bash
# Temporary: Reduce resource requests
kubectl set resources deployment transaction-api \
  --requests=cpu=200m,memory=256Mi

# Long-term: Add more nodes or resize cluster
# (GKE autoscaling should handle this)

# Check node autoscaler status
kubectl get nodes -w
```

#### 2. Node Selector / Affinity Issues

**Solution:**
```bash
# Check pod spec for node selectors
kubectl get deployment transaction-api -o yaml | grep -A 5 nodeSelector

# Remove node selector temporarily if blocking
kubectl patch deployment transaction-api -p '{"spec":{"template":{"spec":{"nodeSelector":null}}}}'
```

**ETA to Recovery:** 3-10 minutes (depends on node provisioning)

---

## 📋 Section D: Pods in Error State

### Diagnosis

```bash
# Get error details
kubectl describe pod <pod-name>
kubectl logs <pod-name> --previous
kubectl logs <pod-name>
```

### Solution

```bash
# Delete failed pods to trigger recreation
kubectl delete pod <pod-name>

# If persistent, check pod spec
kubectl get deployment transaction-api -o yaml > /tmp/deploy.yaml
# Review and fix issues

# Apply fix
kubectl apply -f /tmp/deploy.yaml
```

**ETA to Recovery:** 2-5 minutes

---

## 📋 Section E: ImagePullBackOff

### Diagnosis

```bash
# Check image pull status
kubectl describe pod <pod-name> | grep -A 10 "Failed to pull image"

# Check image name
kubectl get deployment transaction-api -o jsonpath='{.spec.template.spec.containers[0].image}'
```

### Common Causes

#### 1. Image Doesn't Exist

**Solution:**
```bash
# Rollback to previous working version
kubectl rollout undo deployment/transaction-api

# Or specify known good image
kubectl set image deployment/transaction-api \
  transaction-api=gcr.io/project/transaction-api:v1.2.3
```

#### 2. Image Registry Authentication

**Solution:**
```bash
# Check image pull secret
kubectl get secret -n default | grep regcred

# Recreate if missing
kubectl create secret docker-registry regcred \
  --docker-server=gcr.io \
  --docker-username=_json_key \
  --docker-password="$(cat key.json)"

# Update deployment
kubectl patch deployment transaction-api -p \
  '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"regcred"}]}}}}'
```

**ETA to Recovery:** 3-5 minutes

---

## 📋 Section F: Network/Service Issues

### Diagnosis

```bash
# Check if service exists
kubectl get svc transaction-api

# Check service endpoints
kubectl get endpoints transaction-api

# Check if pods are selected by service
kubectl get pods -l app=transaction-api --show-labels

# Test service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://transaction-api:8080/health
```

### Solutions

#### Service Missing Endpoints

```bash
# Check selector matches pod labels
kubectl get svc transaction-api -o yaml | grep -A 5 selector
kubectl get pods -l app=transaction-api --show-labels

# Fix selector if mismatched
kubectl edit svc transaction-api
```

#### Network Policy Blocking

```bash
# Check network policies
kubectl get networkpolicies

# Temporarily disable if blocking (last resort)
kubectl delete networkpolicy <policy-name>
```

**ETA to Recovery:** 2-5 minutes

---

## 🔧 Emergency Workarounds

### If Unable to Fix Quickly (>10 minutes)

```bash
# 1. Enable maintenance mode page
kubectl apply -f maintenance-mode.yaml

# 2. Route traffic to backup/DR site (if available)
# Update DNS or load balancer

# 3. Notify users via status page
# POST to status page API

# 4. Continue troubleshooting with reduced pressure
```

---

## ✅ Verification Steps

```bash
# 1. Check all pods are running
kubectl get pods -l app=transaction-api
# Expected: All pods show 1/1 READY and Running

# 2. Check Prometheus can scrape
# Wait 2 minutes, then check Prometheus UI
# up{job="transaction-api"} should return 1

# 3. Test API endpoint
curl -X POST https://transaction-api/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{"from_account":"ACC001","to_account":"ACC002","amount":100,"type":"transfer"}'

# 4. Check Grafana dashboard
# All metrics should be populating

# 5. Monitor error rate
# Should be < 0.1%
```

---

## 📞 Escalation

| Time | Action |
|------|--------|
| 0 min | On-call engineer engaged |
| 5 min | Backend team lead notified |
| 10 min | Engineering manager + Platform team engaged |
| 15 min | Incident commander assigned |
| 20 min | Executive notification + customer communication |

---

## 📝 Post-Recovery

1. **Verify service stability** for 15 minutes
2. **Review logs** for root cause
3. **Update incident ticket** with timeline
4. **Notify stakeholders** service is restored
5. **Schedule postmortem** within 24 hours
6. **Update runbook** with lessons learned

---

## 🔍 Root Cause Checklist

After resolving, determine root cause:

- [ ] Recent deployment/code change
- [ ] Configuration change
- [ ] Database failure
- [ ] Infrastructure issue (node failure, network)
- [ ] Resource exhaustion
- [ ] Image registry issue
- [ ] Accidental scaling to 0
- [ ] External dependency failure
- [ ] Security/access issue

---

## 📚 Related Resources

- [High Error Rate Runbook](./high-error-rate.md)
- [Pod Crash Loop Runbook](./pod-crash-loop.md)
- [Database Connectivity Runbook](./database-errors.md)
- [Emergency Rollback Procedure](./emergency-rollback.md)

---

**Last Updated:** 2025-11-02  
**Owner:** SRE Team  
**Severity:** P0 - Complete Outage
