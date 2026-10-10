terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group to hold our data platform infrastructure
resource "azurerm_resource_group" "rg" {
  name     = "rg-production-data-platform"
  location = "westeurope" # Optimized for UK tech portfolios
}

# Virtual Network setup
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-data-platform"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "sub-aks-nodes"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Azure Kubernetes Service Cluster (Free Tier)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-pg-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "pg-portfolio"
  
  # 🟢 ADD THIS LINE TO FIX THE ERROR: "code": "OIDCIssuerFeatureCannotBeDisabled",
  oidc_issuer_enabled = true 

  # CRITICAL: Select 'Free' to eliminate the hourly cluster base cost
  sku_tier = "Free" 

  default_node_pool {
    name       = "datanodes"
    node_count = 3 # 3 nodes to ensure physical zone redundancy for the DB
    # vm_size    = "Standard_B2s" # Burstable VM (2 vCPU, 4GB RAM) - ultra low cost
    vm_size        = "Standard_D2as_v5" # 🟢 Swap to this: Highly available & highly compatible vm_size       
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }
  
  # 🟢 ADD THIS BLOCK TO FIX THE OVERLAP
  network_profile {
    network_plugin     = "azure"            # Or "kubenet" depending on your needs
    service_cidr       = "10.240.0.0/16"     # Core services IP range (Must not overlap with 10.0.0.0/16)
    dns_service_ip     = "10.240.0.10"       # Must be inside the service_cidr range
  }

  identity {
    type = "SystemAssigned"
  }
}