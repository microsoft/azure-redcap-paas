terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<=2.99.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

data "azurerm_client_config" "current" {}

data "http" "ifconfig" {
  url = "http://ifconfig.me"
}

resource "random_string" "redcap" {
  keepers = {
    "project_id" = terraform.workspace
  }
  length    = 4
  min_lower = 4
  special   = false
}

resource "random_password" "redcap" {
  length           = 16
  special          = true
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
  override_special = "_%@"
}

##############################################
# AZURE RESOURCE GROUP
##############################################
resource "azurerm_resource_group" "redcap" {
  name     = "rg-${local.resource_name}"
  location = var.location
  tags     = var.tags
}

##############################################
# AZURE VIRTUAL NETWORK + SERVICE ENDPOINTS
##############################################
resource "azurerm_network_security_group" "redcap" {
  name                = "nsg-${local.resource_name}"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
}

resource "azurerm_virtual_network" "redcap" {
  name                = "vn-${local.resource_name}"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
  address_space       = var.vnet_address_space
  dns_servers         = var.dns_servers
}

resource "azurerm_subnet" "redcap" {
  for_each                                       = { for sn in var.subnets : sn.name => sn }
  name                                           = each.value["name"]
  resource_group_name                            = azurerm_resource_group.redcap.name
  virtual_network_name                           = azurerm_virtual_network.redcap.name
  address_prefixes                               = [each.value["address_prefix"]]
  enforce_private_link_endpoint_network_policies = each.value["name"] == "PrivateLinkSubnet" ? true : false

  dynamic "delegation" {
    for_each = each.value["name"] == "IntegrationSubnet" ? [1] : []

    content {
      name = "delegation"

      service_delegation {
        name = "Microsoft.Web/serverFarms"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/action"
        ]
      }
    }
  }

  service_endpoints = [
    "Microsoft.KeyVault",
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.Web"
  ]
}

