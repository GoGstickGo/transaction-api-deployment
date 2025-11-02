terraform {
  backend "gcs" {
    bucket = "sre-assesment-state"
    prefix = "infrastructure/image-repo/terraform.tfstate"
  }
}