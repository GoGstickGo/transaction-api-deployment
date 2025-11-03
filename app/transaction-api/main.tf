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

module "postgresql" {
  source = "../../modules/postgresql"

  db_name    = "postgresql"
  chart_name = "postgresql"
  namespace  = "transactions"

  custom_values = {
    postgresql = {
      # Set the username and password via TF_VAR_db_username and TF_VAR_db_password during runtime
      username = var.db_username
      password = var.db_password
      database = "transactions"
    }
  }
}

module "transaction-api" {
  source = "../../modules/transaction-api"

  app_name   = "transaction-api"
  chart_name = "transaction-api"
  namespace  = "transactions"
  timeout    = 120

  depends_on = [module.postgresql]


  custom_values = {
    image = {
      tag = "v0.0.2"
    }
    env = [
      {
        name = "DATABASE_URL"
        secretRef = {
          name = module.postgresql.secret_name
          key  = "postgres-url"
        }
      }
    ]
  }
}