# Zebo Terraform - Infrastructure as Code

Centralized IaaC repository for provisioning GCP resources for the Zebo platform using a **two-layer architecture**.

## 🏗️ Two-Layer Architecture

### Why Two Layers?

We separate infrastructure into **persistent** and **ephemeral** layers to:
- ✅ **Protect critical resources** - Artifact Registry survives environment rebuilds
- ✅ **Enable rapid iteration** - Destroy/recreate GKE clusters without losing Docker images
- ✅ **Reduce costs** - Destroy dev environments when not in use
- ✅ **Simplify management** - Clear separation of concerns

### Layer 1: Platform (Persistent)

**Purpose**: Foundational resources that should RARELY be destroyed

**Resources**:
- Artifact Registry (Docker images)
- Terraform State Bucket
- Service Accounts (terraform-ci, gke-node-sa)
- IAM Bindings
- Future: Shared VPC, DNS, Cloud NAT

**Location**: `platform/`

**Deployment**: Manual, one-time setup

### Layer 2: Environments (Ephemeral)

**Purpose**: Resources that can be destroyed/recreated frequently

**Resources**:
- GKE Cluster
- ArgoCD (via Helm)
- Application Secrets
- LoadBalancers

**Location**: `environments/dev/`, `environments/prod/`

**Deployment**: Automated via GitHub Actions

## 📁 Repository Structure

```
zebo-terraform/
├── platform/                    # PERSISTENT LAYER ⚡
│   ├── main.tf                 # Platform resources
│   ├── variables.tf            # Platform variables
│   └── platform.tfvars         # Platform configuration
│
├── environments/                # EPHEMERAL LAYER 🔄
│   ├── dev/
│   │   ├── main.tf             # Dev environment
│   │   ├── variables.tf        # Dev variables
│   │   ├── dev.tfvars          # Dev configuration
│   │   └── argocd-values.yaml  # ArgoCD Helm values
│   └── prod/                   # Production (future)
│
├── modules/                     # SHARED MODULES
│   ├── gke/                    # GKE cluster module
│   ├── artifact_registry/      # Container registry
│   ├── secret_manager/         # Secret management
│   └── project/                # GCP API management
│
└── .github/workflows/           # CI/CD PIPELINES
    ├── terraform-platform.yaml # Platform deployment
    ├── terraform-create.yaml      # Dev environment
    └── terraform-destroy.yaml
```

## 🚀 Quick Start

### Prerequisites

- GCP project: `zebraan-gcp-zebo-dev`
- `gcloud` CLI installed
- Terraform >= 1.9.5
- GitHub repository access

### 1. Deploy Platform Layer (One-Time)

```bash
# Deploy persistent infrastructure
cd platform
terraform init
terraform apply -var-file=platform.tfvars

# Note the outputs!
terraform output
```

**Creates**:
- ✅ Artifact Registry at `asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry`
- ✅ State bucket at `zebraan-gcp-zebo-dev-terraform-state`
- ✅ Service accounts with proper IAM bindings

### 2. Configure GitHub

```bash
# Create service account key
gcloud iam service-accounts keys create key.json \
  --iam-account=terraform-ci@zebraan-gcp-zebo-dev.iam.gserviceaccount.com

# Add to GitHub Secrets: GCP_CREDENTIALS
# Then DELETE the local file!
```

Add these to GitHub Secrets:
- `GCP_CREDENTIALS` - Service account JSON
- `GCP_PROJECT_ID` - `zebraan-gcp-zebo-dev`
- `ZEO_DB_PASSWORD`, `ZEO_OPENAI_KEY`, `ZEO_MF_UTIL_KEY`

### 3. Deploy Dev Environment

```bash
# Trigger via push
git push origin main

# Or manually
cd environments/dev
terraform apply -var-file=dev.tfvars
```

**Creates**:
- ✅ GKE cluster with autoscaling (1-5 nodes, spot instances)
- ✅ ArgoCD with LoadBalancer access
- ✅ Application secrets in Secret Manager

### 4. Access ArgoCD

```bash
cd environments/dev

# Get access information
terraform output argocd_access_info

# Or specific outputs
terraform output argocd_url
terraform output -raw argocd_admin_password
```

Open the URL in browser:
- **Username**: `admin`
- **Password**: (from terraform output)

## 🔧 Key Features

### ✅ Service Account Permission Fix

The platform layer automatically grants terraform-ci permission to impersonate gke-node-sa, preventing the common error:

```
Error 400: The user does not have access to service account "gke-node-sa@..."
```