resource "azurerm_subnet_network_security_group_association" "redcap" {
  for_each                  = { for sn in var.subnets : sn.name => sn }
  subnet_id                 = azurerm_subnet.redcap[each.value.name].id
  network_security_group_id = azurerm_network_security_group.redcap.id

  depends_on = [
    azurerm_subnet.redcap["ComputeSubnet"],
    azurerm_subnet.redcap["IntegrationSubnet"],
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

##############################################
# AZURE PRIVATE DNS ZONES AND VNET LINKS
##############################################
resource "azurerm_private_dns_zone" "blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.redcap.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "blob"
  resource_group_name   = azurerm_resource_group.redcap.name
  private_dns_zone_name = azurerm_private_dns_zone.blob.name
  virtual_network_id    = azurerm_virtual_network.redcap.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "file" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = azurerm_resource_group.redcap.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "file" {
  name                  = "file"
  resource_group_name   = azurerm_resource_group.redcap.name
  private_dns_zone_name = azurerm_private_dns_zone.file.name
  virtual_network_id    = azurerm_virtual_network.redcap.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "mysql" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.redcap.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "redcap_pe_mysql"
  resource_group_name   = azurerm_resource_group.redcap.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = azurerm_virtual_network.redcap.id
  tags                  = var.tags
}

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.redcap.name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "keyvault"
  resource_group_name   = azurerm_resource_group.redcap.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.redcap.id
  tags                  = var.tags
}

##############################################
# AZURE STORAGE (BLOB STORAGE)
##############################################
resource "azurerm_storage_account" "redcap" {
  name                     = local.storage_name
  resource_group_name      = azurerm_resource_group.redcap.name
  location                 = azurerm_resource_group.redcap.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  tags                     = var.tags

  network_rules {
    default_action = "Deny"

    ip_rules = [
      data.http.ifconfig.body
    ]

    virtual_network_subnet_ids = [
      azurerm_subnet.redcap["ComputeSubnet"].id,
      azurerm_subnet.redcap["IntegrationSubnet"].id,
      azurerm_subnet.redcap["PrivateLinkSubnet"].id,
      var.devops_subnet_id
    ]

    bypass = [
      "AzureServices",
      "Logging",
      "Metrics"
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["ComputeSubnet"],
    azurerm_subnet.redcap["IntegrationSubnet"],
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

resource "azurerm_private_endpoint" "blob" {
  name                = "${local.storage_name}-pe"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
  subnet_id           = azurerm_subnet.redcap["PrivateLinkSubnet"].id

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.blob.id
    ]
  }

  private_service_connection {
    name                           = "${local.storage_name}-pe"
    private_connection_resource_id = azurerm_storage_account.redcap.id
    is_manual_connection           = false
    subresource_names = [
      "blob"
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

##############################################
# AZURE STORAGE (FILE STORAGE)
##############################################
resource "azurerm_storage_account" "redcap_share" {
  name                     = local.storage_share_name
  resource_group_name      = azurerm_resource_group.redcap.name
  location                 = azurerm_resource_group.redcap.location
  account_kind             = "FileStorage"
  account_tier             = "Premium"
  account_replication_type = var.storage_account_replication_type
  tags                     = var.tags

  network_rules {
    default_action = "Deny"

    ip_rules = [
      data.http.ifconfig.body
    ]

    virtual_network_subnet_ids = [
      azurerm_subnet.redcap["ComputeSubnet"].id,
      azurerm_subnet.redcap["IntegrationSubnet"].id,
      azurerm_subnet.redcap["PrivateLinkSubnet"].id,
      var.devops_subnet_id
    ]

    bypass = [
      "AzureServices",
      "Logging",
      "Metrics"
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["ComputeSubnet"],
    azurerm_subnet.redcap["IntegrationSubnet"],
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

resource "azurerm_private_endpoint" "file" {
  name                = "${local.storage_share_name}-pe"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
  subnet_id           = azurerm_subnet.redcap["PrivateLinkSubnet"].id

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.file.id
    ]
  }

  private_service_connection {
    name                           = "${local.storage_share_name}-pe"
    private_connection_resource_id = azurerm_storage_account.redcap_share.id
    is_manual_connection           = false
    subresource_names = [
      "file"
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

resource "azurerm_storage_share" "redcap" {
  name                 = "redcap"
  storage_account_name = azurerm_storage_account.redcap_share.name
  quota                = 100
}

##############################################
# AZURE KEY VAULT + SECRETS
##############################################
resource "azurerm_key_vault" "redcap" {
  name                            = local.keyvault_name
  resource_group_name             = azurerm_resource_group.redcap.name
  location                        = azurerm_resource_group.redcap.location
  tags                            = var.tags
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days      = 90
  purge_protection_enabled        = true
  sku_name                        = "standard"

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    ip_rules = [
      data.http.ifconfig.body
    ]

    virtual_network_subnet_ids = [
      azurerm_subnet.redcap["ComputeSubnet"].id,
      azurerm_subnet.redcap["IntegrationSubnet"].id,
      azurerm_subnet.redcap["PrivateLinkSubnet"].id,
      var.devops_subnet_id
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["ComputeSubnet"],
    azurerm_subnet.redcap["IntegrationSubnet"],
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

resource "azurerm_key_vault_access_policy" "me" {
  key_vault_id = azurerm_key_vault.redcap.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "backup",
    "create",
    "delete",
    "deleteissuers",
    "get",
    "getissuers",
    "import",
    "list",
    "listissuers",
    "managecontacts",
    "manageissuers",
    "purge",
    "recover",
    "restore",
    "setissuers",
    "update"
  ]
  key_permissions = [
    "backup",
    "create",
    "decrypt",
    "delete",
    "encrypt",
    "get",
    "import",
    "list",
    "purge",
    "recover",
    "restore",
    "sign",
    "unwrapKey",
    "update",
    "verify",
    "wrapKey"
  ]
  secret_permissions = [
    "backup",
    "delete",
    "get",
    "list",
    "purge",
    "recover",
    "restore",
    "set"
  ]
  storage_permissions = [
    "backup",
    "delete",
    "deletesas",
    "get",
    "getsas",
    "list",
    "listsas",
    "purge",
    "recover",
    "regeneratekey",
    "restore",
    "set",
    "setsas",
    "update"
  ]

  depends_on = [
    azurerm_key_vault.redcap
  ]
}

resource "azurerm_key_vault_secret" "mysql" {
  name         = "mysql-password"
  value        = random_password.redcap.result
  key_vault_id = azurerm_key_vault.redcap.id
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.me
  ]
}

resource "azurerm_key_vault_secret" "storage" {
  name         = "storage-key"
  value        = azurerm_storage_account.redcap.primary_access_key
  key_vault_id = azurerm_key_vault.redcap.id
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.me
  ]
}

resource "azurerm_key_vault_secret" "conn" {
  name         = "connection-string"
  value        = "Database=${var.siteName}_db;Data Source=${local.mysql_name}.mysql.database.azure.com;User Id=${var.administratorLogin}@mysql-${local.mysql_name};Password=${random_password.redcap.result}"
  key_vault_id = azurerm_key_vault.redcap.id
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.me
  ]
}

resource "azurerm_key_vault_secret" "rc_zipfile" {
  name         = "redcap-zipfile"
  value        = var.redcapAppZip
  key_vault_id = azurerm_key_vault.redcap.id
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.me
  ]
}

resource "azurerm_key_vault_secret" "rc_user" {
  name         = "redcap-username"
  value        = var.redcapCommunityUsername
  key_vault_id = azurerm_key_vault.redcap.id
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.me
  ]
}

resource "azurerm_key_vault_secret" "rc_pass" {
  name         = "redcap-password"
  value        = var.redcapCommunityPassword
  key_vault_id = azurerm_key_vault.redcap.id
  tags         = var.tags

  depends_on = [
    azurerm_key_vault_access_policy.me
  ]
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "${local.keyvault_name}-pe"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  subnet_id           = azurerm_subnet.redcap["PrivateLinkSubnet"].id

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.keyvault.id
    ]
  }

  private_service_connection {
    name                           = "${local.keyvault_name}-pe"
    private_connection_resource_id = azurerm_key_vault.redcap.id
    is_manual_connection           = false
    subresource_names = [
      "vault"
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

##############################################
# AZURE DATABASE FOR MYSQL
##############################################
resource "azurerm_mysql_flexible_server" "redcap" {
  name                   = local.mysql_name
  resource_group_name    = azurerm_resource_group.redcap.name
  location               = azurerm_resource_group.redcap.location
  tags                   = var.tags
  administrator_login    = var.administratorLogin
  administrator_password = random_password.redcap.result
  sku_name               = local.mysql_sku
  storage {
    size_gb           = var.databaseStorageSizeGB
    auto_grow_enabled = true
    iops              = 360
  }
  version                      = var.mysqlVersion
  backup_retention_days        = 30
  geo_redundant_backup_enabled = true
}

resource "azurerm_mysql_virtual_network_rule" "compute" {
  name                = "${azurerm_subnet.redcap["ComputeSubnet"].name}Rule"
  resource_group_name = azurerm_resource_group.redcap.name
  server_name         = azurerm_mysql_flexible_server.redcap.name
  subnet_id           = azurerm_subnet.redcap["ComputeSubnet"].id

  depends_on = [
    azurerm_subnet.redcap["ComputeSubnet"]
  ]
}

resource "azurerm_mysql_virtual_network_rule" "integration" {
  name                = "${azurerm_subnet.redcap["IntegrationSubnet"].name}Rule"
  resource_group_name = azurerm_resource_group.redcap.name
  server_name         = azurerm_mysql_flexible_server.redcap.name
  subnet_id           = azurerm_subnet.redcap["IntegrationSubnet"].id

  depends_on = [
    azurerm_subnet.redcap["IntegrationSubnet"]
  ]
}

resource "azurerm_mysql_virtual_network_rule" "privatelink" {
  name                = "${azurerm_subnet.redcap["PrivateLinkSubnet"].name}Rule"
  resource_group_name = azurerm_resource_group.redcap.name
  server_name         = azurerm_mysql_flexible_server.redcap.name
  subnet_id           = azurerm_subnet.redcap["PrivateLinkSubnet"].id

  depends_on = [
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

resource "azurerm_mysql_flexible_database" "redcap" {
  name                = "${var.siteName}_db"
  resource_group_name = azurerm_resource_group.redcap.name
  server_name         = azurerm_mysql_flexible_server.redcap.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

resource "azurerm_private_endpoint" "mysql" {
  name                = "${local.mysql_name}-pe"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
  subnet_id           = azurerm_subnet.redcap["PrivateLinkSubnet"].id

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.mysql.id
    ]
  }

  private_service_connection {
    name                           = "${local.mysql_name}-pe"
    private_connection_resource_id = azurerm_mysql_flexible_server.redcap.id
    is_manual_connection           = false
    subresource_names = [
      "mysqlServer"
    ]
  }

  depends_on = [
    azurerm_subnet.redcap["PrivateLinkSubnet"]
  ]
}

##############################################
# AZURE APP SERVICE
##############################################
resource "azurerm_application_insights" "redcap" {
  name                = "${local.app_service_name}AppInsights"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  application_type    = "web"
  tags                = var.tags
}

resource "azurerm_app_service_plan" "redcap" {
  name                = "${local.app_service_name}Plan"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
  kind                = "Linux"
  reserved            = true

  sku {
    tier     = var.app_service_plan_tier
    size     = var.app_service_plan_size
    capacity = var.skuCapacity
  }
}

resource "azurerm_app_service" "redcap" {
  name                = local.app_service_name
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags
  app_service_plan_id = azurerm_app_service_plan.redcap.id
  https_only          = true

  # turn this off for now until terraform module can support "allow". as of 3/22 turning this to true sets it to require. azure supports, "require", "allow", "ignore"
  # https://github.com/terraform-providers/terraform-provider-azurerm/issues/9343
  # As a workaround, you can navigate to the App Service, go to Configuration blade, and set Client Certificate Mode to "Allow"
  # client_cert_enabled = false

  identity {
    type = "SystemAssigned"
  }

  site_config {
    linux_fx_version = var.linuxFxVersion
    app_command_line = "/home/startup.sh"
    always_on        = true

    default_documents = [
      "index.php",
      "Default.htm",
      "Default.html",
      "Default.asp",
      "index.htm",
      "index.html",
      "iisstart.htm",
      "default.aspx",
      "hostingstart.html",
    ]

    ip_restriction {
      name       = "AllowClientIP"
      action     = "Allow"
      priority   = "050"
      ip_address = "${data.http.ifconfig.body}/32"
    }

    ip_restriction {
      name        = "AllowFrontDoor"
      action      = "Allow"
      priority    = "100"
      service_tag = "AzureFrontDoor.Backend"
    }

    ip_restriction {
      name                      = "AllowIntegrationSubnet"
      action                    = "Allow"
      priority                  = "200"
      virtual_network_subnet_id = azurerm_subnet.redcap["IntegrationSubnet"].id
    }

    ip_restriction {
      name                      = "AllowComputeSubnet"
      action                    = "Allow"
      priority                  = "300"
      virtual_network_subnet_id = azurerm_subnet.redcap["ComputeSubnet"].id
    }

    scm_ip_restriction {
      name       = "AllowClientIP"
      action     = "Allow"
      priority   = "050"
      ip_address = "${data.http.ifconfig.body}/32"
    }

    scm_ip_restriction {
      name                      = "AllowVNET"
      action                    = "Allow"
      priority                  = "100"
      virtual_network_subnet_id = azurerm_subnet.redcap["ComputeSubnet"].id
    }
  }

  app_settings = {
    "StorageContainerName"                            = var.storageContainerName,
    "StorageAccount"                                  = azurerm_storage_account.redcap.name,
    "StorageKey"                                      = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.redcap.name};SecretName=${azurerm_key_vault_secret.storage.name})",
    "redcapAppZip"                                    = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.redcap.name};SecretName=${azurerm_key_vault_secret.rc_zipfile.name})",
    "redcapCommunityUsername"                         = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.redcap.name};SecretName=${azurerm_key_vault_secret.rc_user.name})",
    "redcapCommunityPassword"                         = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.redcap.name};SecretName=${azurerm_key_vault_secret.rc_pass.name})",
    "redcapAppZipVersion"                             = var.redcapAppZipVersion,
    "DBHostName"                                      = "${local.mysql_name}.mysql.database.azure.com",
    "DBName"                                          = "${var.siteName}_db",
    "DBUserName"                                      = "${var.administratorLogin}@${local.mysql_name}",
    "DBPassword"                                      = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.redcap.name};SecretName=${azurerm_key_vault_secret.mysql.name})",
    "DBSslCa"                                         = "/home/site/wwwroot/DigiCertGlobalRootCA.crt.pem",
    "PHP_INI_SCAN_DIR"                                = "/usr/local/etc/php/conf.d:/home/site",
    "from_email_address"                              = var.administrator_email,
    "smtp_fqdn_name"                                  = "NOT_USED",
    "smtp_port"                                       = "NOT_USED",
    "smtp_user_name"                                  = "NOT_USED",
    "smtp_password"                                   = "NOT_USED",
    "APPINSIGHTS_INSTRUMENTATIONKEY"                  = azurerm_application_insights.redcap.instrumentation_key
    "APPINSIGHTS_PROFILERFEATURE_VERSION"             = "1.0.0"
    "APPINSIGHTS_SNAPSHOTFEATURE_VERSION"             = "1.0.0"
    "APPLICATIONINSIGHTS_CONNECTION_STRING"           = azurerm_application_insights.redcap.connection_string
    "ApplicationInsightsAgent_EXTENSION_VERSION"      = "~2"
    "DiagnosticServices_EXTENSION_VERSION"            = "~3"
    "InstrumentationEngine_EXTENSION_VERSION"         = "disabled"
    "SnapshotDebugger_EXTENSION_VERSION"              = "disabled"
    "XDT_MicrosoftApplicationInsights_BaseExtensions" = "disabled"
    "XDT_MicrosoftApplicationInsights_Mode"           = "recommended"
    "XDT_MicrosoftApplicationInsights_PreemptSdk"     = "disabled"
    "WEBSITE_DNS_SERVER"                              = "168.63.129.16"
    "WEBSITE_VNET_ROUTE_ALL"                          = "1"
    "SCM_DO_BUILD_DURING_DEPLOYMENT"                  = "1"
  }

  connection_string {
    name  = "defaultConnection"
    type  = "MySql"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.redcap.name};SecretName=${azurerm_key_vault_secret.conn.name})"
  }

  logs {
    detailed_error_messages_enabled = true
    failed_request_tracing_enabled  = true

    application_logs {
      file_system_level = "Off"
    }

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 100 # range is between 25-100
      }
    }
  }

  # This will not work as the deploy.ps1 script in the repo relies on app configuration settings but they are not available in time when running this bit as part of the resource deployment
  # source_control {
  #   repo_url           = var.repoURL
  #   branch             = var.branch
  #   manual_integration = true
  # }

  depends_on = [
    azurerm_key_vault.redcap,
    azurerm_key_vault_secret.mysql,
    azurerm_key_vault_secret.storage,
    azurerm_key_vault_secret.conn,
    azurerm_key_vault_secret.rc_zipfile,
    azurerm_key_vault_secret.rc_user,
    azurerm_key_vault_secret.rc_pass,
    azurerm_application_insights.redcap,
    azurerm_subnet.redcap["ComputeSubnet"],
    azurerm_subnet.redcap["IntegrationSubnet"]
  ]
}

