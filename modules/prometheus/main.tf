

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
      environment = var.environment
    }
  }
}

# Grafana Dashboard ConfigMaps
resource "kubernetes_config_map" "grafana_dashboard_transaction_api" {
  metadata {
    name      = "grafana-dashboard-transaction-api"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "transaction-api-overview.json" = file("${path.module}/grafana/dashboards/transaction-api-overview.json")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_config_map" "grafana_dashboard_slo" {
  metadata {
    name      = "grafana-dashboard-slo"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "slo-dashboard.json" = file("${path.module}/grafana/dashboards/slo-dashboard.json")
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# Deploy Prometheus Stack using kube-prometheus-stack Helm chart
resource "helm_release" "prometheus_stack" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "55.0.0" # Use latest stable version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    file("${path.module}/values.yaml")
  ]

  # Prometheus configuration
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
    value = "ReadWriteOnce"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "50Gi"
  }

  # Grafana configuration
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "grafana.persistence.enabled"
    value = "true"
  }

  set {
    name  = "grafana.persistence.size"
    value = "10Gi"
  }

  # Enable service monitors
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ServiceMonitor for Transaction API
resource "kubectl_manifest" "transaction_api_service_monitor" {
  provider = kubectl  # Add this line
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: ServiceMonitor
    metadata:
      name: transaction-api
      namespace: monitoring
      labels:
        app: transaction-api
        release: prometheus
    spec:
      selector:
        matchLabels:
          app.kubernetes.io/name: transaction-api
      namespaceSelector:
        matchNames:
          - ${var.app_namespace}
      endpoints:
        - port: http
          path: /metrics
          interval: 15s
          scrapeTimeout: 10s
  YAML

  depends_on = [helm_release.prometheus_stack]
}


# PrometheusRule for Transaction API alerts
resource "kubectl_manifest" "transaction_api_alerts" {
  provider = kubectl  # Add this line
  yaml_body = file("${path.module}/alert-rules.yaml")

  depends_on = [helm_release.prometheus_stack]
}

# ConfigMap for additional Prometheus recording rules (SLO calculations)
resource "kubernetes_config_map" "slo_recording_rules" {
  metadata {
    name      = "slo-recording-rules"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    labels = {
      prometheus = "kube-prometheus"
    }
  }

  data = {
    "slo-rules.yaml" = file("${path.module}/slo-recording-rules.yaml")
  }

  depends_on = [helm_release.prometheus_stack]
}

# Outputs
output "prometheus_url" {
  description = "Prometheus server URL"
  value       = "http://prometheus-prometheus.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://prometheus-grafana.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local"
}

output "alertmanager_url" {
  description = "AlertManager URL"
  value       = "http://prometheus-alertmanager.${kubernetes_namespace.monitoring.metadata[0].name}.svc.cluster.local:9093"
}
