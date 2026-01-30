# 🚀 Quick Reference - Two-Layer Terraform

## Architecture at a Glance

```
PLATFORM (Persistent)          ENVIRONMENTS (Ephemeral)
├── Artifact Registry    →     ├── GKE Cluster
├── State Bucket        →     ├── ArgoCD (Helm)
├── terraform-ci SA     →     ├── Secrets
└── gke-node-sa        →     └── LoadBalancers
```

## 🎯 Common Commands

### Deploy Platform (One-Time)
```bash
cd platform
terraform init
terraform apply -var-file=platform.tfvars
```

### Deploy Dev Environment
```bash
cd environments/dev
terraform init
terraform apply -var-file=dev.tfvars
```

### Access ArgoCD
```bash
cd environments/dev
terraform output argocd_url
terraform output -raw argocd_admin_password
```

### Destroy Dev (Save Costs!)
```bash
cd environments/dev
terraform destroy -var-file=dev.tfvars
# Artifact Registry persists! 🎉
```

### Rebuild Dev
```bash
cd environments/dev
terraform apply -var-file=dev.tfvars
# Pulls from Artifact Registry
```

## 🔐 GitHub Secrets Required

| Secret | Value |
|--------|-------|
| `GCP_CREDENTIALS` | terraform-ci service account JSON |
| `GCP_PROJECT_ID` | `zebraan-gcp-zebo-dev` |
| `ZEO_DB_PASSWORD` | Your database password |
| `ZEO_OPENAI_KEY` | Your OpenAI API key |
| `ZEO_MF_UTIL_KEY` | Your MF utility key |

## 📊 Cost Breakdown

| Layer | Always On | When Active |
|-------|-----------|-------------|
| Platform | $0.10/mo | $0.10/mo |
| Dev Env | $0 | $40-70/mo |
| **Total** | **$0.10/mo** | **$40-70/mo** |

💡 **Tip**: Destroy dev when not in use!

## 🎯 Key Outputs

```bash
# From platform/
terraform output terraform_state_bucket
terraform output artifact_registry_url
terraform output terraform_ci_email

# From environments/dev/
terraform output gke_cluster_name
terraform output argocd_url
terraform output argocd_access_info
terraform output -raw argocd_admin_password
```

## 🚨 Error Fixed!

**Before**:
```
Error 400: user does not have access to service account "gke-node-sa@..."
```

**After** (platform layer creates IAM binding):
```
✅ terraform-ci can impersonate gke-node-sa
✅ GKE node pool creation succeeds
✅ Error fixed permanently!
```

## 📁 File Locations

| Resource | Location |
|----------|----------|
| Platform | `platform/main.tf` |
| Dev Env | `environments/dev/main.tf` |
| ArgoCD Config | `environments/dev/argocd-values.yaml` |
| Platform Workflow | `.github/workflows/terraform-platform.yaml` |
| Dev Workflow | `.github/workflows/terraform-create.yaml` |

## 🔄 Typical Workflow

```bash
# 1. Platform (once)
cd platform && terraform apply -var-file=platform.tfvars

# 2. Configure GitHub Secrets
# (via GitHub UI)

# 3. Deploy environment
git push origin main
# or: cd environments/dev && terraform apply

# 4. Access ArgoCD
terraform output argocd_url

# 5. When done for the day
terraform destroy -var-file=dev.tfvars

# 6. Next day
terraform apply -var-file=dev.tfvars
```

## 📚 Documentation

- **[README.md](./README.md)** - Overview
- **[SETUP_TWO_LAYER.md](./SETUP_TWO_LAYER.md)** - Detailed guide
- **[Artifact](see above)** - Complete walkthrough

---

**Status**: ✅ Production Ready  
**ArgoCD**: ✅ Auto-deployed with LoadBalancer  
**Costs**: ✅ Optimized with destroyable environments
