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

variable "registry_id" {
  description = "Artifact Registry repository ID"
  type        = string
  default     = "zebo-registry"
}
