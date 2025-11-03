variable "environment" {
  type = string
  default = "assesment"
}

variable "grafana_admin_password" {
  type = string
}


variable "state_bucket" {
  type    = string
  default = "sre-assesment-state"
}

variable "app_namespace" {
  type = string
}