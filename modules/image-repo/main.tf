resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.image_repo_name
  format        = "DOCKER"
  
  # Auto-cleanup old images
  cleanup_policies {
    id     = "delete-old-images"
    action = "DELETE"
    
    condition {
      tag_state  = "TAGGED"
      older_than = "2592000s"  # 30 days
    }
  }
  
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    
    most_recent_versions {
      keep_count = 10  # Keep at least 10 versions
    }
  }
}
