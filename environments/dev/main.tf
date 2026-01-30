# Ephemeral Development Environment
# This creates resources that can be destroyed frequently:
# - GKE Cluster
# - ArgoCD (via Helm)
# - Secrets
# These resources reference the persistent platform layer

terraform {
  backend "gcs" {
    bucket = "zebraan-gcp-zebo-dev-terraform-state"
    prefix = "environments/dev"
  }

  required_version = ">= 1.9.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Data source: Get GKE node SA from platform layer
data "google_service_account" "gke_node_sa" {
  account_id = "gke-node-sa"
  project    = var.project_id
}

# Secret Manager for application secrets
module "secret_manager" {
  source     = "../../modules/secret_manager"
  project_id = var.project_id
  secrets    = var.secrets
}

# GKE Cluster
module "gke_cluster" {
  source = "../../modules/gke"

  project_id   = var.project_id
  region       = var.region
  cluster_name = "${var.environment}-gke-cluster"

  # Use service account from platform layer
  gke_node_pool_sa_email = data.google_service_account.gke_node_sa.email

  # Network configuration
  network_name    = var.network_name
  subnetwork_name = var.subnetwork_name
  ip_range_pods     = var.ip_range_pods
  ip_range_services = var.ip_range_services

  # Node pool configuration
  node_machine_type  = var.node_machine_type
  min_nodes          = var.min_nodes
  max_nodes          = var.max_nodes
  use_spot_instances = var.use_spot_instances

  deletion_protection = var.gke_deletion_protection
}

# Configure Kubernetes provider to use the GKE cluster
data "google_client_config" "provider" {}

data "google_container_cluster" "primary" {
  name       = module.gke_cluster.cluster_name
  location   = var.region
  depends_on = [module.gke_cluster]
}

provider "kubernetes" {
  host  = "https://${data.google_container_cluster.primary.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${data.google_container_cluster.primary.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      data.google_container_cluster.primary.master_auth[0].cluster_ca_certificate
    )
  }
}

# Create argocd namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [module.gke_cluster]
}

# Install ArgoCD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6" # Pin version for stability
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [templatefile("${path.module}/argocd-values.yaml", {
    hostname = var.argocd_hostname
  })]

  depends_on = [kubernetes_namespace.argocd]
}

# Create LoadBalancer service to expose ArgoCD UI
resource "kubernetes_service" "argocd_server_lb" {
  metadata {
    name      = "argocd-server-lb"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "argocd-server"
    }
  }

  spec {
    type = "LoadBalancer"

    selector = {
      "app.kubernetes.io/name" = "argocd-server"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 8080
      protocol    = "TCP"
    }

    port {
      name        = "https"
      port        = 443
      target_port = 8080
      protocol    = "TCP"
    }
  }

  depends_on = [helm_release.argocd]
}

# Get ArgoCD admin password
data "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

# Outputs
output "gke_cluster_name" {
  value       = module.gke_cluster.cluster_name
  description = "GKE cluster name"
}

output "gcloud_get_credentials" {
  value       = "gcloud container clusters get-credentials ${module.gke_cluster.cluster_name} --region ${var.region} --project ${var.project_id}"
  description = "Command to configure kubectl"
}

output "argocd_url" {
  value       = "http://${kubernetes_service.argocd_server_lb.status.0.load_balancer.0.ingress.0.ip}"
  description = "ArgoCD UI URL (HTTP)"
}

output "argocd_admin_password" {
  value       = try(data.kubernetes_secret.argocd_initial_admin_secret.data["password"], "")
  description = "ArgoCD admin password"
  sensitive   = true
}

output "argocd_access_info" {
  value = <<EOT
ArgoCD Access Information:
--------------------------
URL: http://${try(kubernetes_service.argocd_server_lb.status.0.load_balancer.0.ingress.0.ip, "pending...")}
Username: admin
Password: (run 'terraform output argocd_admin_password' to see)

To get password:
terraform output -raw argocd_admin_password
EOT
  description = "ArgoCD access information"
}
