variable "resource_group_location" {
  type = string
  #   default = "westeurope"
  default = "eastus"

}

variable "resource_group_name" {
  type        = string
  description = "Pre-existing resource group that will be used for provisioning the infastructure"
}

variable "create_resource_group" {
  type    = bool
  default = true
}

variable "container_registry_server" {
  type        = string
  description = "Container registry server"
  default     = "registry.gitlab.com"
}

variable "container_registry_username" {
  type        = string
  description = "Container registry username"
  default = ""
}

variable "container_registry_password" {
  type        = string
  description = "Container registry password"
  sensitive   = true
  default = ""
}

variable "container_image_name" {
  type        = string
  description = "Container image name with tag eg /spring-angular-on-azure-with-terraform/spring-angular-jhipster:master-771c124bcb54feef6c4c8e105d4401582fcb92f4"
}

variable "db_name" {
  type        = string
  description = "name of API related database"
  default = "springangularjhipster"
}

variable "postgresql_admin_username" {
  type        = string
  description = "Login to authenticate to PostgreSQL Server"
  default     = "admin_user"
}

variable "postgresql_admin_password" {
  type        = string
  description = "Password to authenticate to PostgreSQL Server"
  default     = ""
  sensitive   = true
}

variable "postgresql_storage" {
  type        = string
  description = "PostgreSQL Storage in MB, from 5120 to 16777216"
}

variable "postgresql_storage_tier" {
  type        = string
  description = "PostgreSQL Storage tier"
  default     = "P4" # P4 is the smallest tier
}
