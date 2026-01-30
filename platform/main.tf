# Persistent Platform Infrastructure
# This creates resources that should RARELY be destroyed:
# - Artifact Registry
# - Terraform State Bucket  
# - Service Accounts (terraform-ci, gke-node-sa)
# - IAM bindings
# - Networking (VPC, Subnets)
# - DNS (future)

terraform {
  # Use local backend for platform (bootstrapping)
  # This is the foundation that creates the GCS bucket for other environments
  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.9.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
module "project_apis" {
  source     = "../modules/project"
  project_id = var.project_id
}

# Create GCS bucket for Terraform state (idempotent)
resource "google_storage_bucket" "terraform_state" {
  name          = "${var.project_id}-terraform-state"
  location      = var.region
  project       = var.project_id
  force_destroy = false

  versioning {
    enabled = true
  }

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [module.project_apis]
}

# Artifact Registry for Docker images
module "artifact_registry" {
  source      = "../modules/artifact_registry"
  project_id  = var.project_id
  region      = var.region
  registry_id = var.registry_id
}

# Terraform CI Service Account
resource "google_service_account" "terraform_ci" {
  account_id   = "terraform-ci"
  display_name = "Terraform CI Service Account"
  project      = var.project_id
}

# Grant Terraform CI SA required permissions
resource "google_project_iam_member" "terraform_ci_roles" {
  for_each = toset([
    "roles/container.admin",
    "roles/artifactregistry.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/compute.networkAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/resourcemanager.projectIamAdmin",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# Grant Terraform CI SA access to the state bucket
resource "google_storage_bucket_iam_member" "terraform_ci_bucket_access" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# GKE Node Service Account (created here, used by ephemeral environments)
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "GKE Node Service Account"
  project      = var.project_id
}

# Grant GKE node SA required roles
resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
  ])

  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

# CRITICAL: Allow Terraform CI SA to impersonate GKE node SA
resource "google_service_account_iam_member" "terraform_ci_can_use_gke_node_sa" {
  service_account_id = google_service_account.gke_node_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.terraform_ci.email}"
}

# Shared VPC Network (optional, use default for now)
# Uncomment if you want a custom network
# resource "google_compute_network" "shared_vpc" {
#   name                    = "zebo-shared-vpc"
#   project                 = var.project_id
#   auto_create_subnetworks = false
# }

# Shared Subnet for GKE
# resource "google_compute_subnetwork" "gke_subnet" {
#   name          = "zebo-gke-subnet"
#   ip_cidr_range = "10.0.0.0/24"
#   region        = var.region
#   project       = var.project_id
#   network       = google_compute_network.shared_vpc.id
#
#   secondary_ip_range {
#     range_name    = "pods"
#     ip_cidr_range = "10.1.0.0/16"
#   }
#
#   secondary_ip_range {
#     range_name    = "services"
#     ip_cidr_range = "10.2.0.0/20"
#   }
# }

# Outputs
output "terraform_state_bucket" {
  value       = google_storage_bucket.terraform_state.name
  description = "GCS bucket for Terraform state"
}

output "artifact_registry_url" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${var.registry_id}"
  description = "Artifact Registry URL for Docker images"
}

output "terraform_ci_email" {
  value       = google_service_account.terraform_ci.email
  description = "Terraform CI service account email"
}

output "gke_node_sa_email" {
  value       = google_service_account.gke_node_sa.email
  description = "GKE node service account email"
}
