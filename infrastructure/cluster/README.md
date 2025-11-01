# Small GKE Cluster with Terraform

This Terraform configuration creates a small Google Kubernetes Engine (GKE) cluster suitable for development or testing.

## Features

- **Small footprint**: 2 nodes by default with e2-medium machine type
- **Autoscaling**: Configurable min/max node counts (1-3 by default)
- **Workload Identity**: Enabled for secure pod-to-GCP-service authentication
- **Auto-repair & Auto-upgrade**: Nodes automatically repaired and upgraded
- **Regular release channel**: Balanced stability and features

## Prerequisites

1. **Google Cloud Project**: You need a GCP project with billing enabled
2. **gcloud CLI**: Install and authenticate
   ```bash
   gcloud auth application-default login
   ```
3. **Terraform**: Install Terraform >= 1.0
4. **Enable APIs**: Enable the required APIs
   ```bash
   gcloud services enable container.googleapis.com
   gcloud services enable compute.googleapis.com
   ```

## Usage

### 1. Configure Variables

Copy the example variables file and update with your values:
```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set your `project_id`:
```hcl
project_id = "your-actual-project-id"
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Create the Cluster

```bash
terraform apply
```

Type `yes` when prompted to confirm.

### 5. Configure kubectl

Once the cluster is created, configure kubectl to connect:
```bash
gcloud container clusters get-credentials my-small-gke-cluster \
  --zone us-central1-a \
  --project your-gcp-project-id
```

### 6. Verify the Cluster

```bash
kubectl get nodes
kubectl cluster-info
```

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `project_id` | GCP project ID | (required) |
| `region` | GCP region | us-central1 |
| `zone` | GCP zone | us-central1-a |
| `cluster_name` | Name of the GKE cluster | my-gke-cluster |
| `machine_type` | Node machine type | e2-medium |
| `node_count` | Initial number of nodes | 2 |
| `min_node_count` | Minimum nodes for autoscaling | 1 |
| `max_node_count` | Maximum nodes for autoscaling | 3 |
| `use_preemptible` | Use preemptible nodes | false |

## Cost Optimization

To reduce costs:
1. Set `use_preemptible = true` (nodes can be terminated but are ~80% cheaper)
2. Use smaller machine types like `e2-small` or `e2-micro`
3. Reduce `node_count` to 1 for testing
4. Delete the cluster when not in use: `terraform destroy`

## Cleanup

To delete all resources:
```bash
terraform destroy
```

Type `yes` when prompted to confirm.

## Notes

- This creates a zonal cluster (single zone) which is cheaper than regional
- The default node pool is immediately deleted and replaced with a managed node pool
- Workload Identity is enabled for secure pod authentication
- Auto-repair and auto-upgrade are enabled for easier maintenance
