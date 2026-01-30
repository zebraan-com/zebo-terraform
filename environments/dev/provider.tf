provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Remote state backend
terraform {
  backend "gcs" {
    bucket = "zebo-dev-terraform-state"
    prefix = "terraform/state"
  }

  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
