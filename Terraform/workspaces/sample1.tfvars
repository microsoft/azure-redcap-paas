# the values here will be updated per deployment
subscription_id = "<YOUR_REDCAP_DEPLOYMENT_SUBSCRIPTION_ID>"

vnet_peerings = [
  {
    peering_name     = "to-netops"
    vnet_resource_id = "<YOUR_HUB_VNET_RESOURCE_ID>"
  },
]

devops_subnet_id = "<YOUR_DEVOPS_SUBNET_RESOURCE_ID>"

redcapCommunityUsername = ""
redcapCommunityPassword = ""
redcapAppZipVersion     = "latest"

environment = "prod"

tags = {
  "po-number"          = "zzz"
  "environment"        = "prod"
  "mission"            = "administrative"
  "protection-level"   = "p1"
  "availability-level" = "a1"
}

vm_count = 1
vm_sku   = "Standard_D4s_v4"
vm_image = {
  publisher = "microsoftwindowsdesktop"
  offer     = "office-365"
  sku       = "20h2-evd-o365pp"
  version   = "latest"
}

# this is really important - make sure addresses do not overlap
vnet_address_space = ["10.230.0.0/25"]
subnets = [
  {
    name           = "PrivateLinkSubnet"
    address_prefix = "10.230.0.0/27"
  },
  {
    name           = "ComputeSubnet"
    address_prefix = "10.230.0.32/27"
  },
  {
    name           = "IntegrationSubnet"
    address_prefix = "10.230.0.64/26"
  }
]

# the values below are pretty much static for all deployments
repoURL                          = "https://github.com/microsoft/azure-redcap-paas.git"
branch                           = "master"
location                         = "westus2"
storage_account_tier             = "Standard"
storage_account_replication_type = "LRS"
administrator_name               = "Paul Yu"
administrator_email              = "pauyu@microsoft.com"
firewall_ip                      = "10.21.1.132"
dns_servers                      = ["10.21.1.132", "168.63.129.16"]

subnet_routes = [
  {
    name                   = "to-internet"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.21.1.132"
  },
  {
    name                   = "to-aadds"
    address_prefix         = "10.21.0.0/28"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.21.1.132"
  },
  {
    name                   = "to-devops"
    address_prefix         = "10.21.0.16/28"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = "10.21.1.132"
  }
]