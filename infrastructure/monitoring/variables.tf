variable "environment" {
  type = string
  default = "assesment"
}

variable "db_username" {
  type = string
}

variable "grafana_admin_password" {
  type = string
}


variable "state_bucket" {
  type    = string
  default = "sre-assesment-state"
}