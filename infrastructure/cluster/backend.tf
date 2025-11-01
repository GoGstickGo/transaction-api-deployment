terraform {
  backend "gcs" {
    bucket = "sre-assesment-state"
    prefix = "infrastructure/cluster/terraform.tfstate"
  }
}