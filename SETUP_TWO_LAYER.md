# Zebo Terraform - Two-Layer Infrastructure Setup

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   PERSISTENT PLATFORM                    │
│  (Rarely destroyed - shared across environments)        │
├─────────────────────────────────────────────────────────┤
│  • Artifact Registry (Docker images)                    │
│  • Terraform State Bucket                               │
│  • Service Accounts (terraform-ci, gke-node-sa)        │
│  • IAM Bindings                                         │
│  • Shared Networking (VPC, Subnets) - future           │
│  • DNS - future                                         │
└─────────────────────────────────────────────────────────┘
                           ↓ references
┌─────────────────────────────────────────────────────────┐
│                 EPHEMERAL ENVIRONMENTS                   │
│         (Can be destroyed/recreated anytime)            │
├─────────────────────────────────────────────────────────┤
│  DEV Environment:                                       │
│    • GKE Cluster                                        │
│    • ArgoCD (via Helm)                                  │
│    • Application Secrets                                │
│                                                         │
│  PROD Environment: (future)                             │
│    • Same as dev but with prod configurations           │
└─────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start (First Time Setup)

### Step 1: Initialize Platform Layer

The platform layer creates foundational resources that should persist.

```bash
cd platform

# Initialize Terraform (uses local backend for bootstrapping)
terraform init

# Plan the platform resources
terraform plan -var-file=platform.tfvars

# Apply platform resources
terraform apply -var-file=platform.tfvars

# Note the outputs - you'll need them!
terraform output
```

**Platform creates**:
- ✅ GCS bucket: `zebraan-gcp-zebo-dev-terraform-state`
- ✅ Artifact Registry: `asia-south1-docker.pkg.dev/zebraan-gcp-zebo-dev/zebo-registry`
- ✅ Service Account: `terraform-ci@zebraan-gcp-zebo-dev.iam.gserviceaccount.com`
- ✅ Service Account: `gke-node-sa@zebraan-gcp-zebo-dev.iam.gserviceaccount.com`
- ✅ IAM bindings (terraform-ci can impersonate gke-node-sa)

### Step 2: Create Service Account Key

```bash
# From the platform directory
cd ..

# Create service account key
gcloud iam service-accounts keys create terraform-ci-key.json \
  --iam-account=terraform-ci@zebraan-gcp-zebo-dev.iam.gserviceaccount.com

# IMPORTANT: Add this to GitHub Secrets as GCP_CREDENTIALS
# Then DELETE the local file:
rm terraform-ci-key.json
```

### Step 3: Configure GitHub Repository

#### Add Secrets
Go to: Settings → Secrets and variables → Actions → Secrets

| Secret | Value |
|--------|-------|
| `GCP_CREDENTIALS` | Content of `terraform-ci-key.json` |
| `GCP_PROJECT_ID` | `zebraan-gcp-zebo-dev` |
| `ZEO_DB_PASSWORD` | Your database password |
| `ZEO_OPENAI_KEY` | Your OpenAI API key |
| `ZEO_MF_UTIL_KEY` | Your MF utility key |

#### Add Variables (Optional)
Go to: Settings → Secrets and variables → Actions → Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GCP_REGION` | `asia-south1` | GCP region |
| `MIN_NODES` | `1` | Minimum GKE nodes |
| `MAX_NODES` | `5` | Maximum GKE nodes |
| `USE_SPOT_INSTANCES` | `true` | Use spot VMs |

### Step 4: Deploy Development Environment

```bash
# Option A: Via GitHub Actions (Recommended)
git push origin main

# Option B: Locally
cd environments/dev
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars
```

### Step 5: Access ArgoCD

After deployment completes:

```bash
cd environments/dev

# Get ArgoCD URL
terraform output argocd_url

# Get ArgoCD admin password
terraform output -raw argocd_admin_password

