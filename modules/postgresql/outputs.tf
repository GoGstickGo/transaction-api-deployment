output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.db.name
}

output "release_namespace" {
  description = "Namespace of the Helm release"
  value       = helm_release.db.namespace
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.db.status
}

output "release_version" {
  description = "Version of the Helm release"
  value       = helm_release.db.version
}

output "chart_name" {
  description = "Name of the chart"
  value       = helm_release.db.chart
}

output "secret_name" {
  description = "Name of the secret"
  value       = "${helm_release.db.name}-credentials"
}