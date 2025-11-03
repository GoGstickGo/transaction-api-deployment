# Transaction API Runbooks

This directory contains operational runbooks for responding to critical alerts from the Transaction API monitoring system.

## 📚 Available Runbooks

### Critical Alerts

| Runbook | Alert | Severity | Avg Resolution Time |
|---------|-------|----------|---------------------|
| [High Error Rate](./high-error-rate.md) | TransactionAPIHighErrorRate | Critical | 5-15 minutes |
| [Service Down](./service-down.md) | TransactionAPIDown | Critical | 2-10 minutes |
| [Database Connection Failures](./database-errors.md) | DatabaseConnectionFailures | Critical | 5-30 minutes |
| [High Latency](./high-latency.md) | TransactionAPIHighLatency | Critical | 5-20 minutes |

---

## 🚨 Quick Reference

### When Alert Fires

1. **Acknowledge** alert in PagerDuty/Slack
2. **Open** the corresponding runbook
3. **Follow** the investigation steps
4. **Apply** the appropriate solution
5. **Verify** resolution
6. **Document** actions taken

### Runbook Structure

Each runbook contains:
- ✅ Alert description and thresholds
- 📊 Quick diagnosis queries
- 🔍 Investigation steps
- 🛠️ Common causes and solutions
- ⚡ Immediate mitigation actions
- ✅ Verification procedures
- 📝 Post-incident checklist

---

## 📖 Runbook Summaries

### [High Error Rate](./high-error-rate.md)
**Alert:** `TransactionAPIHighErrorRate`  
**Trigger:** Error rate > 1% for 5 minutes  

**Common Causes:**
- Recent deployment with bugs → **Rollback**
- Database connection issues → **Check DB health**
- Resource exhaustion → **Scale up**
- External dependency failure → **Enable fallback**

**First Actions:**
1. Check Grafana dashboard
2. Review recent deployments
3. Check application logs
4. Assess impact scope

---

### [Service Down](./service-down.md)
**Alert:** `TransactionAPIDown`  
**Trigger:** Service unreachable for 2+ minutes  

**Common Causes:**
- Pods in CrashLoopBackOff → **Check logs, fix config**
- Deployment scaled to 0 → **Scale up immediately**
- Image pull failures → **Rollback or fix registry**
- Resource constraints → **Add capacity**

**First Actions:**
1. Check pod status: `kubectl get pods -l app=transaction-api`
2. Quick triage using decision tree
3. Apply appropriate fix from runbook
4. Verify service restoration

---

### [Database Connection Failures](./database-errors.md)
**Alert:** `DatabaseConnectionFailures`  
**Trigger:** DB error rate > 0.1% for 5 minutes  

**Common Causes:**
- Database pod crashed → **Restart pod**
- Connection pool exhausted → **Scale down/increase pool**
- Slow queries → **Optimize or kill queries**
- Network issues → **Check connectivity**
- Authentication problems → **Verify credentials**

**First Actions:**
1. Check database pod status
2. Review API logs for DB errors
3. Test connectivity
4. Check connection pool utilization

---

### [High Latency](./high-latency.md)
**Alert:** `TransactionAPIHighLatency`  
**Trigger:** P95 latency > 200ms for 10 minutes  

**Common Causes:**
- High CPU usage → **Scale horizontally**
- Slow database queries → **Optimize or add indexes**
- Memory pressure/GC → **Increase memory**
- External API delays → **Implement circuit breaker**
- Traffic spike → **Scale up**
- Connection pool saturation → **Increase pool size**

**First Actions:**
1. Check resource usage
2. Identify slow endpoints
3. Check database query latency
4. Scale horizontally as quick win

---

## 🎯 Response Time Guidelines

| Severity | Target MTTD | Target MTTR | Action |
|----------|-------------|-------------|--------|
| Critical | < 2 min | < 15 min | Page immediately |
| Warning | < 5 min | < 30 min | Slack notification |
| Info | < 30 min | Best effort | Log for review |

**MTTD:** Mean Time To Detect  
**MTTR:** Mean Time To Resolve

---

## 🔧 Essential Commands

### Pod Status
```bash
kubectl get pods -l app=transaction-api
kubectl describe pod <pod-name>
kubectl logs -l app=transaction-api --tail=100
```

### Scaling
```bash
kubectl scale deployment transaction-api --replicas=5
kubectl autoscale deployment transaction-api --cpu-percent=70 --min=3 --max=10
```

### Rollback
```bash
kubectl rollout undo deployment/transaction-api
kubectl rollout status deployment/transaction-api
```

### Database
```bash
kubectl exec -it <postgres-pod> -- psql -U postgresql -d postgres
kubectl logs <postgres-pod> --tail=100
```

### Prometheus Queries
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090
```

---

## 📊 Key Metrics

### Error Rate
```promql
(sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
 sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100
```

### Latency
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m]))
```

### Request Rate
```promql
sum(rate(http_requests_total{app="transaction-api"}[5m]))
```

### Database Error Rate
```promql
(sum(rate(db_query_errors_total{app="transaction-api"}[5m])) / 
 sum(rate(db_queries_total{app="transaction-api"}[5m]))) * 100
```

---

## 🔗 Related Resources

- [Monitoring Guide](../transaction-api-monitoring-guide.md)
- [Quick Reference Card](../QUICK_REFERENCE.md)
- [Deployment Guide](../DEPLOYMENT_GUIDE.md)
- [Grafana Dashboards](../grafana/dashboards/)

---

## 📞 Escalation Contacts

| Role | Contact | When to Engage |
|------|---------|----------------|
| On-call Engineer | PagerDuty | Immediate (auto) |
| Backend Team Lead | #backend-oncall | > 5 minutes |
| Database Team | #database-oncall | DB issues > 10 min |
| Engineering Manager | [Phone] | > 15 minutes |
| Incident Commander | [Phone] | > 30 minutes |

---

## ✅ Runbook Maintenance

### Review Schedule
- **Monthly:** Review alert thresholds and update if needed
- **Quarterly:** Full runbook review and update
- **After Incidents:** Update with lessons learned

### Update Process
1. Identify gaps during incident response
2. Document improvements in ticket
3. Update runbook within 48 hours of incident
4. Review changes with team
5. Update "Last Updated" date

### Contribution Guidelines
- Keep runbooks concise and actionable
- Include actual commands, not just descriptions
- Add ETA for each solution
- Include verification steps
- Link to related resources

---

## 📝 Incident Documentation Template

After using a runbook, document:

```markdown
**Incident:** [Brief description]
**Alert:** [Alert name]
**Date/Time:** [Start - End]
**Duration:** [Minutes]
**Severity:** [Critical/High/Medium]

**Detection:**
- How was it detected?
- Time to detection?

**Investigation:**
- Runbook used: [Link]
- Root cause: [Description]
- Steps taken: [List]

**Resolution:**
- Solution applied: [Description]
- Time to resolution: [Minutes]
- Verification: [How confirmed]

**Impact:**
- Users affected: [Number/percentage]
- Transactions failed: [Number]
- Revenue impact: [$Amount]

**Follow-up:**
- [ ] Postmortem scheduled
- [ ] Runbook updated
- [ ] Monitoring improved
- [ ] Code fix deployed
- [ ] Team trained
```

---

## 🎓 Training

New team members should:
1. Read all runbooks
2. Shadow on-call engineer during alert response
3. Practice in staging environment
4. Complete runbook walkthrough session
5. Participate in game day exercises

---

**Last Updated:** 2025-11-02  
**Owner:** SRE Team  
**Contributors:** Backend Team, Database Team  
**Review Frequency:** Quarterly
