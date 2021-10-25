terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.12"
    }
  }
}

resource "random_password" "vmpasswd" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azurerm_key_vault_secret" "vmpasswdINPUT" {
  name         = "vmpasswd"
  value        = random_password.vmpasswd.result
  key_vault_id = var.kvid
}

data "azurerm_key_vault_secret" "vmpasswd" {
  name         = "vmpasswd"
  key_vault_id = var.kvid
  depends_on = [
    azurerm_key_vault_secret.vmpasswdINPUT,
  ]
}

locals {
  vmname = format("%s%s", "vm-", var.name)
} 

resource "azurerm_network_interface" "vmnic" {
  name                = format("%s%s", "nic-", local.vmname)
  location            = var.location
  resource_group_name = var.rgname

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnetID
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                            = local.vmname
  resource_group_name             = var.rgname
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