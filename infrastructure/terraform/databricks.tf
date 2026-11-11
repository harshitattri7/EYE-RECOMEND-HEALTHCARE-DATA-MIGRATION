resource "azurerm_databricks_workspace" "databricks" {
  name                = "dbw-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.rg_migration.name
  location            = azurerm_resource_group.rg_migration.location
  sku                 = "premium" # Required for Unity Catalog & HIPAA compliant cluster policies

  managed_resource_group_name = "rg-${var.project_name}-${var.environment}-dbw-managed"

  custom_parameters {
    no_public_ip                                         = true
    virtual_network_id                                  = null
    public_subnet_name                                  = null
    private_subnet_name                                 = null
    storage_account_sku_name                            = "Standard_LRS"
  }

  tags = azurerm_resource_group.rg_migration.tags
}
