# Deploy the Helm chart
resource "helm_release" "app" {
  name      = var.app_name
  chart     = "${path.module}/charts/${var.chart_name}"  # ← Local chart
  namespace = var.namespace

  create_namespace = var.create_namespace

  # Merge custom values with defaults
  values = [
    file("${path.module}/charts/${var.chart_name}/values.yaml"),
    yamlencode(var.custom_values)
  ]

  wait             = var.wait
  timeout          = var.timeout
  cleanup_on_fail  = var.cleanup_on_fail
  force_update     = var.force_update
  recreate_pods    = var.recreate_pods
}