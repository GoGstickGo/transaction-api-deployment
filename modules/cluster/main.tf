# GKE cluster
resource "google_container_cluster" "primary" {
  name           = var.cluster_name
  location       = var.region
  node_locations = var.zones

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = "default"
  subnetwork = "default"

  # Disable basic authentication and client certificate
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
  }
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  node_config {
    preemptible  = var.use_preemptible
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb


    # OAuth scopes for GCP services
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = var.labels

    tags = ["gke-node", "${var.cluster_name}-node"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }
}
