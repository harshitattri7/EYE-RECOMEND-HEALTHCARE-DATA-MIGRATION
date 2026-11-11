variable "project_name" {
  type        = string
  description = "Project name identifier"
  default     = "eyerecommend"
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
  default     = "prod"
}

variable "azure_region" {
  type        = string
  description = "Azure primary region"
  default     = "eastus2"
}

variable "pg_admin_username" {
  type        = string
  description = "Administrator username for Azure PostgreSQL Flexible Server"
  default     = "azure_pg_admin"
}

variable "pg_admin_password" {
  type        = string
  description = "Administrator password for Azure PostgreSQL Flexible Server"
  sensitive   = true
}

variable "databricks_node_type" {
  type        = string
  description = "Databricks cluster worker VM size"
  default     = "Standard_D8s_v5"
}

variable "databricks_spark_version" {
  type        = string
  description = "Databricks Spark Runtime version"
  default     = "13.3.x-scala2.12"
}
