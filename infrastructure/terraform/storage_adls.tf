resource "azurerm_storage_account" "adls_gen2" {
  name                     = "st${var.project_name}${var.environment}dls01"
  resource_group_name      = azurerm_resource_group.rg_migration.name
  location                 = azurerm_resource_group.rg_migration.location
  account_tier             = "Standard"
  account_replication_type = "GRS" # Geo-redundant for healthcare compliance
  account_kind             = "StorageV2"
  is_hns_enabled           = true  # ADLS Gen2 Hierarchical Namespace

  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  enable_https_traffic_only       = true

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
  }

  tags = azurerm_resource_group.rg_migration.tags
}

# Medallion Architecture Containers
resource "azurerm_storage_data_lake_gen2_filesystem" "containers" {
  for_each = toset([
    "landing",    # Raw drop from ADF copy activity
    "bronze",     # Raw ingested Delta Lake tables with audit headers
    "silver",     # Cleansed, deduplicated, conformant Delta Lake tables
    "gold",       # Harmonized, modeled clinical & financial datasets
    "quarantine", # Schema/DQ invalid rejections
    "archive"     # Cold storage historical logs
  ])

  name               = each.key
  storage_account_id = azurerm_storage_account.adls_gen2.id
}
