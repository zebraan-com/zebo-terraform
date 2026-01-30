variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "zebraan-gcp-zebo-dev"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-south1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-south1-a"
}

variable "registry_id" {
  description = "Artifact Registry repository id"
  type        = string
  default     = "zebo-registry"
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "min_nodes" {
  description = "Minimum number of nodes in the node pool"
  type        = number
  default     = 0
}

variable "max_nodes" {
  description = "Maximum number of nodes in the node pool"
  type        = number
  default     = 1
}

variable "gke_deletion_protection" {
  description = "Protect GKE cluster from deletion"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "secrets" {
  description = "Map of secrets to create in Secret Manager"
  type        = map(string)
  default     = {}
}

variable "terraform_service_account_email" {
  description = "Email of the service account used by Terraform (e.g., from GitHub Actions)"
  type        = string
  default     = ""
}

variable "use_spot_instances" {
  description = "Whether to use spot instances for GKE node pool (enabled for dev to reduce costs)"
  type        = bool
  default     = true
}
