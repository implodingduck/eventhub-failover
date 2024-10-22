terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "=3.1.0"
    }
    azapi = {
      source = "azure/azapi"
      version = "=1.3.0"
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
  type = "Microsoft.EventHub/namespaces/disasterRecoveryConfigs@2021-11-01"
  name = "ehnfailovertest${random_string.unique.result}"
  parent_id = azurerm_eventhub_namespace.primary.id
  #location = azurerm_resource_group.rg.location

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
  name                            = "saehfo${random_string.unique.result}${local.loc_for_naming}"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  
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


resource "azurerm_container_app" "producer" {
  name                         = "ehfoproducer"
  container_app_environment_id = azurerm_container_app_environment.primary.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "producer"
      image  = "ghcr.io/implodingduck/eventhub-failover-producer:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }

      env {
        name = "EVENT_HUB_FULLY_QUALIFIED_NAMESPACE"
        value = "ehnfailovertest${random_string.unique.result}.servicebus.windows.net"
      }

      env {
        name = "EVENT_HUB_NAME"
        value = "${azurerm_eventhub.primary.name}"
      }

    }
    http_scale_rule {
      name                = "http-1"
      concurrent_requests = "100"
    }
    min_replicas = 0
    max_replicas = 1
  }

  ingress {
    allow_insecure_connections = false
    external_enabled           = true
    target_port                = 80
    transport                  = "auto"
    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
  

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

}

resource "azurerm_container_app" "consumer" {
  name                         = "ehfoconsumeralias"
  container_app_environment_id = azurerm_container_app_environment.primary.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "consumer"
      image  = "ghcr.io/implodingduck/eventhub-failover-consumer:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }
      env {
        name = "EVENT_HUB_FULLY_QUALIFIED_NAMESPACE"
        value = "ehnfailovertest${random_string.unique.result}.servicebus.windows.net"
      }

      env {
        name = "EVENT_HUB_NAME"
        value = "${azurerm_eventhub.primary.name}"
      }
      env {
        name = "EVENT_HUB_CONSUMER_GROUP"
        value = "alias"
      }

      env {
        name = "BLOB_STORAGE_ACCOUNT_URL"
        value = "${azurerm_storage_account.primary.primary_blob_endpoint}"
      }

      env {
        name = "BLOB_CONTAINER_NAME"
        value = "eventhubcheckpoint"
      }

    }
   
    min_replicas = 1
    max_replicas = 1
  }

  
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

}

resource "azurerm_container_app" "primary" {
  name                         = "ehfoconsumerprimary"
  container_app_environment_id = azurerm_container_app_environment.primary.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "consumer"
      image  = "ghcr.io/implodingduck/eventhub-failover-consumer:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }
      env {
        name = "EVENT_HUB_FULLY_QUALIFIED_NAMESPACE"
        value = "${azurerm_eventhub_namespace.primary.name}.servicebus.windows.net"
      }

      env {
        name = "EVENT_HUB_NAME"
        value = "${azurerm_eventhub.primary.name}"
      }
      env {
        name = "EVENT_HUB_CONSUMER_GROUP"
        value = "primary"
      }

      env {
        name = "BLOB_STORAGE_ACCOUNT_URL"
        value = "${azurerm_storage_account.primary.primary_blob_endpoint}"
      }

      env {
        name = "BLOB_CONTAINER_NAME"
        value = "eventhubcheckpoint"
      }

    }
   
    min_replicas = 1
    max_replicas = 1
  }

  
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

}

resource "azurerm_container_app" "secondary" {
  name                         = "ehfoconsumersecondary"
  container_app_environment_id = azurerm_container_app_environment.primary.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "consumer"
      image  = "ghcr.io/implodingduck/eventhub-failover-consumer:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }
      env {
        name = "EVENT_HUB_FULLY_QUALIFIED_NAMESPACE"
        value = "${azurerm_eventhub_namespace.secondary.name}.servicebus.windows.net"
      }

      env {
        name = "EVENT_HUB_NAME"
        value = "${azurerm_eventhub.primary.name}"
      }
      env {
        name = "EVENT_HUB_CONSUMER_GROUP"
        value = "secondary"
      }

      env {
        name = "BLOB_STORAGE_ACCOUNT_URL"
        value = "${azurerm_storage_account.primary.primary_blob_endpoint}"
      }

      env {
        name = "BLOB_CONTAINER_NAME"
        value = "eventhubcheckpoint"
      }

    }
   
    min_replicas = 1
    max_replicas = 1
  }

  
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

}

resource "azurerm_container_app" "replicator" {
  name                         = "ehfoconsumerreplicator"
  container_app_environment_id = azurerm_container_app_environment.primary.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"

  template {
    container {
      name   = "consumer"
      image  = "ghcr.io/implodingduck/eventhub-failover-replicator:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.this.client_id
      }
      env {
        name = "EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_PRIMARY"
        value = "${azurerm_eventhub_namespace.primary.name}.servicebus.windows.net"
      }

      env {
        name = "EVENT_HUB_FULLY_QUALIFIED_NAMESPACE_SECONDARY"
        value = "${azurerm_eventhub_namespace.secondary.name}.servicebus.windows.net"
      }

      env {
        name = "EVENT_HUB_NAME"
        value = "${azurerm_eventhub.primary.name}"
      }
      env {
        name = "EVENT_HUB_CONSUMER_GROUP"
        value = "replicator"
      }

      env {
        name = "BLOB_STORAGE_ACCOUNT_URL"
        value = "${azurerm_storage_account.primary.primary_blob_endpoint}"
      }

      env {
        name = "BLOB_CONTAINER_NAME"
        value = "eventhubcheckpoint"
      }

    }
   
    min_replicas = 1
    max_replicas = 1
  }

  
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.this.id]
  }
  tags = local.tags

}


resource azurerm_user_assigned_identity "this" {
  name                = "uai-ehfailovertest-${random_string.unique.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource azurerm_role_assignment "ehowner" {
  principal_id = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = "Azure Event Hubs Data Owner"
  scope = azurerm_resource_group.rg.id
}
resource azurerm_role_assignment "ehowner2" {
  principal_id = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = "Azure Event Hubs Data Owner"
  scope = azurerm_resource_group.rg2.id
}

resource azurerm_role_assignment "blobowner" {
  principal_id = azurerm_user_assigned_identity.this.principal_id
  role_definition_name = "Storage Blob Data Owner"
  scope = azurerm_resource_group.rg.id
}


