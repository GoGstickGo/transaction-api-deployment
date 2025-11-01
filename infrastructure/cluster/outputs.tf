output "cluster_name" {
  description = "GKE cluster name"
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = module.cluster.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "GKE cluster CA certificate"
  value       = module.cluster.cluster_ca_certificate
  sensitive   = true
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "kubernetes_version" {
  description = "Kubernetes version"
  value       = module.cluster.kubernetes_version
}
