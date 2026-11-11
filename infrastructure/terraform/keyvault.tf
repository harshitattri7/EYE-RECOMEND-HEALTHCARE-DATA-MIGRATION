data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.project_name}-${var.environment}-01"
  location                    = azurerm_resource_group.rg_migration.location
  resource_group_name         = azurerm_resource_group.rg_migration.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = true
  sku_name                    = "premium" # HSM-backed key protection for HIPAA

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = azurerm_resource_group.rg_migration.tags
}

# Example Secret References for credentials managed securely
resource "azurerm_key_vault_secret" "pg_conn_str" {
  name         = "target-postgres-connection-string"
  value        = "postgresql://${var.pg_admin_username}:${var.pg_admin_password}@psql-${var.project_name}-${var.environment}.postgres.database.azure.com:5432/eyerecommend_central_db?sslmode=require"
  key_vault_id = azurerm_key_vault.kv.id
}
