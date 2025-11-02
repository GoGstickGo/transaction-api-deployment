
module "cluster" {
  source = "../../modules/cluster"

  project_id   = var.project_id
  cluster_name = var.cluster_name
  region       = var.region

  machine_type   = var.machine_type
  node_count     = var.node_count
  min_node_count = var.min_node_count
  max_node_count = var.max_node_count

  monitoring_disk_size_gb    = var.monitoring_disk_size_gb
  monitoring_machine_type    = var.monitoring_machine_type
  monitoring_node_count      = var.monitoring_node_count
  monitoring_labels          = var.monitoring_labels
  monitoring_max_node_count  = var.monitoring_max_node_count
  monitoring_min_node_count  = var.monitoring_min_node_count
  monitoring_use_preemptible = var.monitoring_use_preemptible
}