terraform {
  backend "gcs" {
    bucket = "sre-assesment-state"
    prefix = "infrastructure/monitoring/terraform.tfstate"
  }
}