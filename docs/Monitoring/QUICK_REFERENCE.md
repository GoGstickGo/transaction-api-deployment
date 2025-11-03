# Transaction API Monitoring - Quick Reference Card

## 🎯 Service Level Objectives (SLOs)

| SLO | Target | Measurement Window | Error Budget |
|-----|--------|-------------------|--------------|
| **API Availability** | 99.95% | 30 days | 21.6 min/month |
| **API Latency (P95)** | < 200ms | 7 days | - |
| **API Latency (P99)** | < 500ms | 7 days | - |
| **Transaction Success** | 99.9% | 7 days | 0.1% failure rate |
| **Transaction Processing (P95)** | < 2 seconds | 24 hours | - |
| **Transaction Processing (P99)** | < 5 seconds | 24 hours | - |
| **Database Availability** | 99.99% | 24 hours | 0.01% error rate |

## 📊 Key Metrics

### HTTP Metrics
```promql
# Request rate
sum(rate(http_requests_total{app="transaction-api"}[5m]))

# Error rate (percentage)
(sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
 sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m]))

# P99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m]))
```

### Transaction Metrics
```promql
# Transaction throughput
sum(rate(transactions_total{app="transaction-api"}[5m]))

# Transaction success rate
(sum(rate(transactions_total{app="transaction-api",status="success"}[5m])) / 
 sum(rate(transactions_total{app="transaction-api"}[5m]))) * 100

# Transaction P95 processing time
histogram_quantile(0.95, rate(transaction_processing_duration_seconds_bucket{app="transaction-api"}[5m]))
```

### Database Metrics
```promql
# Connection pool utilization
(db_connections_active{app="transaction-api"} / db_connections_max{app="transaction-api"}) * 100

# Database error rate
(sum(rate(db_query_errors_total{app="transaction-api"}[5m])) / 
 sum(rate(db_queries_total{app="transaction-api"}[5m]))) * 100

# Database query P95 latency
histogram_quantile(0.95, rate(db_query_duration_seconds_bucket{app="transaction-api"}[5m]))
```

## 🚨 Critical Alerts

| Alert | Threshold | Action |
|-------|-----------|--------|
| **TransactionAPIDown** | Service down > 2min | Page immediately |
| **TransactionAPIHighErrorRate** | Error rate > 1% for 5min | Page immediately |
| **TransactionAPIHighLatency** | P95 > 200ms for 10min | Page immediately |
| **TransactionProcessingFailureHigh** | Failure rate > 0.5% for 5min | Page immediately |
| **DatabaseConnectionFailures** | DB error rate > 0.1% for 5min | Page immediately |
| **DatabaseConnectionPoolExhausted** | Pool > 95% for 5min | Page immediately |

## ⚠️ Warning Alerts

| Alert | Threshold | Action |
|-------|-----------|--------|
| **TransactionAPIErrorRateElevated** | Error rate > 0.5% for 10min | Investigate |
| **TransactionAPILatencyP99High** | P99 > 500ms for 15min | Investigate |
| **DatabaseQueryLatencyHigh** | P95 query time > 100ms for 10min | Investigate |
| **DatabaseConnectionPoolUtilizationHigh** | Pool > 80% for 15min | Plan scaling |
| **TransactionAPICPUHigh** | CPU > 80% for 15min | Plan scaling |
| **TransactionAPIMemoryHigh** | Memory > 80% for 15min | Plan scaling |

## 🔥 Error Budget Burn Rate

| Window | Alert Threshold | Time to Exhaustion |
|--------|----------------|-------------------|
| **1 hour** | > 14.4x normal | < 2 days |
| **6 hours** | > 6x normal | < 5 days |
| **24 hours** | > 3x normal | < 10 days |
| **7 days** | > 1x normal | < 30 days |

## 📈 Error Budget Policy

| Remaining Budget | Action |
|-----------------|--------|
| **> 75%** | Normal operations, feature development allowed |
| **50-75%** | Monitor closely, prioritize reliability work |
| **25-50%** | Feature freeze for non-critical features |
| **< 25%** | All hands on reliability improvements |
| **0%** | Full incident response, mandatory postmortem |

## 🔗 Quick Links

### Access URLs (Port Forward Required)
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
# http://localhost:9090

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# http://localhost:3000


### Grafana Dashboards
- **Transaction API - Overview**: Main operational dashboard
- **Transaction API - SLO Dashboard**: SLO compliance and error budget

### Useful kubectl Commands
```bash
# Check pod status
kubectl get pods -l app=transaction-api

# Check pod logs
kubectl logs -l app=transaction-api --tail=100 -f

# Check pod metrics
kubectl top pods -l app=transaction-api

# Describe pod
kubectl describe pod <pod-name>

# Get recent events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Check service endpoints
kubectl get endpoints transaction-api
```

## 🏃 Quick Troubleshooting

### High Error Rate
1. Check recent deployments: `kubectl rollout history deployment/transaction-api`
2. Check pod logs: `kubectl logs -l app=transaction-api --tail=100`
3. Check database connectivity: Test DB connection
4. Review recent code changes
5. Consider rollback if recent deployment

### High Latency
1. Check database query performance in Grafana
2. Check resource utilization (CPU/Memory)
3. Check database connection pool
4. Review slow query logs
5. Consider horizontal scaling

### Database Issues
1. Check PostgreSQL metrics in Grafana
2. Check connection pool utilization
3. Look for long-running queries
4. Check for deadlocks
5. Review recent schema changes

### Transaction Failures
1. Check failure reasons in Grafana: `transactions_failed_total` by reason
2. Review application logs for error details
3. Check account balance consistency
4. Verify authentication/authorization
5. Check for database constraint violations

## 📞 Escalation

| Severity | Contact | Response Time |
|----------|---------|---------------|
| **Critical** | PagerDuty → On-call SRE | Immediate |
| **High** | Slack #alerts-critical | 15 minutes |
| **Medium** | Slack #alerts-warnings | 1 hour |
| **Low** | Slack #alerts-info | Next business day |

## 📝 Incident Response Checklist

1. [ ] Acknowledge alert in PagerDuty/Slack
2. [ ] Check Grafana dashboard for context
3. [ ] Check recent deployments/changes
4. [ ] Review application logs
5. [ ] Identify root cause
6. [ ] Implement fix or rollback
7. [ ] Verify resolution
8. [ ] Document in incident tracker
9. [ ] Schedule postmortem if needed

## 🎓 Training Resources

- [Google SRE Book - SLOs](https://sre.google/sre-book/service-level-objectives/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Fundamentals](https://grafana.com/tutorials/)
- Internal: Company Runbooks (update link)
- Internal: Transaction API Documentation (update link)

---

**Last Updated**: 2025-11-02  
**Version**: 1.0  
**Owner**: SRE Team
