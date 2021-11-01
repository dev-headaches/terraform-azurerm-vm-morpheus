terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 2.3.0"
    }
  }
}


#construct list of different things from the hub
locals {
  sec_rg = format("%s%s%s%s%s%s", "rg_hub", "_", "Security", var.orgname, var.enviro, var.prjnum)
  connectivity_rg = format("%s%s%s%s%s%s", "rg_hub", "_", "Connectivity", var.orgname, var.enviro, var.prjnum)
  compute_rg = format("%s%s%s%s%s%s", "rg_hub", "_", "Compute", var.orgname, var.enviro, var.prjnum)
  aks_rg = format("%s%s%s%s%s%s", "rg_hub", "_", "AKS", var.orgname, var.enviro, var.prjnum)
  netsec_rg = format("%s%s%s%s%s%s", "rg_hub", "_", "NetSec", var.orgname, var.enviro, var.prjnum)
  mgmt_rg = format("%s%s%s%s%s%s", "rg_hub", "_", "MGMT", var.orgname, var.enviro, var.prjnum)
  hub_vnet = format("%s%s%s%s%s", "vnet_", "hub", var.orgname, var.enviro, var.prjnum)
  vmname = format("vm-%s-%s-%s", var.name, var.enviro, var.prjnum)
  hub_azfw_name = format("%s%s%s%s", "fw_hub_", var.orgname, var.enviro, var.prjnum)
  morphpowershellscriptfile= try(file("./morphinstall.ps1"), null)
  base64EncodedScript = base64encode(local.morphpowershellscriptfile)
}

data "azurerm_resources" "vmpasswordkeyvault" {
  type = "Microsoft.KeyVault/vaults"
  resource_group_name = local.sec_rg
  required_tags = {
    environment = var.enviro
    prjnum = var.prjnum
    orgname = var.orgname
    usecase = "vmpasswords"
  }
}

data "azurerm_key_vault" "vmsecretkv" {
  name = data.azurerm_resources.vmpasswordkeyvault.resources[0].name
  resource_group_name = local.sec_rg
}

data "azurerm_subnet" "hub_vm_subnet" {
  name = "snet_vm"
  virtual_network_name = local.hub_vnet
  resource_group_name = local.connectivity_rg
}

data "azurerm_firewall" "hub_firewall" {
  name = local.hub_azfw_name
  resource_group_name = local.connectivity_rg
}

resource "random_password" "vmpasswd" {
  length           = 16
  min_lower        = 1
  min_upper        = 1
  min_special      = 1
  special          = true
  override_special = "_%@"
}

resource "azurerm_key_vault_secret" "vmpasswdINPUT" {
  name         = format("%s%s", "vmpasswd-", local.vmname)
  value        = random_password.vmpasswd.result
  key_vault_id = data.azurerm_key_vault.vmsecretkv.id
}

data "azurerm_key_vault_secret" "vmpasswd" {
  name         = format("%s%s", "vmpasswd-", local.vmname)
  key_vault_id = data.azurerm_key_vault.vmsecretkv.id
  depends_on = [
    azurerm_key_vault_secret.vmpasswdINPUT,
  ]
}

resource "azurerm_network_interface" "vmnic" {
  name                = format("%s%s", "nic-", local.vmname)
  location            = data.azurerm_firewall.hub_firewall.location
  resource_group_name = local.compute_rg
  dns_servers         = [data.azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address]

  ip_configuration {
    name                          = format("%s%s", "ipcfg-", local.vmname)
    subnet_id                     = data.azurerm_subnet.hub_vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                            = local.vmname
  computer_name                   = substr(format("%s%s", var.name, var.prjnum), 0,15)
  resource_group_name             = local.compute_rg
  location                        = data.azurerm_firewall.hub_firewall.location
  size                            = var.vmsize
  admin_username                  = "azureuser"
  admin_password                  = data.azurerm_key_vault_secret.vmpasswd.value
  //disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.vmnic.id]
  #delete_os_disk_on_termination  = "true"

  os_disk {
    #name              = format("%s%s", resource.azurerm_virtual_machine.vmweb.name, "-osdsk")   #format("%s%s", "disk1_", local.vmname)
    #create_option     = "FromImage"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_extension" "morpheus_agent" {
  name                 = "install-morph-agent"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {
    "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${local.base64EncodedScript }')) | Out-File -filepath morphinstall.ps1\" && powershell -ExecutionPolicy Unrestricted -File morphinstall.ps1"
  }
  SETTINGS

  depends_on = [
    azurerm_windows_virtual_machine.vm
  ]
}
/*
data "template_file" "tf" {
    template = "${file("./morphinstall.ps1")}"
    vars = {
      morph_api_key = var.morph_api_key
      morph_url = var.morph_url
   }
} 
*/

