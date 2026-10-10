# Generate a unique string to ensure the storage account name is globally unique
resource "random_id" "storage_id" {
  byte_length = 4
}

# Create the Azure Storage Account for CNPG Backups
resource "azurerm_storage_account" "cnpg_backup" {
  name                     = "cnpgbackup${lower(random_id.storage_id.hex)}"
  resource_group_name      = "rg-production-data-platform"
  location                 = "westeurope"
  account_tier             = "Standard"
  account_replication_type = "LRS" # Local Redundant is fine for backups, or change to GRS for cross-region
  min_tls_version          = "TLS1_2"

  tags = {
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}

# Create the specific Blob Container where backups will land
resource "azurerm_storage_container" "cnpg_container" {
  name                  = "postgresql-backups"
  storage_account_name  = azurerm_storage_account.cnpg_backup.name  # <-- Fixed this line
  container_access_type = "private"
}

# Output the keys so we can grab them cleanly
output "cnpg_storage_account_name" {
  value = azurerm_storage_account.cnpg_backup.name
}

output "cnpg_storage_primary_key" {
  value     = azurerm_storage_account.cnpg_backup.primary_access_key
  sensitive = true
}
