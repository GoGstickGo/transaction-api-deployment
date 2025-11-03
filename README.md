# Transaction API

Complete infrastructure-as-code setup for deploying a production-ready Transaction API on Google Kubernetes Engine (GKE) with comprehensive monitoring and observability.

---

## 🏗️ Overview

This repository contains Terraform modules and Helm charts for deploying:

- **GKE Cluster** - Google Kubernetes Engine cluster with autoscaling
- **Transaction API** - RESTful API for transaction processing
- **PostgreSQL Database** - Persistent data storage
- **Monitoring Stack** - Prometheus, Grafana, AlertManager
- **Observability** - Metrics, alerts, dashboards, and SLO tracking

---

## 📁 Repository Structure

```
.
├── app/
│   └── transaction-api/          # Transaction API application deployment
├── infrastructure/
│   ├── cluster/                  # GKE cluster infrastructure
│   ├── image-repo/               # Docker image artifact registry
│   └── monitoring/               # Prometheus monitoring stack
├── modules/
│   ├── cluster/                  # Reusable GKE cluster module
│   ├── image-repo/               # Reusable image repository module
│   ├── postgresql/               # PostgreSQL Helm chart module
│   ├── prometheus/               # Prometheus stack module
│   └── transaction-api/          # Transaction API Helm chart module
├── docs/
│   ├── Deployment/               # Deployment guides
│   ├── Monitoring/               # Monitoring setup and guides
│   └── RunBooks/                 # Operational runbooks
└── README.md                     # This file
```

---

## 📚 Documentation

### 🚀 Deployment

| Document | Description |
|----------|-------------|
| **[DEPLOYMENT.md](docs/Deployment/DEPLOYMENT.md)** | Complete step-by-step deployment guide with prerequisites, deployment order, verification steps, and troubleshooting |

**Key Topics:**
- Prerequisites and tool setup
- Infrastructure deployment (image-repo, cluster, monitoring)
- Application deployment (Transaction API + PostgreSQL)
- Verification procedures
- Rollback strategies
- Cleanup/teardown instructions

---

### 📊 Monitoring

| Document | Description |
|----------|-------------|
| **[README.md](docs/Monitoring/README.md)** | Monitoring overview, architecture, and quick start guide |
| **[transaction-api-monitoring-guide.md](docs/Monitoring/transaction-api-monitoring-guide.md)** | Complete monitoring implementation guide with SLOs, alerts, and dashboards |
| **[QUICK_REFERENCE.md](docs/Monitoring/QUICK_REFERENCE.md)** | Quick reference card for SLOs, metrics queries, alerts, and troubleshooting |

**Key Topics:**
- Prometheus metrics collection
- Grafana dashboard setup
- Service Level Objectives (SLOs)
- Alert rules and thresholds
- Error budget tracking
- Application instrumentation examples (Python/Node.js)

---

### 🔧 Operational Runbooks

| Runbook | Alert | Description |
|---------|-------|-------------|
| **[README.md](docs/RunBooks/README.md)** | - | Runbooks overview and quick reference |
| **[high-error-rate.md](docs/RunBooks/high-error-rate.md)** | TransactionAPIHighErrorRate | Error rate > 1% - deployment issues, database problems, resource exhaustion |
| **[service-down.md](docs/RunBooks/service-down.md)** | TransactionAPIDown | Complete service outage - pod crashes, scaling issues, network problems |
| **[database-errors.md](docs/RunBooks/database-errors.md)** | DatabaseConnectionFailures | DB error rate > 0.1% - connection pool, slow queries, network issues |
| **[high-latency.md](docs/RunBooks/high-latency.md)** | TransactionAPIHighLatency | P95 > 200ms - CPU pressure, slow queries, external API delays |

**Each runbook includes:**
- Alert description and thresholds
- Quick diagnosis steps with PromQL queries
- Common causes and solutions
- Step-by-step investigation procedures
- Verification steps
- Escalation procedures

---

## 🏛️ Architecture

### Infrastructure Components

```
┌─────────────────────────────────────────────────────────┐
│                      GCP Project                         │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   Artifact   │  │  GCS Bucket  │  │ GKE Cluster  │  │
│  │   Registry   │  │  (TF State)  │  │              │  │
│  └──────────────┘  └──────────────┘  └──────┬───────┘  │
│                                               │           │
│       ┌───────────────────────────────────────┘          │
│       │                                                   │
│  ┌────▼──────────────────────────────────────────────┐  │
│  │           GKE Cluster Namespaces                   │  │
│  ├────────────────────────────────────────────────────┤  │
│  │  ┌──────────────┐  ┌──────────────┐              │  │
│  │  │transactions  │  │  monitoring   │              │  │
│  │  │              │  │               │              │  │
│  │  │• Trans API   │  │• Prometheus   │              │  │
│  │  │• PostgreSQL  │  │• Grafana      │              │  │
│  │  │              │  │• AlertManager │              │  │
│  │  └──────────────┘  └──────────────┘              │  │
│  └────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Monitoring Flow

```
Transaction API (App)
         ↓ (exposes /metrics)
    Prometheus (scrapes metrics)
         ↓
    ┌────┴────┐
    ↓         ↓
Grafana   AlertManager
(visualize) (notify)
```

---

## 🔑 Key Features

### Infrastructure
✅ **Multi-zone GKE cluster** with autoscaling  
✅ **Managed node pools** with auto-repair and auto-upgrade  
✅ **Artifact Registry** for Docker images  
✅ **Infrastructure as Code** - Complete Terraform setup  
✅ **Makefile automation** - Simple deployment commands  

### Application
✅ **Horizontal Pod Autoscaling** (HPA)  
✅ **Pod Disruption Budgets** (PDB)  
✅ **Health checks** and liveness probes  
✅ **Resource limits** and requests  
✅ **Pod anti-affinity** for high availability  


---

## 🛠️ Technologies Used

| Category | Technology |
|----------|-----------|
| **Cloud Provider** | Google Cloud Platform (GCP) |
| **Container Orchestration** | Google Kubernetes Engine (GKE) |
| **Infrastructure as Code** | Terraform |
| **Package Management** | Helm |
| **Monitoring** | Prometheus, Grafana, AlertManager |
| **Database** | PostgreSQL |
| **Programming** | Go (Transaction API) |

---

## 🤝 Contributing

### Development Workflow

1. Create feature branch
2. Make changes
3. Test locally
4. Run `terraform plan` to preview changes
5. Submit pull request
6. Deploy to staging first
7. Verify in staging
8. Deploy to production

### Code Standards

- Use Terraform formatting: `terraform fmt -recursive`
- Validate Terraform: `terraform validate`
- Lint Kubernetes manifests: `helm lint`
- Follow existing naming conventions
- Document all variables and outputs

---

## 📞 Support

### Getting Help

1. Check [Troubleshooting](#troubleshooting) section
2. Review [Deployment Guide](docs/Deployment/DEPLOYMENT.md)
3. Consult [Runbooks](docs/RunBooks/README.md)
4. Check application/infrastructure logs
5. Contact infrastructure team

### Escalation

For critical production issues, see [Runbooks Escalation Procedures](docs/RunBooks/README.md#escalation-path)


## 🙏 Acknowledgments

- Prometheus and Grafana communities
- Google Cloud Platform documentation
- Terraform and Helm communities
- SRE best practices from Google SRE Book

---

## 📅 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-02 | Initial release with complete infrastructure and monitoring |

---

**Maintained By:** Infrastructure Team  
**Last Updated:** 2025-11-02  
**Status:** Production Ready ✅
