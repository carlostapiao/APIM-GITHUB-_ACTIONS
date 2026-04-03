terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    helm    = { source = "hashicorp/helm", version = "~> 2.0" }
  }
  backend "azurerm" {
    resource_group_name  = "rg-apppersonal-tfstate"
    storage_account_name = "stcarlosv3state"
    container_name       = "tfstate-apppersonal"
    key                  = "tfstate.v4"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# --- 1. Grupo de Recursos ---
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# --- 2. Azure Container Registry ---
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

# --- 3. Azure Kubernetes Service ---
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-tickets"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DC2s_v3" # SKU solicitado
  }

  identity { type = "SystemAssigned" }
}

# --- 4. Unión AKS + ACR (Role Assignment) ---
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# --- 5. SQL Server & Database ---
resource "azurerm_mssql_server" "sql" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.db_password
}

resource "azurerm_mssql_database" "db" {
  name      = "SupportDB"
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "S0" # Nivel básico para lab
}

# Permitir conexiones de Azure (necesario para que AKS llegue a SQL)
resource "azurerm_mssql_firewall_rule" "sql_fw" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# --- 6. API Management (APIM) ---
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_name      = "Carlos Tapia"
  publisher_email     = "carlos@example.com"
  sku_name            = "Consumption_0"

  # Agrega esto para no esperar una eternidad si Azure se traba
  timeouts {
    create = "25m"
    delete = "25m"
  }
}

resource "azurerm_api_management_api" "api" {
  name                = "tickets-api"
  resource_group_name = azurerm_resource_group.rg.name
  api_management_name = azurerm_api_management.apim.name
  revision            = "1"
  display_name        = "IT Support API"
  path                = "tickets"
  protocols           = ["http", "https"]
}

resource "azurerm_api_management_api_operation" "get_tickets" {
  operation_id        = "get-tickets"
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Get All Tickets"
  method              = "GET"
  url_template        = "/"
}

resource "azurerm_api_management_api_operation" "post_ticket" {
  operation_id        = "create-ticket"
  api_name            = azurerm_api_management_api.api.name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  display_name        = "Create Ticket"
  method              = "POST"
  url_template        = "/"
}

# --- 7. Helm Ingress Nginx ---
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

resource "helm_release" "nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-basic"
  create_namespace = true
}