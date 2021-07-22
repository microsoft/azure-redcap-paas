locals {
  resource_name      = var.environment == "prod" ? lower(format("%s-%s", var.siteName, terraform.workspace)) : lower(format("%s-%s-%s", var.siteName, terraform.workspace, var.environment))
  mysql_sku          = format("%s_%s_%s", join("", regexall("[^a-z]", var.databaseForMySqlTier)), var.databaseForMySqlFamily, var.databaseForMySqlCores)
  app_service_name   = lower(format("as%s%s", join("", regexall("[^-]", local.resource_name)), random_string.redcap.result))
  mysql_name         = lower(format("mysql%s%s", join("", regexall("[^-]", local.resource_name)), random_string.redcap.result))
  storage_name       = lower(format("sa%s%s", join("", regexall("[^-]", local.resource_name)), random_string.redcap.result))
  storage_share_name = lower(format("sa%sfiles%s", join("", regexall("[^-]", local.resource_name)), random_string.redcap.result))
  keyvault_name      = lower(format("kv%s%s", join("", regexall("[^-]", local.resource_name)), random_string.redcap.result))
  vm_name            = lower(format("vm%s", join("", regexall("[^-]", terraform.workspace))))
}