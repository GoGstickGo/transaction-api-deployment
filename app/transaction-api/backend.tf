terraform {
  backend "gcs" {
    bucket = "sre-assesment-state"
    prefix = "application/transaction-api/terraform.tfstate"
  }
}