resource "azurerm_app_service_virtual_network_swift_connection" "redcap" {
  app_service_id = azurerm_app_service.redcap.id
  subnet_id      = azurerm_subnet.redcap["IntegrationSubnet"].id

  depends_on = [
    azurerm_subnet.redcap["IntegrationSubnet"]
  ]
}

resource "azurerm_key_vault_access_policy" "redcap_app" {
  key_vault_id = azurerm_key_vault.redcap.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_app_service.redcap.identity.0.principal_id

  certificate_permissions = [
    "get",
    "list",
  ]

  secret_permissions = [
    "get",
    "list",
  ]

  depends_on = [
    azurerm_app_service.redcap
  ]
}

##############################################
# WINDOWS VIRTUAL DESKTOP + SESSION HOSTS
##############################################
resource "azurerm_virtual_desktop_host_pool" "redcap" {
  name                     = "hp-${local.resource_name}"
  resource_group_name      = azurerm_resource_group.redcap.name
  location                 = azurerm_resource_group.redcap.location
  type                     = "Pooled"
  load_balancer_type       = "BreadthFirst"
  friendly_name            = "REDCap ${upper(terraform.workspace)} Host Pool"
  description              = "REDCap WVD host pool for remote app and remote desktop services"
  validate_environment     = false
  maximum_sessions_allowed = 999999
  tags                     = var.tags

  registration_info {
    expiration_date = timeadd(format("%sT00:00:00Z", formatdate("YYYY-MM-DD", timestamp())), "1440m")
  }
}

