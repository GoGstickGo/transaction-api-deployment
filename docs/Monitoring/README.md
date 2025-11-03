# Transaction API Monitoring Implementation

Complete monitoring and SLO implementation for Transaction API service running on GKE with Prometheus, Grafana, and AlertManager.

## 🎯 What You Get

### 1. Complete Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization dashboards
- **AlertManager**: Alert routing and notification

### 2. Service Level Objectives (SLOs)
- API Availability: 99.95% (30-day window)
- API Latency: P95 < 200ms, P99 < 500ms
- Transaction Success Rate: 99.9%
- Transaction Processing Time: P95 < 2s, P99 < 5s
- Database Availability: 99.99%

### 3. Comprehensive Alerting
- **Critical Alerts**: 8 alerts for immediate action
- **Warning Alerts**: 9 alerts for investigation
- **SLO Burn Rate Alerts**: Multi-window burn rate tracking
- **Info Alerts**: Deployment and scaling events

### 4. Pre-built Dashboards
- **Transaction API Overview**: Main operational view with all key metrics
- **SLO Dashboard**: SLO compliance, error budgets, and burn rates

### 5. Application Instrumentation Examples
- Complete Python/Flask implementation
- Complete Node.js/Express implementation
- All required Prometheus metrics
- Best practices and patterns

## 🚀 Quick Start

### Prerequisites
- GKE cluster running
- `kubectl` configured
- Terraform installed (v1.0+)
- Helm installed (v3.0+)
- Transaction API deployed
- PostgreSQL database running

### 5-Minute Setup

1. **Configure variables:**
```bash
cd infrastucture/monitoring
# Make sure required TF_VAR_ exists 
```

2. **Deploy monitoring stack:**
```bash
make init
make plan
make apply
```

3. **Deploy updated application:**
```bash
kubectl apply -f kubernetes/transaction-api-service.yaml
# Redeploy your app with metrics instrumentation
```

5. **Access dashboards:**
```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000 (admin / your_password)

# Prometheus
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
# Open http://localhost:9090
```

## 📚 Documentation

### Primary Guides

1. **[transaction-api-monitoring-guide.md](./transaction-api-monitoring-guide.md)**
   - Complete overview and architecture
   - Detailed SLO definitions
   - Alert rules explanation
   - Best practices
   - Implementation checklist

2. **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)**
   - Step-by-step deployment instructions
   - Verification procedures
   - Testing procedures
   - Troubleshooting guide
   - Post-deployment checklist

3. **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)**
   - SLO summary table
   - Key Prometheus queries
   - Alert thresholds
   - Quick troubleshooting
   - Escalation procedures

### Configuration Files

#### Terraform (`terraform/`)
- `monitoring.tf`: Deploys entire monitoring stack including:
  - Prometheus Operator
  - Prometheus server with 15-day retention
  - AlertManager with routing
  - Grafana with pre-configured dashboards
  - PostgreSQL exporter
  - ServiceMonitors
  - PrometheusRules

- `variables.tf`: Configuration variables for:
  - Environment settings
  - Grafana credentials
  - PostgreSQL connection
  - Alert notification endpoints (Slack, PagerDuty)

#### Prometheus (`prometheus/`)
- `alert-rules.yaml`: 20+ alert rules covering:
  - API health (availability, latency, errors)
  - Transaction processing
  - Database connectivity
  - Resource utilization
  - SLO burn rates

- `slo-recording-rules.yaml`: 40+ recording rules for:
  - SLI (Service Level Indicators)
  - SLO calculations
  - Error budget tracking
  - Burn rate calculations
  - Business metrics

#### Grafana (`grafana/dashboards/`)
- `transaction-api-overview.json`: Main dashboard with:
  - Service health overview
  - Request metrics (rate, errors, latency)
  - Transaction metrics
  - Database metrics
  - Resource usage

- `slo-dashboard.json`: SLO tracking with:
  - SLO compliance status
  - Error budget gauges
  - Burn rate analysis
  - Historical trends
  - Latency tracking

## 🔧 Customization

### Adjust SLO Targets

Edit `prometheus/slo-recording-rules.yaml`:

```yaml
# Change availability target from 99.95% to 99.9%
- record: slo:api_availability:error_budget_remaining:30d
  expr: |
    1 - (slo:api_availability:error_ratio:30d / 0.001)  # Changed from 0.0005
```

### Modify Alert Thresholds

Edit `prometheus/alert-rules.yaml`:

```yaml
# Change latency threshold
- alert: TransactionAPIHighLatency
  expr: |
    histogram_quantile(0.95, ...) > 0.3  # Changed from 0.2 (300ms instead of 200ms)
```

### Add Custom Metrics

Add to your application code:

```python
# Python
from prometheus_client import Counter
custom_metric = Counter('custom_metric_total', 'Description')
custom_metric.inc()
```

