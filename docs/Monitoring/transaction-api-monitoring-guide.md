# Transaction API Monitoring & SLO Implementation Guide

## Overview
This guide provides a complete monitoring solution for your Transaction API service running on GKE, including Prometheus metrics collection, Grafana dashboards, alerting rules, and SLO definitions appropriate for financial transaction systems.

## Architecture

```
Transaction API (Prometheus Metrics)
         ↓
    Prometheus (Scraping & Storage)
         ↓
    Alertmanager (Alert Routing)
         ↓
    Grafana (Visualization)
```

## Table of Contents
1. [Prometheus Stack Setup](#prometheus-stack-setup)
2. [Application Metrics Instrumentation](#application-metrics-instrumentation)
3. [SLO Definitions](#slo-definitions)
4. [Alert Rules](#alert-rules)
5. [Grafana Dashboards](#grafana-dashboards)
6. [Runbook Procedures](#runbook-procedures)

---

## 1. Prometheus Stack Setup

### 1.1 Terraform Configuration for Prometheus Stack

See `modules/prometheus/main.tf` for the complete Helm release configuration.

### 1.2 Values Configuration

See `modules/prometheus/values.yaml` for detailed Prometheus stack configuration.

---

## 2. Application Metrics Instrumentation

### 2.1 Required Metrics Categories

Your Transaction API should expose the following metric categories:

#### A. HTTP/API Metrics
- **Request Duration**: `http_request_duration_seconds` (histogram)
- **Request Count**: `http_requests_total` (counter)
- **Active Requests**: `http_requests_in_flight` (gauge)

#### B. Transaction Processing Metrics
- **Transaction Count**: `transactions_total` (counter) - labels: status, type
- **Transaction Duration**: `transaction_processing_duration_seconds` (histogram)
- **Transaction Amount**: `transaction_amount_total` (counter) - for volume tracking
- **Failed Transactions**: `transactions_failed_total` (counter) - labels: reason

#### C. Database Metrics
- **Connection Pool**: `db_connections_active`, `db_connections_idle`, `db_connections_max` (gauge)
- **Query Duration**: `db_query_duration_seconds` (histogram)
- **Query Errors**: `db_query_errors_total` (counter)

### 2.2 Metric Naming Conventions

Follow Prometheus best practices:
- Use base units (seconds, bytes)
- Suffix with unit name
- Use underscores for word separation
- Include `_total` suffix for counters
- Include `_bucket` for histogram buckets

### 2.3 Label Strategy

**Recommended labels:**
- `endpoint`: API endpoint path
- `method`: HTTP method
- `status`: HTTP status code or transaction status
- `type`: Transaction type (transfer, deposit, withdrawal)
- `priority`: Transaction priority level

---

## 3. SLO Definitions

### 3.1 Service Level Objectives for Financial Transaction API

#### SLO 1: API Availability
- **Objective**: 99.95% availability (monthly)
- **Measurement Window**: 30 days
- **Error Budget**: 21.6 minutes/month
- **SLI**: Percentage of successful HTTP requests (status code < 500)
- **Calculation**: 
  ```
  (sum(rate(http_requests_total{status!~"5.."}[30d])) / 
   sum(rate(http_requests_total[30d]))) * 100
  ```

#### SLO 2: API Latency
- **Objective**: 
  - P95 < 200ms
  - P99 < 500ms
- **Measurement Window**: 7 days rolling
- **SLI**: API response time at 95th and 99th percentile
- **Calculation**:
  ```
  histogram_quantile(0.95, 
    rate(http_request_duration_seconds_bucket[5m]))
  ```

#### SLO 3: Transaction Success Rate
- **Objective**: 99.9% successful transaction processing
- **Measurement Window**: 7 days rolling
- **Error Budget**: 0.1% failure rate
- **SLI**: Percentage of successfully processed transactions
- **Calculation**:
  ```
  (sum(rate(transactions_total{status="success"}[7d])) / 
   sum(rate(transactions_total[7d]))) * 100
  ```

#### SLO 4: Transaction Processing Time
- **Objective**: 
  - P95 < 2 seconds
  - P99 < 5 seconds
- **Measurement Window**: 24 hours rolling
- **SLI**: Transaction processing duration
- **Calculation**:
  ```
  histogram_quantile(0.95, 
    rate(transaction_processing_duration_seconds_bucket[1h]))
  ```

#### SLO 5: Database Connection Availability
- **Objective**: 99.99% database connection success rate
- **Measurement Window**: 24 hours rolling
- **SLI**: Successful database connections vs total attempts
- **Calculation**:
  ```
  (1 - (sum(rate(db_query_errors_total[24h])) / 
        sum(rate(db_queries_total[24h])))) * 100
  ```

### 3.2 Error Budget Policy

| Error Budget Remaining | Action Required |
|------------------------|-----------------|
| > 75% | Normal operations, feature development allowed |
| 50-75% | Monitor closely, prioritize reliability work |
| 25-50% | Freeze non-critical features, focus on reliability |
| < 25% | Feature freeze, all hands on reliability |
| 0% | Full incident response, postmortem required |

---

## 4. Alert Rules

### 4.1 Critical Alerts (Page Immediately)

See `modules/prometheus/alert-rules.yaml` for complete alert definitions.

**Critical Alert Criteria:**
- Immediate impact on user experience
- Revenue/transaction processing impact
- Security implications
- Data integrity risk

### 4.2 Warning Alerts (Notify Team)

See `modules/prometheus/alert-rules.yaml` for warning-level alerts.

**Warning Alert Criteria:**
- Potential future impact
- Degraded but functional service
- Resource constraints approaching limits

---

## 5. Grafana Dashboards

### 5.1 Dashboard Structure

Create three primary dashboards:

1. **Transaction API Overview** - Executive/SRE view
3. **SLO Dashboard** - SLO compliance and error budget tracking

See dashboard JSON files for complete configurations.

### 5.2 Key Panels

#### Overview Dashboard
- Request rate (QPS)
- Error rate percentage
- P95/P99 latency
- Active users
- Transaction success rate
- Error budget burn rate

#### Detailed Metrics Dashboard
- HTTP request breakdown by endpoint
- Transaction processing time by type
- Database query performance
- Connection pool utilization
- Pod CPU/Memory usage
- Network I/O

#### SLO Dashboard
- SLO compliance status (each SLO)
- Error budget remaining
- Error budget burn rate (1h, 6h, 24h, 7d)
- Historical SLO compliance
- Time to exhaustion

---

## 6. Runbook Procedures

### 6.1 High Error Rate Response

**Trigger**: Error rate > 1% for 5 minutes

**Investigation Steps:**
1. Check Grafana dashboard for error patterns
2. Review recent deployments/changes
3. Check application logs: `kubectl logs -n <namespace> -l app=transaction-api --tail=100`
4. Verify database connectivity
5. Check external dependencies

**Mitigation:**
- Rollback recent deployment if correlation found
- Scale up pods if resource-related
- Enable circuit breaker if downstream service issue

### 6.2 High Latency Response

**Trigger**: P95 latency > 200ms for 10 minutes

**Investigation Steps:**
1. Identify slow endpoints in Grafana
2. Check database query performance
3. Review database connection pool utilization
4. Check pod resource utilization
5. Investigate external API calls

**Mitigation:**
- Optimize slow database queries
- Increase connection pool size
- Scale horizontally
- Add caching layer
- Implement query timeouts

### 6.3 Transaction Processing Failures

**Trigger**: Transaction failure rate > 0.5% for 5 minutes

**Investigation Steps:**
1. Check transaction error reasons in metrics
2. Review database transaction logs
3. Verify database locks/deadlocks
4. Check account balance consistency
5. Review authentication/authorization issues

**Mitigation:**
- Implement retry logic with exponential backoff
- Review transaction isolation levels
- Optimize database indexes
- Implement idempotency checks

### 6.4 Database Connection Issues

**Trigger**: Database error rate > 0.1% for 5 minutes

**Investigation Steps:**
1. Check PostgreSQL connection limits
2. Verify network connectivity
3. Review connection pool configuration
4. Check database CPU/memory usage
5. Investigate long-running queries

**Mitigation:**
- Increase max_connections in PostgreSQL
- Tune connection pool parameters
- Kill long-running queries
- Scale database resources
- Implement connection retry logic

---

## 7. Implementation Checklist

### Phase 1: Infrastructure Setup (Week 1)
- [ ] Deploy Prometheus stack via Terraform
- [ ] Configure ServiceMonitor for Transaction API
- [ ] Configure PostgreSQL exporter
- [ ] Verify metric collection in Prometheus UI
- [ ] Set up AlertManager routing

### Phase 2: Application Instrumentation (Week 1-2)
- [ ] Add Prometheus client library to Transaction API
- [ ] Implement HTTP metrics middleware
- [ ] Add transaction processing metrics
- [ ] Add database metrics
- [ ] Add business metrics
- [ ] Verify metrics endpoint exposure

### Phase 3: Alerting Setup (Week 2)
- [ ] Deploy critical alert rules
- [ ] Deploy warning alert rules
- [ ] Configure PagerDuty/Slack integration
- [ ] Test alert firing and routing
- [ ] Document runbook procedures

### Phase 4: Dashboard Creation (Week 2-3)
- [ ] Create Overview dashboard
- [ ] Create Detailed Metrics dashboard
- [ ] Create SLO dashboard
- [ ] Share dashboards with team
- [ ] Set up dashboard as TV display

### Phase 5: SLO Tracking (Week 3-4)
- [ ] Implement SLO recording rules
- [ ] Configure error budget calculations
- [ ] Set up SLO compliance reports
- [ ] Establish error budget policy
- [ ] Train team on SLO process

### Phase 6: Validation & Tuning (Week 4)
- [ ] Load test to validate metrics accuracy
- [ ] Fine-tune alert thresholds
- [ ] Adjust SLO targets based on data
- [ ] Document lessons learned
- [ ] Conduct team training session

---

## 8. Best Practices

### Monitoring Best Practices
1. **Use RED Method**: Rate, Errors, Duration for request-driven services
2. **Use USE Method**: Utilization, Saturation, Errors for resources
3. **Instrument at boundaries**: API entry points, database calls, external services
4. **Keep cardinality low**: Limit label combinations
5. **Use histograms for latency**: Not averages

### SLO Best Practices
1. **Start conservative**: Easier to improve SLOs than to lower them
2. **Align with user experience**: SLOs should reflect user expectations
3. **Use error budgets**: Balance reliability vs feature velocity
4. **Review regularly**: Adjust based on business needs
5. **Keep it simple**: 3-5 SLOs per service maximum

### Alert Best Practices
1. **Alert on symptoms, not causes**: Alert when users are impacted
2. **Actionable alerts only**: Every alert should require human action
3. **Reduce alert fatigue**: Tune thresholds to minimize false positives
4. **Include context**: Link to dashboards and runbooks
5. **Test alerts**: Regularly verify alert routing

---

## 9. Useful Commands

### Prometheus Queries

Check API error rate:
```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) / 
sum(rate(http_requests_total[5m])) * 100
```

Check P95 latency:
```promql
histogram_quantile(0.95, 
  rate(http_request_duration_seconds_bucket[5m]))
```

Check transaction throughput:
```promql
sum(rate(transactions_total[5m]))
```

Check error budget remaining:
```promql
1 - (
  (1 - (sum(rate(http_requests_total{status!~"5.."}[30d])) / 
        sum(rate(http_requests_total[30d])))) / 
  (1 - 0.9995)
)
```

### Kubectl Commands

Check pod metrics:
```bash
kubectl top pods -n <namespace> -l app=transaction-api
```

Check application logs:
```bash
kubectl logs -n <namespace> -l app=transaction-api --tail=100 -f
```

Port forward to Prometheus:
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Port forward to Grafana:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

---

## 10. Additional Resources

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Google SRE Book - SLO Chapter](https://sre.google/sre-book/service-level-objectives/)
- [The Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)

---

## Conclusion

This monitoring setup provides comprehensive observability for your Transaction API service with appropriate SLOs for a financial system. The key success factors are:

1. **Complete visibility**: All critical metrics are captured
2. **Proactive alerting**: Issues detected before user impact
3. **Clear SLOs**: Well-defined reliability targets
4. **Actionable insights**: Dashboards and alerts lead to action
5. **Continuous improvement**: Regular review and tuning

Remember: Monitoring is not a one-time setup. Continuously review and adjust based on your service's behavior and business requirements.