resource "azurerm_virtual_desktop_application_group" "redcap" {
  name                = "dag-${local.resource_name}"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  host_pool_id        = azurerm_virtual_desktop_host_pool.redcap.id
  type                = "Desktop"
  friendly_name       = "REDCap ${upper(terraform.workspace)} Workstation"
  description         = "Windows 10 Desktops"
}

resource "azurerm_virtual_desktop_workspace" "redcap" {
  name                = "ws-${local.resource_name}"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  friendly_name       = "REDCap ${upper(terraform.workspace)}  Workspace"
  description         = "Session desktops"
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "redcap" {
  workspace_id         = azurerm_virtual_desktop_workspace.redcap.id
  application_group_id = azurerm_virtual_desktop_application_group.redcap.id
}

resource "azurerm_network_interface" "redcap" {
  count               = var.vm_count
  name                = "${local.vm_name}-${count.index + 1}_nic"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.redcap["ComputeSubnet"].id
    private_ip_address_allocation = "dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "redcap" {
  count               = var.vm_count
  name                = "${local.vm_name}-${count.index + 1}"
  resource_group_name = azurerm_resource_group.redcap.name
  location            = azurerm_resource_group.redcap.location
  size                = var.vm_sku
  admin_username      = var.vm_username
  admin_password      = var.vm_password
  tags                = merge(var.tags, { "role" = "WVDSessionHost" })

  network_interface_ids = [
    element(azurerm_network_interface.redcap.*.id, count.index)
  ]

  os_disk {
    name                 = "${local.vm_name}-${count.index + 1}_osdisk"
    caching              = var.vm_os_disk_caching.caching
    storage_account_type = var.vm_os_disk_caching.storage_account_type
  }

  source_image_reference {
    publisher = var.vm_image.publisher
    offer     = var.vm_image.offer
    sku       = var.vm_image.sku
    version   = var.vm_image.version
  }

  identity {
    type = "SystemAssigned"
  }
}

##############################################
# AZURE RECOVERY SERVICES VAULT
##############################################
resource "azurerm_recovery_services_vault" "redcap" {
  name                = "rsv-${local.resource_name}"
  location            = azurerm_resource_group.redcap.location
  resource_group_name = azurerm_resource_group.redcap.name
  sku                 = "Standard"
  soft_delete_enabled = false
  tags                = var.tags
}

resource "azurerm_backup_policy_vm" "redcap" {
  name                = "rsv-${local.vm_name}"
  resource_group_name = azurerm_resource_group.redcap.name
  recovery_vault_name = azurerm_recovery_services_vault.redcap.name
  #tags                = var.tags

  retention_daily {
    count = 30
  }

  backup {
    frequency = "Daily"
    time      = "23:00"
  }
}

resource "azurerm_backup_protected_vm" "redcap" {
  count               = var.vm_count
  resource_group_name = azurerm_resource_group.redcap.name
  recovery_vault_name = azurerm_recovery_services_vault.redcap.name
  source_vm_id        = azurerm_windows_virtual_machine.redcap[count.index].id
  backup_policy_id    = azurerm_backup_policy_vm.redcap.id
  #tags                = var.tags
}

resource "azurerm_backup_container_storage_account" "redcap" {
  resource_group_name = azurerm_resource_group.redcap.name
  recovery_vault_name = azurerm_recovery_services_vault.redcap.name
  storage_account_id  = azurerm_storage_account.redcap_share.id
}

resource "azurerm_backup_policy_file_share" "redcap" {
  name                = local.storage_share_name
  resource_group_name = azurerm_resource_group.redcap.name
  recovery_vault_name = azurerm_recovery_services_vault.redcap.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 10
  }

  retention_weekly {
    count    = 7
    weekdays = ["Sunday", "Wednesday", "Friday", "Saturday"]
  }

  retention_monthly {
    count    = 7
    weekdays = ["Sunday", "Wednesday"]
    weeks    = ["First", "Last"]
  }

  retention_yearly {
    count    = 7
    weekdays = ["Sunday"]
    weeks    = ["Last"]
    months   = ["January"]
  }
}

