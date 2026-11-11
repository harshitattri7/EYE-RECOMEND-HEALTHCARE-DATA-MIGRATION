output "resource_group_name" {
  value = azurerm_resource_group.rg_migration.name
}

output "storage_account_name" {
  value = azurerm_storage_account.adls_gen2.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.kv.vault_uri
}

output "databricks_workspace_url" {
  value = azurerm_databricks_workspace.databricks.workspace_url
}

output "adf_name" {
  value = azurerm_data_factory.adf.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.postgres_target.fqdn
}
