terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.109.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "azure/azapi"
      version = "=1.13.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.53.1"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  subscription_id = var.subscription_id
}

resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}


data "azurerm_client_config" "current" {}

data "azurerm_log_analytics_workspace" "default" {
  name                = "DefaultWorkspace-${data.azurerm_client_config.current.subscription_id}-EUS"
  resource_group_name = "DefaultResourceGroup-EUS"
} 

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming}"
  location = var.location
  tags = local.tags
}

resource "azurerm_resource_group" "rg2" {
  name     = "rg-${local.gh_repo}-${random_string.unique.result}-${local.loc_for_naming2}"
  location = var.location2
  tags = local.tags
}

resource "azurerm_eventhub_namespace" "primary" {
  name                = "ehnfailovertestprimary${random_string.unique.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  capacity            = 1

  tags = local.tags
}

resource "azurerm_eventhub_namespace" "secondary" {
  name                = "ehnfailovertestsecondary${random_string.unique.result}"
  location            = azurerm_resource_group.rg2.location
  resource_group_name = azurerm_resource_group.rg2.name
  sku                 = "Standard"
  capacity            = 1

  tags = local.tags
}

resource "azapi_resource" "eventhub-dr-config" {
  type = "Microsoft.EventHub/namespaces/disasterRecoveryConfigs@2024-01-01"
  name = "ehnfailovertest${random_string.unique.result}"
  parent_id = azurerm_eventhub_namespace.primary.id
  body = jsonencode({
    properties = {
      partnerNamespace = azurerm_eventhub_namespace.secondary.id
    }
  })
}

resource "azurerm_eventhub" "primary" {
  depends_on = [ azapi_resource.eventhub-dr-config ]
  name                = "eventhubfailovertest"
  namespace_name      = azurerm_eventhub_namespace.primary.name
  resource_group_name = azurerm_resource_group.rg.name
  partition_count     = 1
  message_retention   = 1
}

resource "azurerm_eventhub_consumer_group" "alias" {
  name                = "alias"
  eventhub_name       = azurerm_eventhub.primary.name
  namespace_name      = azurerm_eventhub_namespace.primary.name
  resource_group_name = azurerm_resource_group.rg.name
  
}

resource "azurerm_eventhub_consumer_group" "primary" {
  name                = "primary"
  eventhub_name       = azurerm_eventhub.primary.name
  namespace_name      = azurerm_eventhub_namespace.primary.name
  resource_group_name = azurerm_resource_group.rg.name
  
}

resource "azurerm_eventhub_consumer_group" "secondary" {
  name                = "secondary"
  eventhub_name       = azurerm_eventhub.primary.name
  namespace_name      = azurerm_eventhub_namespace.primary.name
  resource_group_name = azurerm_resource_group.rg.name
  
}

resource "azurerm_eventhub_consumer_group" "replicator" {
  name                = "replicator"
  eventhub_name       = azurerm_eventhub.primary.name
  namespace_name      = azurerm_eventhub_namespace.primary.name
  resource_group_name = azurerm_resource_group.rg.name
  
}

resource "azurerm_storage_account" "primary" {
  name                     = "saehfo${random_string.unique.result}${local.loc_for_naming}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

resource "azurerm_storage_container" "primary-alias" {
  name                  = "eventhubcheckpoint-alias"
  storage_account_name  = azurerm_storage_account.primary.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "primary-primary" {
  name                  = "eventhubcheckpoint-primary"
  storage_account_name  = azurerm_storage_account.primary.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "primary-secondary" {
  name                  = "eventhubcheckpoint-secondary"
  storage_account_name  = azurerm_storage_account.primary.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "primary-replicator" {
  name                  = "eventhubcheckpoint-replicator"
  storage_account_name  = azurerm_storage_account.primary.name
  container_access_type = "private"
}

resource "azurerm_storage_account" "secondary" {
  name                     = "saehfo${random_string.unique.result}${local.loc_for_naming2}"
  resource_group_name      = azurerm_resource_group.rg2.name
  location                 = azurerm_resource_group.rg2.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

resource "azurerm_storage_container" "secondary" {
  name                  = "eventhubcheckpoint"
  storage_account_name  = azurerm_storage_account.secondary.name
  container_access_type = "private"
}
resource "azurerm_container_app_environment" "primary" {
  name                       = "ace-${random_string.unique.result}-${local.loc_for_naming}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = local.tags

}

resource "azurerm_container_app_environment" "secondary" {
  name                       = "ace-${random_string.unique.result}-${local.loc_for_naming2}"
  location                   = azurerm_resource_group.rg2.location
  resource_group_name        = azurerm_resource_group.rg2.name
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.default.id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = local.tags

}

