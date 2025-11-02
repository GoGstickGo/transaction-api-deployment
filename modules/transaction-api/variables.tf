variable "app_name" {
  description = "Name of the Helm release"
  type        = string
}

variable "chart_name" {
  description = "Name of the chart directory (under charts/)"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "create_namespace" {
  description = "Create namespace if it doesn't exist"
  type        = bool
  default     = true
}

variable "values_files" {
  description = "List of values files relative to module (e.g., ['charts/myapp/values.yaml'])"
  type        = list(string)
  default     = null
}

variable "custom_values" {
  description = "Custom values to override"
  type        = any
  default     = {}
}

variable "wait" {
  description = "Wait for resources to be ready"
  type        = bool
  default     = true
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 300
}

variable "cleanup_on_fail" {
  description = "Cleanup resources on failure"
  type        = bool
  default     = true
}

variable "force_update" {
  description = "Force resource update"
  type        = bool
  default     = false
}

variable "recreate_pods" {
  description = "Recreate pods on chart update"
  type        = bool
  default     = false
}