terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# Get cluster info from remote state
data "terraform_remote_state" "cluster" {
  backend = "gcs"
  config = {
    bucket = var.state_bucket
    prefix = "infrastructure/cluster/terraform.tfstate"
  }
}


# Get GCP access token
data "google_client_config" "default" {}

# Get cluster details
data "google_container_cluster" "primary" {
  name     = data.terraform_remote_state.cluster.outputs.cluster_name
  location = data.terraform_remote_state.cluster.outputs.cluster_location
  project  = data.terraform_remote_state.cluster.outputs.project_id
}

# Configure Google provider
provider "google" {
  project = data.terraform_remote_state.cluster.outputs.project_id
  region  = data.terraform_remote_state.cluster.outputs.region
}

# Configure Kubernetes provider
provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

# Kubectl provider using GKE cluster
provider "kubectl" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  load_config_file       = false
}


# Configure Helm provider
provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.primary.endpoint}"
    token = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    )
    client_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.client_certificate)
    client_key         = base64decode(data.google_container_cluster.primary.master_auth.0.client_key)
  }
}

module "monitoring" {
  source = "../../modules/prometheus"

  # Set the password via TF_VAR_grafana_admin_password during runtime
  environment            = var.environment
  grafana_admin_password = var.grafana_admin_password
  app_namespace          = "transactions"
}