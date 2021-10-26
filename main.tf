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
  vmname = format("%s%s", "vm-", var.name)
}

data "azurerm_key_vault" "vmsecretkv" {
  name = var.kv_name
  resource_group_name = local.sec_rg
}

data "azurerm_subnet" "hub_vm_subnet" {
  name = "snet_vm"
  virtual_network_name = local.hub_vnet
  resource_group_name = local.connectivity_rg
}

resource "random_password" "vmpasswd" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azurerm_key_vault_secret" "vmpasswdINPUT" {
  name         = "vmpasswd"
  value        = random_password.vmpasswd.result
  key_vault_id = data.azurerm_key_vault.vmsecretkv.id
}

data "azurerm_key_vault_secret" "vmpasswd" {
  name         = "vmpasswd"
  key_vault_id = data.azurerm_key_vault.vmsecretkv.id
  depends_on = [
    azurerm_key_vault_secret.vmpasswdINPUT,
  ]
}

resource "azurerm_network_interface" "vmnic" {
  name                = format("%s%s", "nic-", local.vmname)
  location            = "usgovvirginia"
  resource_group_name = local.compute_rg

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.hub_vm_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                            = local.vmname
  resource_group_name             = local.compute_rg
  location                        = "usgovvirginia"
  size                            = "Standard_DS1_v2"
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