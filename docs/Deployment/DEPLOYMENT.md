# Deployment Guide

This guide walks you through deploying the complete infrastructure and application stack for the Transaction API on Google Kubernetes Engine (GKE).

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Order](#deployment-order)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Application Deployment](#application-deployment)
6. [Verification](#verification)
7. [Monitoring Setup](#monitoring-setup)
8. [Rollback Procedures](#rollback-procedures)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

Ensure you have these tools installed:

```bash
# Check versions
terraform --version    # >= 1.0.0
kubectl version       # >= 1.20.0
helm version         # >= 3.0.0
gcloud --version     # Latest
make --version       # Any recent version
```

### Install Missing Tools

```bash
# Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads

# kubectl
gcloud components install kubectl

# Helm
brew install helm  # macOS
# or https://helm.sh/docs/intro/install/

# gcloud CLI
# https://cloud.google.com/sdk/docs/install
```

### GCP Setup

```bash
# Authenticate
gcloud auth login
gcloud auth application-default login

# Set project
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
```

### Access Requirements

- **GCP Project** with billing enabled
- **IAM Permissions:**
  - `roles/container.admin` (GKE)
  - `roles/compute.admin` (Compute Engine)
  - `roles/artifactregistry.admin` (Artifact Registry)
  - `roles/storage.admin` (GCS for Terraform state)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         GCP Project                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │ Artifact       │  │ GCS Bucket      │  │ GKE Cluster  │ │
│  │ Registry       │  │ (Terraform      │  │              │ │
│  │ (Docker Images)│  │  State)         │  │              │ │
│  └────────────────┘  └─────────────────┘  └──────┬───────┘ │
│                                                    │          │
│         ┌──────────────────────────────────────────┘         │
│         │                                                     │
│  ┌──────▼───────────────────────────────────────────────┐   │
│  │              GKE Cluster Namespaces                   │   │
│  ├───────────────────────────────────────────────────────┤   │
│  │                                                        │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │   │
│  │  │transactions │  │  monitoring   │  │kube-system  │ │   │
│  │  │             │  │               │  │             │ │   │
│  │  │ • Trans API │  │ • Prometheus  │  │ • CoreDNS   │ │   │
│  │  │ • PostgreSQL│  │ • Grafana     │  │ • etc       │ │   │
│  │  │             │  │ • AlertMgr    │  │             │ │   │
│  │  └─────────────┘  └──────────────┘  └─────────────┘ │   │
│  └────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Deployment Order

**CRITICAL: Deploy in this exact order to avoid dependency issues.**

```
1. infrastructure/image-repo     → Artifact Registry for Docker images
2. infrastructure/cluster        → GKE cluster
3. infrastructure/monitoring     → Prometheus, Grafana, AlertManager
4. app/transaction-api          → Transaction API application
```

---

## Infrastructure Deployment

### Step 1: Deploy Artifact Registry

**Purpose:** Create Docker image repository for the Transaction API.

```bash
cd infrastructure/image-repo

# Review configuration
cat terraform.tfvars

# Initialize Terraform
make init

# Review plan
make plan

# Deploy
make apply

# Verify
make verify
```

**Expected output:**
```
✓ Artifact Registry repository created
✓ Repository URL: <region>-docker.pkg.dev/<project>/transaction-api
```

**Time estimate:** 2-3 minutes

---

### Step 2: Deploy GKE Cluster

**Purpose:** Create the Kubernetes cluster that will host all applications.

```bash
cd infrastructure/cluster

# Review and customize configuration
cat terraform.tfvars
# Edit if needed: cluster size, machine types, regions, etc.

# Initialize Terraform
make init

# Review plan (IMPORTANT: Review resource costs)
make plan

# Deploy
make apply
# This will take 10-15 minutes

# Configure kubectl
make configure-kubectl

# Verify cluster
make verify
```

**Expected output:**
```
✓ GKE cluster created
✓ Node pools ready
✓ kubectl configured
✓ Cluster accessible
```

**Time estimate:** 10-15 minutes

**Verify cluster:**
```bash
kubectl get nodes
kubectl get namespaces
kubectl cluster-info
```

---

### Step 3: Deploy Monitoring Stack

**Purpose:** Deploy Prometheus, Grafana, and AlertManager for observability.

```bash
cd infrastructure/monitoring

# Review configuration
cat terraform.tfvars

# Set required variables
export TF_VAR_grafana_admin_password="your-secure-password"

# Initialize Terraform
make init

# Review plan
make plan

# Deploy
make apply
# This will take 3-5 minutes

# Verify
make verify
```

**Expected output:**
```
✓ Prometheus deployed
✓ Grafana deployed
✓ AlertManager deployed
✓ ServiceMonitors configured
```

**Time estimate:** 3-5 minutes

**Access monitoring services:**
```bash
# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Open http://localhost:3000 (admin / your-password)

# Prometheus/AlertManager
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
# Open http://localhost:9090

```

---

## Application Deployment

### Step 4: Build and Push Docker Image

**Before deploying the app, you need a Docker image.**

```bash
# Navigate to your application source code
cd /path/to/transaction-api-source

# Build image
docker build -t <region>-docker.pkg.dev/<project>/transaction-api/transaction-api:v1.0.0 .

# Authenticate with Artifact Registry
gcloud auth configure-docker <region>-docker.pkg.dev

# Push image
docker push <region>-docker.pkg.dev/<project>/transaction-api/transaction-api:v1.0.0
```

---

### Step 5: Deploy Transaction API

**Purpose:** Deploy the Transaction API application with PostgreSQL database.

```bash
cd app/transaction-api

# Set DB PASSWORD / DB_USERNAM
export TF_VAR_db_username="username"
export TF_VAR_db_password="db_password"

# Update main.tf if neccessary under custom_values to overwrite values from module

# Initialize Terraform
make init

# Review plan
make plan

# Deploy
make apply
# This will take 3-5 minutes

# Verify
make verify
```

**Expected output:**
```
✓ PostgreSQL deployed
✓ Transaction API deployed
✓ Services created
```

**Time estimate:** 3-5 minutes

**Verify application:**
```bash
# Check pods
kubectl get pods -n transactions

# Check services
kubectl get svc -n transactions

# Check logs
kubectl logs -n transactions -l app.kubernetes.io/name=transaction-api

# Test API
kubectl port-forward -n transactions svc/transaction-api 8080:8080
curl http://localhost:8080/health
```

---

## Verification

### Complete System Check

Run these commands to verify everything is working:

```bash
# 1. Check all namespaces
kubectl get namespaces

# 2. Check all pods
kubectl get pods --all-namespaces

# 3. Check services
kubectl get svc --all-namespaces

# 4. Check if Transaction API is exposing metrics
kubectl port-forward -n transactions svc/transaction-api 8080:8080
curl http://localhost:8080/metrics | head -20

# 5. Check if Prometheus is scraping Transaction API
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
# Go to http://localhost:9090/targets
# Search for "transaction-api" - should be UP

# 6. Check Grafana dashboards
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Go to http://localhost:3000
# Login and verify dashboards exist

# 7. Test Transaction API endpoint
kubectl port-forward -n transactions svc/transaction-api 8080:8080
curl -X POST http://localhost:8080/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{"value": 100, "timestamp": "2025-11-02T12:00:00Z"}'
```

---

## Monitoring Setup

### Initial Configuration

After deployment, complete these monitoring setup steps:

#### 1. Access Grafana

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

- URL: http://localhost:3000
- Username: `admin`
- Password: (from terraform.tfvars)

#### 2. Verify Dashboards

Navigate to:
- **Dashboards** → **Transaction API - Overview**
- **Dashboards** → **Transaction API - SLO Dashboard**

#### 3. Configure Alerts

Check AlertManager:
```bash
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
```

URL: http://localhost:9090

#### 4. Setup Notifications

Edit monitoring configuration to add:
- Slack webhook URL
- PagerDuty integration key
- Email SMTP settings

```bash
cd infrastructure/monitoring
# Edit terraform.tfvars
# Add notification settings
make apply
```

---

## Makefile Commands Reference

Each component has a Makefile with these common commands:

### Infrastructure Components

```bash
# In infrastructure/image-repo, infrastructure/cluster, infrastructure/monitoring

make init          # Initialize Terraform
make plan          # Show execution plan
make apply         # Apply changes
make destroy       # Destroy resources
make verify        # Verify deployment
make output        # Show outputs
make clean         # Clean Terraform files
```

### Application Components

```bash
# In app/transaction-api

make init          # Initialize Terraform
make plan          # Show execution plan
make apply         # Apply changes
make destroy       # Destroy resources
make verify        # Verify deployment
make logs          # Show application logs
make port-forward  # Port forward to service
```

### Special Commands

```bash
# infrastructure/cluster
make configure-kubectl  # Configure kubectl access

# infrastructure/monitoring
make grafana            # Port forward to Grafana
make prometheus         # Port forward to Prometheus
```

---

## Rollback Procedures

### Rollback Application

```bash
cd app/transaction-api

# Option 1: Rollback via Terraform
export TF_VAR_image_tag="v0.9.0"  # Previous version
make apply

# Option 2: Rollback via kubectl
kubectl rollout undo deployment/transaction-api -n transactions

# Option 3: Rollback to specific revision
kubectl rollout history deployment/transaction-api -n transactions
kubectl rollout undo deployment/transaction-api -n transactions --to-revision=2
```

### Rollback Infrastructure

```bash
# Rollback monitoring
cd infrastructure/monitoring
git checkout HEAD~1  # Previous commit
make apply

# Rollback cluster (DANGEROUS - avoid if possible)
cd infrastructure/cluster
# Better to update configuration and apply rather than destroy
```

---

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n transactions

# Describe pod for events
kubectl describe pod <pod-name> -n transactions

# Check logs
kubectl logs <pod-name> -n transactions

# Common issues:
# - ImagePullBackOff: Image doesn't exist or auth issue
# - CrashLoopBackOff: Application error, check logs
# - Pending: Resource constraints or node affinity issues
```

### No Metrics in Prometheus

```bash
# 1. Check if app exposes metrics
kubectl port-forward -n transactions svc/transaction-api 8080:8080
curl http://localhost:8080/metrics

# 2. Check ServiceMonitor
kubectl get servicemonitor -n monitoring transaction-api

# 3. Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-prometheus 9090:9090
# Go to http://localhost:9090/targets

# 4. Check logs
kubectl logs -n monitoring -l app=prometheus
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n transactions -l app=postgresql

# Check PostgreSQL logs
kubectl logs -n transactions <postgres-pod>

# Test connection from Transaction API pod
kubectl exec -it -n transactions <transaction-api-pod> -- /bin/sh
# Inside pod:
nc -zv postgresql 5432
```

### Terraform State Issues

```bash
# State locked
terraform force-unlock <lock-id>

# State out of sync
terraform refresh

# Import existing resource
terraform import <resource_type>.<resource_name> <resource_id>
```

### Access Issues

```bash
# Re-authenticate
gcloud auth login
gcloud auth application-default login

# Get cluster credentials again
gcloud container clusters get-credentials <cluster-name> --region <region>

# Check RBAC
kubectl auth can-i --list --as=system:serviceaccount:transactions:default
```

---

## Cleanup / Teardown

**WARNING: This will destroy all resources and data!**

### Complete Teardown (in reverse order)

```bash
# 1. Destroy application
cd app/transaction-api
make destroy

# 2. Destroy monitoring
cd infrastructure/monitoring
make destroy

# 3. Destroy cluster
cd infrastructure/cluster
make destroy

# 4. Destroy image repo
cd infrastructure/image-repo
make destroy
```

### Partial Cleanup

```bash
# Only destroy application (keep infrastructure)
cd app/transaction-api
make destroy

# Scale down instead of destroy
kubectl scale deployment transaction-api --replicas=0 -n transactions
```

---

## Deployment Checklist

Use this checklist for production deployments:

### Pre-Deployment

- [ ] All prerequisites installed and configured
- [ ] GCP project and billing verified
- [ ] IAM permissions confirmed
- [ ] Terraform state backend configured
- [ ] Docker image built and pushed
- [ ] Configuration files reviewed
- [ ] Secrets and credentials prepared
- [ ] Backup plan documented

### Deployment

- [ ] Deploy image-repo (Step 1)
- [ ] Deploy cluster (Step 2)
- [ ] Deploy monitoring (Step 3)
- [ ] Deploy application (Step 4)
- [ ] Verify each step before proceeding

### Post-Deployment

- [ ] All pods running
- [ ] Services accessible
- [ ] Metrics being collected
- [ ] Dashboards showing data
- [ ] Alerts configured
- [ ] Monitoring verified
- [ ] API tested
- [ ] Documentation updated
- [ ] Team notified

### Production Readiness

- [ ] SSL/TLS configured
- [ ] Ingress configured
- [ ] DNS records updated
- [ ] Backups configured
- [ ] Disaster recovery tested
- [ ] Runbooks reviewed
- [ ] On-call rotation established
- [ ] Monitoring alerts tested

---

## Quick Reference

### Common Commands

```bash
# Get cluster credentials
gcloud container clusters get-credentials <cluster> --region <region>

# Switch context
kubectl config use-context <context>

# View all resources
kubectl get all --all-namespaces

# Port forward to service
kubectl port-forward -n <namespace> svc/<service> <local-port>:<service-port>

# View logs
kubectl logs -n <namespace> -l app=<app-name> --tail=100 -f

# Execute command in pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh

# Apply configuration
kubectl apply -f <file>

# Restart deployment
kubectl rollout restart deployment/<name> -n <namespace>
```

### Important URLs

- **GCP Console:** https://console.cloud.google.com
- **Terraform Registry:** https://registry.terraform.io
- **Kubernetes Docs:** https://kubernetes.io/docs
- **Helm Hub:** https://artifacthub.io

---

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section
2. Review component-specific READMEs
3. Check application logs
4. Review Terraform state
5. Contact infrastructure team

---

**Last Updated:** 2025-11-02  
**Version:** 1.0  
**Maintained By:** Infrastructure Team
