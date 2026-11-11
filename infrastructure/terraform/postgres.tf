resource "azurerm_postgresql_flexible_server" "postgres_target" {
  name                   = "psql-${var.project_name}-${var.environment}"
  resource_group_name    = azurerm_resource_group.rg_migration.name
  location               = azurerm_resource_group.rg_migration.location
  version                = "15"
  administrator_login    = var.pg_admin_username
  administrator_password = var.pg_admin_password

  storage_mb = 1048576 # 1 TB storage with auto-grow
  sku_name   = "GP_Standard_D16ds_v5" # General Purpose 16 vCores, 64 GB RAM for high ingestion throughput

  backup_retention_days        = 35
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  high_availability {
    mode                      = "ZoneRedundant"
    standby_availability_zone = "2"
  }

  tags = azurerm_resource_group.rg_migration.tags
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "target_db" {
  name      = "eyerecommend_central_db"
  server_id = azurerm_postgresql_flexible_server.postgres_target.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Performance & Optimization Configurations for High-Throughput Migration
resource "azurerm_postgresql_flexible_server_configuration" "pg_max_connections" {
  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.postgres_target.id
  value     = "500"
}

resource "azurerm_postgresql_flexible_server_configuration" "pg_work_mem" {
  name      = "work_mem"
  server_id = azurerm_postgresql_flexible_server.postgres_target.id
  value     = "65536" # 64MB per operation
}

resource "azurerm_postgresql_flexible_server_configuration" "pg_maintenance_work_mem" {
  name      = "maintenance_work_mem"
  server_id = azurerm_postgresql_flexible_server.postgres_target.id
  value     = "2097152" # 2GB for rapid index creation during cutover
}