```javascript
// Node.js
const customMetric = new promClient.Counter({
  name: 'custom_metric_total',
  help: 'Description'
});
customMetric.inc();
```

### Add Custom Dashboards

1. Create dashboard in Grafana UI
2. Export as JSON
3. Add to `grafana/dashboards/`
4. Create ConfigMap in `terraform/monitoring.tf`:

```hcl
resource "kubernetes_config_map" "custom_dashboard" {
  metadata {
    name      = "grafana-dashboard-custom"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "custom.json" = file("${path.module}/grafana/dashboards/custom.json")
  }
}
```

## 📊 Key Metrics

### Essential Queries

**Request Rate:**
```promql
sum(rate(http_requests_total{app="transaction-api"}[5m]))
```

**Error Rate (%):**
```promql
(sum(rate(http_requests_total{app="transaction-api",status=~"5.."}[5m])) / 
 sum(rate(http_requests_total{app="transaction-api"}[5m]))) * 100
```

**P95 Latency:**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app="transaction-api"}[5m]))
```

**SLO Compliance:**
```promql
slo:api_availability:success_ratio:30d * 100
```

**Error Budget Remaining:**
```promql
slo:api_availability:error_budget_remaining:30d * 100
```

## 🚨 Alert Overview

### Critical (Page Immediately)
- TransactionAPIDown
- TransactionAPIHighErrorRate
- TransactionAPIHighLatency
- TransactionProcessingFailureHigh
- DatabaseConnectionFailures
- DatabaseConnectionPoolExhausted
- TransactionAPIPodCrashLooping
- TransactionAPIMemoryCritical

### Warning (Team Notification)
- TransactionAPIErrorRateElevated
- TransactionAPILatencyP99High
- TransactionQueueDepthHigh
- DatabaseQueryLatencyHigh
- DatabaseConnectionPoolUtilizationHigh
- TransactionAPICPUHigh
- TransactionAPIMemoryHigh

## 🧪 Testing

After deployment, run these tests:

1. **Metrics Collection:**
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets
# Verify transaction-api target is UP
```

2. **Generate Test Traffic:**
```bash
for i in {1..100}; do
  curl -X POST http://transaction-api/api/v1/transactions \
    -H "Content-Type: application/json" \
    -d '{"from_account":"ACC001","to_account":"ACC002","amount":100,"type":"transfer"}' &
done
```

3. **Trigger Test Alert:**
```bash
kubectl scale deployment transaction-api --replicas=0
# Wait 2-3 minutes, check Prometheus alerts
kubectl scale deployment transaction-api --replicas=3
```

## 🛠️ Troubleshooting

### Prometheus Not Scraping
1. Check ServiceMonitor: `kubectl get servicemonitor -n monitoring`
2. Check Service labels match ServiceMonitor selector
3. Verify metrics endpoint: `curl http://transaction-api:8080/metrics`

### No Data in Grafana
1. Test Prometheus datasource in Grafana
2. Check time range includes data
3. Verify metrics exist in Prometheus

### Alerts Not Firing
1. Check rules loaded: `kubectl get prometheusrules -n monitoring`
2. Test alert query in Prometheus
3. Check for evaluation errors in Prometheus UI

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for detailed troubleshooting.

## 📖 Additional Resources

- [Google SRE Book - SLOs](https://sre.google/sre-book/service-level-objectives/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [The Four Golden Signals](https://sre.google/sre-book/monitoring-distributed-systems/)

## 💡 Tips for Success

1. **Start with Conservative SLOs**: It's easier to improve SLOs than to lower them
2. **Monitor Error Budgets**: Review weekly to balance reliability vs. velocity
3. **Tune Alert Thresholds**: Reduce false positives over first few weeks
4. **Create Runbooks**: Document procedures for each alert type
5. **Review Regularly**: Monthly SLO reviews with stakeholders
6. **Load Test**: Validate metrics under realistic load
7. **Practice Incident Response**: Run game days to test procedures

## 🤝 Support

For issues:
1. Check [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review Prometheus/Grafana logs
3. Verify all prerequisites are met
4. Check application logs for instrumentation errors

## 📝 Changelog

### Version 1.0 (2025-11-02)
- Initial release
- Complete monitoring stack
- 5 SLOs defined
- 20+ alert rules
- 2 Grafana dashboards
- Python and Node.js instrumentation examples
- Comprehensive documentation

---

## 🎓 Next Steps

After successful deployment:

1. ✅ Complete the verification steps in [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
2. ✅ Load test to validate metrics accuracy
3. ✅ Create runbooks for each alert type
4. ✅ Set up Slack/PagerDuty integrations
5. ✅ Train team on dashboards and alerts
6. ✅ Schedule weekly SLO review meetings
7. ✅ Document incident response procedures
8. ✅ Plan capacity based on trends

---

**Version**: 1.0  
**Last Updated**: 2025-11-02  
**License**: MIT  
**Author**: SRE Team
