variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "app_namespace" {
  description = "Namespace where Transaction API is deployed"
  type        = string
  default     = "default"
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}
