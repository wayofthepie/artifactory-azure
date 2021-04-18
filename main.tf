provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-artifactory-k8s"
  location = "West Europe"
}

resource "azurerm_postgresql_server" "psql-artifactory" {
  name                = "psql-artifactory-k8s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  administrator_login          = "${var.username}"
  administrator_login_password = "${var.password}"

  sku_name   = "GP_Gen5_4"
  version    = "9.6"
  storage_mb = 640000

  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  auto_grow_enabled            = true

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "artifactory-k8s"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "artifactory"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "prod"
  }
}

#resource "local_file" "cluster_config" {
#    content  = azurerm_kubernetes_cluster.k8s.kube_config_raw
#    filename = "cluster_config"
#}
#
# Helm stuff
provider "helm" {
  kubernetes {
    #config_path = local_file.cluster_config.filename
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress-controller"

  repository = "https://charts.jfrog.io"
  chart      = "artifactory"

  set {
    name  = "service.type"
    value = "ClusterIP"
  }
  set {
    name = "postgres.enabled"
    value = "false"
  }
  set {
    name = "database.type"
    value = "postgresql"
  }
  set {
    name = "database.driver"
    value = "org.postgresql.Driver"
  }
  set {
    name = "database.url"
    value = "jdbc:postgresql://psql-artifactory-k8s.postgres.database.azure.com:5432/postgres"
  }
  set {
    name = "database.user"
    value = "${var.username}"
  }
  set {
    name = "database.password"
    value = "${var.password}"
  }
}
