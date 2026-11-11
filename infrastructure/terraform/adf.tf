resource "azurerm_data_factory" "adf" {
  name                = "adf-${var.project_name}-${var.environment}-01"
  location            = azurerm_resource_group.rg_migration.location
  resource_group_name = azurerm_resource_group.rg_migration.name

  identity {
    type = "SystemAssigned"
  }

  tags = azurerm_resource_group.rg_migration.tags
}

# Grant ADF Managed Identity read permissions on Key Vault
resource "azurerm_key_vault_access_policy" "adf_vault_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.adf.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
