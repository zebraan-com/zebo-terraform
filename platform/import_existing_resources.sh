#!/bin/bash
# Import Existing Platform Resources into Terraform State
# Run this from the platform/ directory

set -e

PROJECT_ID="zebraan-gcp-zebo-dev"
REGION="asia-south1"

echo "🔄 Importing existing platform resources into Terraform state..."
echo ""

# Import Terraform CI Service Account
echo "1️⃣  Importing terraform-ci service account..."
terraform import \
  google_service_account.terraform_ci \
  "projects/${PROJECT_ID}/serviceAccounts/terraform-ci@${PROJECT_ID}.iam.gserviceaccount.com" \
  || echo "⚠️  terraform-ci already in state or doesn't exist"

# Import GKE Node Service Account
echo "2️⃣  Importing gke-node-sa service account..."
terraform import \
  google_service_account.gke_node_sa \
  "projects/${PROJECT_ID}/serviceAccounts/gke-node-sa@${PROJECT_ID}.iam.gserviceaccount.com" \
  || echo "⚠️  gke-node-sa already in state or doesn't exist"

# Import Artifact Registry
echo "3️⃣  Importing artifact registry..."
terraform import \
  module.artifact_registry.google_artifact_registry_repository.docker_repo \
  "projects/${PROJECT_ID}/locations/${REGION}/repositories/zebo-registry" \
  || echo "⚠️  Artifact registry already in state or doesn't exist"

# Import Terraform State Bucket (if it exists)
echo "4️⃣  Importing terraform state bucket..."
terraform import \
  google_storage_bucket.terraform_state \
  "${PROJECT_ID}-terraform-state" \
  || echo "⚠️  State bucket already in state or doesn't exist"

echo ""
echo "✅ Import complete! Now run:"
echo "   terraform plan -var-file=platform.tfvars"
echo ""
echo "If you see 'No changes' - you're all set! 🎉"
echo "If you see changes - review them carefully before applying"
