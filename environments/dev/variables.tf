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

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "default"
}

variable "subnetwork_name" {
  description = "Subnetwork name"
  type        = string
  default     = "default"
}

variable "ip_range_pods" {
  description = "Secondary IP range for pods"
  type        = string
  default     = "pods"
}

variable "ip_range_services" {
  description = "Secondary IP range for services"
  type        = string
  default     = "services"
}

variable "node_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "min_nodes" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
}

variable "use_spot_instances" {
  description = "Use spot instances for cost savings"
  type        = bool
  default     = true
}

variable "gke_deletion_protection" {
  description = "Protect GKE cluster from deletion"
  type        = bool
  default     = true
}

variable "argocd_hostname" {
  description = "Hostname for ArgoCD (can be IP or domain)"
  type        = string
  default     = "argocd.local"
}

variable "secrets" {
  description = "Map of secrets to create in Secret Manager"
  type        = map(string)
  default     = {}
}
