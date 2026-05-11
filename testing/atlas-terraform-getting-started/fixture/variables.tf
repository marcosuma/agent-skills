variable "atlas_client_id" {
  description = "MongoDB Atlas Service Account client ID."
  type        = string
  sensitive   = true
}

variable "atlas_client_secret" {
  description = "MongoDB Atlas Service Account client secret."
  type        = string
  sensitive   = true
}

variable "org_id" {
  description = "MongoDB Atlas Organization ID."
  type        = string
}

variable "region" {
  description = "Atlas cloud region name, e.g. US_EAST_1."
  type        = string
}