resource "azurerm_backup_protected_file_share" "redcap" {
  resource_group_name       = azurerm_resource_group.redcap.name
  recovery_vault_name       = azurerm_recovery_services_vault.redcap.name
  source_storage_account_id = azurerm_backup_container_storage_account.redcap.storage_account_id
  source_file_share_name    = azurerm_storage_share.redcap.name
  backup_policy_id          = azurerm_backup_policy_file_share.redcap.id
}

#####################################################################################################
# VM EXTENSIONS - https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/overview
#####################################################################################################
resource "azurerm_virtual_machine_extension" "da" {
  count                      = length(azurerm_windows_virtual_machine.redcap)
  name                       = "DAExtension"
  virtual_machine_id         = azurerm_windows_virtual_machine.redcap[count.index].id
  publisher                  = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                       = "DependencyAgentWindows"
  type_handler_version       = "9.5"
  auto_upgrade_minor_version = true
  tags                       = var.tags

  depends_on = [
    azurerm_windows_virtual_machine.redcap
  ]
}

# https://docs.microsoft.com/en-us/azure/security/fundamentals/antimalware-code-samples#enable-and-configure-microsoft-antimalware-for-azure-resource-manager-vms
# Get-AzVMExtensionImage -Location westus2 -PublisherName "Microsoft.Azure.Security" -Type “IaaSAntimalware"
resource "azurerm_virtual_machine_extension" "ia" {
  count                      = length(azurerm_windows_virtual_machine.redcap)
  name                       = "IaaSAntimalware"
  virtual_machine_id         = azurerm_windows_virtual_machine.redcap[count.index].id
  publisher                  = "Microsoft.Azure.Security"
  type                       = "IaaSAntimalware"
  type_handler_version       = "1.5"
  auto_upgrade_minor_version = true
  tags                       = var.tags

  settings = <<SETTINGS
    {
      "AntimalwareEnabled": true
    }
  SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.redcap,
    azurerm_virtual_machine_extension.da
  ]
}

