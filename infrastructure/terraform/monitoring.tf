resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.rg_migration.location
  resource_group_name = azurerm_resource_group.rg_migration.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = azurerm_resource_group.rg_migration.tags
}

resource "azurerm_application_insights" "app_insights" {
  name                = "appi-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.rg_migration.location
  resource_group_name = azurerm_resource_group.rg_migration.name
  workspace_id        = azurerm_log_analytics_workspace.law.id
  application_type    = "other"

  tags = azurerm_resource_group.rg_migration.tags
}

# Azure Monitor Action Group for Migration Alerts
resource "azurerm_monitor_action_group" "migration_alerts" {
  name                = "ag-${var.project_name}-migration-alerts"
  resource_group_name = azurerm_resource_group.rg_migration.name
  short_name          = "MigrationAlert"

  email_receiver {
    name                    = "DataEngineeringLead"
    email_address           = "data-eng-team@eyerecommend.internal"
    use_common_alert_schema = true
  }
}
