project_id   = "transaction-api-2446"
region       = "europe-west1"
zones        = ["europe-west1-b", "europe-west1-c", "europe-west1-d"]
cluster_name = "transaction-api-assesment"
environment  = "assesment"

# Node configuration
machine_type    = "e2-small" # 2 vCPUs, 4 GB memory
node_count      = 2
min_node_count  = 1
max_node_count  = 3
use_preemptible = true # Set to true for cost savings (nodes can be terminated)

disk_size_gb = 50

labels = {
  environment = "assesment"
  purpose     = "challenge"
}

monitoring_machine_type    = "e2-medium"
monitoring_use_preemptible = true
monitoring_node_count      = 1
monitoring_min_node_count  = 1
monitoring_max_node_count  = 3
monitoring_disk_size_gb    = 50
monitoring_labels = {
  "purpose"   = "monitoring"
  environment = "assesment"
}