# Install WinRM for Ansible
# https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows
resource "azurerm_virtual_machine_extension" "ans" {
  count                      = length(azurerm_windows_virtual_machine.redcap)
  name                       = "AnsibleWinRM"
  virtual_machine_id         = azurerm_windows_virtual_machine.redcap[count.index].id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "fileUris": [
          "https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1"
        ]
    }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
    {
      "commandToExecute": "powershell.exe -Command \"./ConfigureRemotingForAnsible.ps1; exit 0;\""
    }
  PROTECTED_SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.redcap,
    azurerm_virtual_machine_extension.da,
    azurerm_virtual_machine_extension.ia
  ]
}

##############################################
# AZURE VNET PEERING AND ROUTE TO AADDS
##############################################
resource "azurerm_virtual_network_peering" "redcap" {
  for_each                     = { for vp in var.vnet_peerings : vp.peering_name => vp }
  name                         = each.value["peering_name"]
  remote_virtual_network_id    = each.value["vnet_resource_id"]
  resource_group_name          = azurerm_resource_group.redcap.name
  virtual_network_name         = azurerm_virtual_network.redcap.name
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_route_table" "redcap" {
  name                          = "rt-${local.resource_name}"
  resource_group_name           = azurerm_resource_group.redcap.name
  location                      = azurerm_resource_group.redcap.location
  tags                          = var.tags
  disable_bgp_route_propagation = true

  dynamic "route" {
    for_each = var.subnet_routes
    content {
      name                   = route.value["name"]
      address_prefix         = route.value["address_prefix"]
      next_hop_type          = route.value["next_hop_type"]
      next_hop_in_ip_address = route.value["next_hop_in_ip_address"]
    }
  }
}

resource "azurerm_subnet_route_table_association" "redcap" {
  subnet_id      = azurerm_subnet.redcap["ComputeSubnet"].id
  route_table_id = azurerm_route_table.redcap.id

  depends_on = [
    azurerm_subnet.redcap["ComputeSubnet"],
    azurerm_virtual_machine_extension.da,
    azurerm_virtual_machine_extension.ia,
    azurerm_virtual_machine_extension.ans
  ]
}

##############################################
# ANSIBLE INVENTORY FILE
##############################################
resource "local_file" "redcap" {
  filename = "ansible/inventory"

  content = templatefile("ansible/template-inventory.tpl",
    {
      hosts = zipmap(azurerm_windows_virtual_machine.redcap.*.name, azurerm_network_interface.redcap.*.private_ip_address),
    }
  )
}