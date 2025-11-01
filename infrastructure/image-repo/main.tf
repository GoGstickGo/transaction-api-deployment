
module "image-repo" {
  source          = "../../modules/image-repo"
  project_id      = var.project_id
  region          = var.region
  image_repo_name = var.image_repo_name

}