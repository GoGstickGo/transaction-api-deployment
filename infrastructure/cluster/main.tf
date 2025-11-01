
module "cluster" {
  source = "../../modules/cluster"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region

  machine_type   = var.machine_type
  node_count     = var.node_count
  min_node_count = var.min_node_count
  max_node_count = var.max_node_count
}