variable "db_password" {
  type = string
  sensitive = true
}

variable "db_username" {
  type = string
}

variable "state_bucket" {
  type = string
  default = "sre-assesment-state"
}