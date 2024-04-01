provider "azurerm" {
  features {}
}

resource "azurerm_public_ip" "vm_public_ip" {
  count                = 3
    name                 = "vm-public-ip-${count.index}"
    location             = "East US"
    resource_group_name  = "rg1"
    allocation_method    = "Dynamic"
          }
resource "azurerm_virtual_machine" "linux_vm" {
  count                 = 3
  name                  = "linux-vm-${count.index}"
  location              = "East US"
  resource_group_name   = "rg1"
  network_interface_ids = [azurerm_network_interface.vm_nic[count.index].id]
  vm_size               = "Standard_DS2_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile {
    computer_name  = "linux-vm-${count.index}"
    admin_username = "aryan"
    admin_password = "Aryan@6387402913"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
provisioner "local-exec" {
    command = <<EOT
      echo '${azurerm_linux_virtual_machine.linux_vm.public_ip_address} ansible_connection=ssh ansible_user=adminuser' >> inventory
      echo '[webservers]' > ansible.cfg
      echo 'inventory = inventory' >> ansible.cfg
EOT
  }


  provisioner "remote-exec" {
    inline = [
      "echo '${file("/var/jenkins_home/.ssh/id_rsa.pub")}' >> ~/.ssh/authorized_keys",
    ]

    connection {
      type        = "ssh"
      user        = "aryan"
      password    = "Aryan@6387402913"
      host        = self.public_ip_address
    }
  }
}
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = "East US"
  resource_group_name = "rg1"

  security_rule {
    name                       = "AllowAll"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_network_interface" "vm_nic" {
  count               = 3
  name    = "vm-nic-${count.index}"
  location            = "East US"
  resource_group_name = "rg1"

  ip_configuration {
    name                          = "internal"
    subnet_id                     = "/subscriptions/fa145963-b0f6-4b09-bbeb-076c3c14d4ab/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/master-vnet/subnets/default"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm_public_ip[count.index].id
  }
  
}
resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = "/subscriptions/fa145963-b0f6-4b09-bbeb-076c3c14d4ab/resourceGroups/rg1/providers/Microsoft.Network/virtualNetworks/master-vnet/subnets/default"
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}

