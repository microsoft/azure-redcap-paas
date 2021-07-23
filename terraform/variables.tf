variable "subscription_id" {
  type        = string
  description = "The subscription you wish to deploy this instance of REDCap into"
}

variable "tags" {
  type = map(any)
}

variable "environment" {
  type        = string
  description = "Environment"
  default     = "dev"
}

variable "location" {
  type        = string
  description = "Location"
  default     = "westus2"

  validation {
    condition = can(index([
      "centralus",
      "eastus",
      "eastus2",
      "northcentralus",
      "southcentralus",
      "westcentralus",
      "westus",
      "westus2"
    ], var.location) >= 0)
    error_message = "The deployment location must be US regions. If you want to deploy to other regions, add them to the list."
  }
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Virtual network address space."
}

variable "subnets" {
  type = list(object({
    name           = string
    address_prefix = string
  }))
  description = "List of subnets"
}

variable "subnet_routes" {
  type = list(object({
    name                   = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = string
  }))
  description = "List of routes to be applied to the ComputeSubnet"
}

variable "storage_account_tier" {
  type        = string
  description = "Storage account tier"
  default     = "Standard"
}

variable "storage_account_replication_type" {
  type        = string
  description = "Storage account replication type"
  default     = "GRS"
}

variable "app_service_plan_tier" {
  type        = string
  description = "App service account tier"
  default     = "Standard"
}

variable "app_service_plan_size" {
  type        = string
  description = "Describes plan's pricing tier and capacity - this can be changed after deployment. Check details at https://azure.microsoft.com/en-us/pricing/details/app-service/"
  default     = "S1"

  validation {
    condition = can(index([
      "F1",
      "D1",
      "B1",
      "B2",
      "B3",
      "S1",
      "S2",
      "S3",
      "P1",
      "P2",
      "P3",
      "P4"
    ], var.app_service_plan_size) >= 0)
    error_message = "The skuName is not valid."
  }
}

variable "vnet_peerings" {
  type = list(object({
    peering_name     = string
    vnet_resource_id = string
  }))
  description = "List of virtual networks peers"
}

variable "firewall_ip" {
  type = string
}

variable "dns_servers" {
  type = list(string)
}

variable "vm_count" {
  type    = number
  default = 1
}

variable "vm_sku" {
  type    = string
  default = "Standard_B2ms"
}

variable "vm_username" {
  type = string
}

variable "vm_password" {
  type = string
}

variable "vm_os_disk_caching" {
  type = object({
    caching              = string
    storage_account_type = string
  })
  description = "Virtual machine OS disk cachine"
  default = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

variable "vm_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  description = "Virtual machine image - Use 'az vm image' command to find your image"
}

variable "administrator_name" {
  type = string
}

variable "devops_subnet_id" {
  type = string
}

#############################################
# AZURE ARM TEMPLATE PARAMETERS
#############################################

variable "siteName" {
  type        = string
  description = "Name of azure web app"
  default     = "redcap"
}

variable "administratorLogin" {
  type        = string
  description = "Database administrator login name"
  default     = "redcap_app"
}

variable "redcapAppZip" {
  type        = string
  description = "A publicly accessible path to your copy of the REDCap zip file."
}

variable "redcapCommunityUsername" {
  type        = string
  description = "REDCap community website username"
  default     = ""
}

variable "redcapCommunityPassword" {
  type        = string
  description = "REDCap community website password"
  sensitive   = true
  default     = ""
}

variable "redcapAppZipVersion" {
  type        = string
  description = "REDCap version"
  default     = "latest"
}

variable "administrator_email" {
  type        = string
  description = "Email address configured as the sending address in RedCAP"
}

variable "skuCapacity" {
  type        = number
  description = "Describes plan's instance count (how many distinct web servers will be deployed in the farm) - this can be changed after deployment"
  default     = 1
}

variable "databaseSkuSizeMB" {
  type    = number
  default = 5120

  description = "Azure database for MySQL sku Size."
}

variable "databaseForMySqlTier" {
  type        = string
  default     = "GeneralPurpose"
  description = "Select MySql server performance tier. Please review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers and ensure your choices are available in the selected region."

  validation {
    condition = can(index([
      "Basic",
      "GeneralPurpose",
      "MemoryOptimized"
    ], var.databaseForMySqlTier) >= 0)
    error_message = "The databaseForMySqlTier is not valid."
  }

}

variable "databaseForMySqlFamily" {
  type        = string
  description = "Select MySql compute generation. Please review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers and ensure your choices are available in the selected region."
  default     = "Gen5"

  validation {
    condition = can(index([
      "Gen4",
      "Gen5"
    ], var.databaseForMySqlFamily) >= 0)
    error_message = "The databaseForMySqlFamily is not valid."
  }
}

variable "databaseForMySqlCores" {
  type        = number
  description = "Select MySql vCore count. Please review https://docs.microsoft.com/en-us/azure/mysql/concepts-pricing-tiers and ensure your choices are available in the selected region."
  default     = 2

  validation {
    condition = can(index([
      1,
      2,
      4,
      8,
      16,
      32
    ], var.databaseForMySqlCores) >= 0)
    error_message = "The databaseForMySqlCores is not valid."
  }
}

variable "mysqlVersion" {
  type        = string
  description = "MySQL version"
  default     = "5.7"

  validation {
    condition = can(index([
      "5.6",
      "5.7"
    ], var.mysqlVersion) >= 0)
    error_message = "The mysqlVersion is not valid."
  }
}

variable "storageType" {
  type        = string
  description = "The default selected is 'Locally Redundant Storage' (3 copies in one region). See https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy for more information."
  default     = "Standard_LRS"

  validation {
    condition = can(index([
      "Standard_LRS",
      "Standard_ZRS",
      "Standard_GRS",
      "Standard_RAGRS",
      "Premium_LRS"
    ], var.storageType) >= 0)
    error_message = "The storageType is not valid."
  }
}

variable "storageContainerName" {
  type        = string
  description = "Name of the container used to store backing files in the new storage account. This container is created automatically during deployment."
  default     = "redcap"
}

variable "repoURL" {
  type        = string
  description = "The path to the deployment source files on GitHub"
  default     = "https://github.com/vanderbilt-redcap/redcap-azure.git"
}

variable "branch" {
  type        = string
  description = "The main branch of the application repo"
  default     = "master"
}