# Or see all access info
terraform output argocd_access_info
```

Open the URL in your browser:
- Username: `admin`
- Password: (from terraform output)

## 📁 Repository Structure

```
zebo-terraform/
├── platform/                    # PERSISTENT LAYER
│   ├── main.tf                 # Platform resources
│   ├── variables.tf            # Platform variables
│   └── platform.tfvars         # Platform values
│
├── environments/                # EPHEMERAL LAYER
│   ├── dev/
│   │   ├── main.tf             # Dev environment
│   │   ├── variables.tf        # Dev variables
│   │   ├── dev.tfvars          # Dev values
│   │   └── argocd-values.yaml  # ArgoCD Helm values
│   └── prod/                   # Production (future)
│
├── modules/                     # Reusable modules
│   ├── gke/
│   ├── artifact_registry/
│   ├── secret_manager/
│   └── project/
│
└── .github/workflows/           # CI/CD
    ├── terraform-platform.yaml  # Platform deployment
    ├── terraform-create.yaml       # Dev environment
    └── terraform-destroy.yaml
```

## 🔄 Workflows

### Platform Deployment (One-Time)

**When**: Setting up for the first time, or adding new persistent resources

```bash
cd platform
terraform apply -var-file=platform.tfvars
```

**Frequency**: Rarely (only when adding DNS, networking, etc.)

### Environment Deployment (Frequent)

**When**: Deploying/updating GKE cluster, ArgoCD, or application secrets

```bash
cd environments/dev
terraform apply -var-file=dev.tfvars
```

**Frequency**: As needed (can destroy/recreate anytime)

### Destroying Environments

**Safe to destroy** (won't affect platform):
```bash
cd environments/dev
terraform destroy -var-file=dev.tfvars
```

**Persistent resources remain**:
- ✅ Artifact Registry (your Docker images are safe!)
- ✅ Terraform state bucket
- ✅ Service accounts
- ✅ IAM bindings

## 🔐 Service Account Permissions Fix

The platform layer now **automatically** grants terraform-ci permission to use gke-node-sa:

```hcl
resource "google_service_account_iam_member" "terraform_ci_can_use_gke_node_sa" {
  service_account_id = google_service_account.gke_node_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.terraform_ci.email}"
}
```

This prevents the "user does not have access to service account" error permanently!

## 🎯 ArgoCD Features

### Automatic Deployment

ArgoCD is deployed via Helm chart with:
- ✅ LoadBalancer for external access
- ✅ HTTP access (insecure mode for simplicity)
- ✅ Resource limits for cost optimization
- ✅ Initial admin password auto-generated

### Accessing ArgoCD

```bash
# Get URL and credentials
terraform output argocd_access_info

# Configure kubectl
eval $(terraform output -raw gcloud_get_credentials)

# Access via LoadBalancer
open $(terraform output -raw argocd_url)
```

## 💰 Cost Breakdown

### Platform (Always Running)
- Artifact Registry: Free tier (500MB storage)
- GCS Bucket: ~$0.10/month
- **Total: ~$0.10/month**

### Dev Environment (When Running)
- GKE Cluster: ~$20-50/month (with spot instances)
- LoadBalancer: ~$18/month
- **Total: ~$40-70/month**

### Total When Active
**~$40-70/month** (destroy dev environment when not in use!)

## 🚨 Troubleshooting

### Error: Bucket already exists

If the state bucket already exists:

```bash
cd platform

# Import existing bucket
terraform import google_storage_bucket.terraform_state zebraan-gcp-zebo-dev-terraform-state
```

### Error: Service account already exists

If service accounts already exist:

```bash
cd platform

# Import terraform-ci
terraform import google_service_account.terraform_ci projects/zebraan-gcp-zebo-dev/serviceAccounts/terraform-ci@zebraan-gcp-zebo-dev.iam.gserviceaccount.com

# Import gke-node-sa
terraform import google_service_account.gke_node_sa projects/zebraan-gcp-zebo-dev/serviceAccounts/gke-node-sa@zebraan-gcp-zebo-dev.iam.gserviceaccount.com
```

### ArgoCD LoadBalancer pending

Wait 3-5 minutes for GCP to provision the LoadBalancer. Check status:

```bash
kubectl get svc -n argocd argocd-server-lb -w
```

### Can't access ArgoCD URL

Ensure:
1. LoadBalancer has EXTERNAL-IP (not `<pending>`)
2. GKE cluster firewall allows port 80/443
3. You're using HTTP (not HTTPS) in the URL

## 📚 Next Steps

1. ✅ Platform deployed
2. ✅ Dev environment deployed
3. ✅ ArgoCD accessible
4. → Configure ArgoCD applications (in zebo-infra repo)
5. → Deploy your first app via ArgoCD

## 🔗 Related Documentation

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