This is handled permanently in `platform/main.tf`:
```hcl
resource "google_service_account_iam_member" "terraform_ci_can_use_gke_node_sa" {
  service_account_id = google_service_account.gke_node_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.terraform_ci.email}"
}
```

### ✅ ArgoCD Auto-Deployment

ArgoCD is automatically deployed via Helm with:
- LoadBalancer for external access
- HTTP mode (insecure) for simplicity
- Resource limits for cost optimization
- Admin password auto-generated

### ✅ Cost Optimization

- Spot instances enabled by default (70% cost reduction)
- Resource limits on all ArgoCD components
- Autoscaling (1-5 nodes) based on workload
- Can destroy dev environment when not in use

**Estimated costs**:
- Platform (always running): **~$0.10/month**
- Dev environment (when active): **~$40-70/month**

## 🔄 Common Workflows

### Deploy New Environment

```bash
cd environments/dev
terraform apply -var-file=dev.tfvars
```

### Update GKE Configuration

```bash
# Edit variables
vim environments/dev/dev.tfvars

# Apply changes
terraform apply -var-file=dev.tfvars
```

### Destroy Dev Environment (Save Costs!)

```bash
cd environments/dev
terraform destroy -var-file=dev.tfvars
```

**Your Docker images are safe** - they remain in Artifact Registry!

### Rebuild Dev Environment

```bash
cd environments/dev
terraform apply -var-file=dev.tfvars
```

Recreates GKE and ArgoCD, pulls images from Artifact Registry.

## 📊 Infrastructure Diagram

```
┌─────────────────────────────────────────────────────┐
│              PLATFORM LAYER (Persistent)            │
│  • Artifact Registry: Docker images                │
│  • State Bucket: Terraform state                   │
│  • terraform-ci SA: CI/CD automation               │
│  • gke-node-sa: GKE node identity                  │
│  • IAM: terraform-ci → gke-node-sa permission      │
└─────────────────────────────────────────────────────┘
                         ↓ references
┌─────────────────────────────────────────────────────┐
│           DEV ENVIRONMENT (Ephemeral)               │
│  • GKE Cluster (1-5 nodes, spot instances)         │
│  • ArgoCD (Helm + LoadBalancer)                    │
│  • Secrets (Secret Manager)                        │
└─────────────────────────────────────────────────────┘
                         ↓ deploys to
┌─────────────────────────────────────────────────────┐
│            APPLICATIONS (zebo-infra repo)           │
│  • Kubernetes manifests                            │
│  • Helm charts                                     │
│  • ArgoCD ApplicationSets                          │
└─────────────────────────────────────────────────────┘
```

## 🚨 Troubleshooting

### Platform Resources Already Exist

If you already have resources from previous setup:

```bash
cd platform

# Import existing resources
terraform import google_storage_bucket.terraform_state zebraan-gcp-zebo-dev-terraform-state
terraform import google_service_account.terraform_ci projects/zebraan-gcp-zebo-dev/serviceAccounts/terraform-ci@zebraan-gcp-zebo-dev.iam.gserviceaccount.com
terraform import google_service_account.gke_node_sa projects/zebraan-gcp-zebo-dev/serviceAccounts/gke-node-sa@zebraan-gcp-zebo-dev.iam.gserviceaccount.com
```

### ArgoCD LoadBalancer Pending

Wait 3-5 minutes for GCP to provision the LoadBalancer:

```bash
kubectl get svc -n argocd argocd-server-lb -w
```

### Can't Access ArgoCD

1. Check LoadBalancer has EXTERNAL-IP
2. Use HTTP (not HTTPS): `http://X.X.X.X`
3. Verify firewall rules allow port 80

## 📚 Documentation

- **[SETUP_TWO_LAYER.md](./SETUP_TWO_LAYER.md)** - Detailed setup guide
- **[POST_MIGRATION_CHECKLIST.md](./POST_MIGRATION_CHECKLIST.md)** - Migration tasks

## 🔗 Related Repositories

- **[zebo-infra](https://github.com/YOUR_ORG/zebo-infra)** - Kubernetes manifests and ArgoCD applications
- **[zebo](https://github.com/YOUR_ORG/zebo)** - Application code

## 🤝 Contributing

1. Platform changes → Create PR to `platform/`
2. Environment changes → Create PR to `environments/`
3. Module changes → Create PR to `modules/`
4. Test locally before committing
5. CI/CD will validate on PR

## 📄 License

See [LICENSE](LICENSE) file.

---

**Status**: ✅ Two-layer architecture implemented  
**ArgoCD**: ✅ Auto-deployed with LoadBalancer  
**Cost Optimization**: ✅ Spot instances + destroyable environments
