# Setup Guide - Zebo Terraform

## 🎯 First-Time Setup

### Step 1: Configure GitHub Repository

#### Add Secrets

Go to: `Settings` → `Secrets and variables` → `Actions` → `Secrets` tab

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `GCP_CREDENTIALS` | Service account JSON key | `{full json content}` |
| `GCP_PROJECT_ID` | GCP project ID | `zebraan-gcp-zebo-dev` |
| `ZEO_DB_PASSWORD` | Database password | `your-secure-password` |
| `ZEO_OPENAI_KEY` | OpenAI API key | `sk-...` |
| `ZEO_MF_UTIL_KEY` | MF utility key | `your-key` |

#### Add Variables

Go to: `Settings` → `Secrets and variables` → `Actions` → `Variables` tab

| Variable Name | Description | Default |
|---------------|-------------|---------|
| `GCP_REGION` | GCP region | `asia-south1` |
| `ARTIFACT_REGISTRY_ID` | Registry ID | `zebo-registry` |
| `NODE_MACHINE_TYPE` | VM instance type | `e2-medium` |
| `MIN_NODES` | Minimum nodes | `1` |
| `MAX_NODES` | Maximum nodes | `5` |
| `USE_SPOT_INSTANCES` | Enable spot VMs | `true` |
| `GKE_DELETION_PROTECTION` | Protect cluster | `true` |
| `TERRAFORM_SERVICE_ACCOUNT_EMAIL` | Terraform SA | (see below) |

### Step 2: Find Terraform Service Account

```bash
# List all service accounts
gcloud iam service-accounts list --project=zebraan-gcp-zebo-dev

# Look for something like:
# terraform@zebraan-gcp-zebo-dev.iam.gserviceaccount.com
# terraform-ci@zebraan-gcp-zebo-dev.iam.gserviceaccount.com
# github-actions@zebraan-gcp-zebo-dev.iam.gserviceaccount.com
```

Add this email to the `TERRAFORM_SERVICE_ACCOUNT_EMAIL` variable in GitHub.

### Step 3: Create GCS Backend Bucket (One-Time)

```bash
# Create bucket for Terraform state
gsutil mb -p zebraan-gcp-zebo-dev -l asia-south1 gs://zebo-dev-terraform-state

# Enable versioning
gsutil versioning set on gs://zebo-dev-terraform-state
```

### Step 4: Initialize and Deploy

Option A: Via GitHub Actions (Recommended)
```bash
# Push to main branch
git push origin main

# Or manually trigger workflow
# Go to Actions → Terraform Deployment → Run workflow
```

Option B: Locally
```bash
cd environments/dev

# Copy example tfvars
cp dev.tfvars.example dev.tfvars

# Edit with your values
vim dev.tfvars

# Initialize
terraform init

# Plan
terraform plan -var-file=dev.tfvars

# Apply
terraform apply -var-file=dev.tfvars
```

## 🔧 Common Tasks

### Update Configuration

1. Edit files in `environments/dev/` or `modules/`
2. Commit and push to `main`
3. GitHub Actions automatically applies changes

### Scale Cluster

Update GitHub Variables:
- `MIN_NODES` - Set minimum nodes
- `MAX_NODES` - Set maximum nodes

Then push a change or manually trigger the workflow.

### Add New Secret

1. Add to `environments/dev/dev.tfvars`:
   ```hcl
   secrets = {
     ZEO_DB_PASSWORD = "placeholder"
     ZEO_OPENAI_KEY  = "placeholder"
     ZEO_MF_UTIL_KEY = "placeholder"
     NEW_SECRET      = "placeholder"  # Add this
   }
   ```

2. Add to `.github/workflows/terraform-dev.yaml`:
   ```yaml
   secrets = {
     # ... existing secrets ...
     NEW_SECRET = "${NEW_SECRET}"
   }
   
   env:
     # ... existing env vars ...
     NEW_SECRET: ${{ secrets.NEW_SECRET }}
   ```

3. Add secret to GitHub Secrets

4. Commit and push

### Destroy Infrastructure

1. Go to Actions → Terraform Destroy Dev
2. Click "Run workflow"
3. Type `destroy` in the confirmation field
4. Click "Run workflow"
5. Wait for completion (~10-15 minutes)

## 🚨 Troubleshooting

### Error: Service Account Permission Denied

**Problem**: Terraform can't create GKE node pool

**Solution**: 
```bash
gcloud iam service-accounts add-iam-policy-binding \
  gke-node-sa@zebraan-gcp-zebo-dev.iam.gserviceaccount.com \
  --member="serviceAccount:YOUR_TERRAFORM_SA@zebraan-gcp-zebo-dev.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountUser" \
  --project=zebraan-gcp-zebo-dev
```

Or set `TERRAFORM_SERVICE_ACCOUNT_EMAIL` in GitHub Variables (permanent fix).

### Error: Backend Initialization Failed

**Problem**: Can't access GCS bucket

**Solution**:
```bash
# Check if bucket exists
gsutil ls -p zebraan-gcp-zebo-dev | grep terraform-state

# If not, create it
gsutil mb -p zebraan-gcp-zebo-dev -l asia-south1 gs://zebo-dev-terraform-state
```

### Error: Resource Already Exists

**Problem**: Terraform thinks resource doesn't exist but it does

**Solution**:
```bash
# Import existing resource
terraform import -var-file=dev.tfvars <resource_type>.<resource_name> <resource_id>

# Example: Import existing GKE cluster
terraform import -var-file=dev.tfvars module.gke_cluster.google_container_cluster.primary projects/PROJECT_ID/locations/REGION/clusters/CLUSTER_NAME
```

### Workflow Fails on `terraform fmt -check`

**Problem**: Code not formatted

**Solution**:
```bash
# Format all files
terraform fmt -recursive

# Commit changes
git add .
git commit -m "chore: format Terraform files"
git push
```

## 📋 Checklist

Before first deployment:

- [ ] GCP project created (`zebraan-gcp-zebo-dev`)
- [ ] GitHub Secrets configured (5 secrets)
- [ ] GitHub Variables configured (8 variables)
- [ ] GCS bucket for state created
- [ ] Terraform service account exists
- [ ] Service account has required permissions
- [ ] `TERRAFORM_SERVICE_ACCOUNT_EMAIL` set in GitHub Variables

## 🎉 Success!

After successful deployment, you should see:
- GKE cluster created
- Artifact Registry ready
- Secrets stored in Secret Manager
- Service accounts configured
- Outputs showing cluster details

Next steps:
1. Configure kubectl: Run the command from Terraform outputs
2. Deploy applications using `zebo-infra` repository
3. Monitor costs in GCP Console

## 📚 Additional Resources

- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
