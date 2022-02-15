# Configure the Microsoft Azure Provid
terraform {
  required_version = ">=0.12"

  required_providers {
      azurerm = {
           source = "hashicorp/azurerm"
           version = "~>2.0"
      }
  }
}

provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "awxterraformgroup" {
    name     = "AWXResourceGroup"
    location = "eastus"

    tags = {
        environment = "Asibel Tower"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "awxterraformnetwork" {
    name                = "awxVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.awxterraformgroup.name

    tags = {
        environment = "Asibel Tower"
    }
}


# Create subnet
resource "azurerm_subnet" "awxterraformsubnet" {
    name                 = "awxSubnet"
    resource_group_name  = azurerm_resource_group.awxterraformgroup.name
    virtual_network_name = azurerm_virtual_network.awxterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}


# Create public IPs
resource "azurerm_public_ip" "awxterraformpublicip" {
    name                         = "anyPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.awxterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Asibel Tower"
    }
}



# Create Network Security Group and rule
resource "azurerm_network_security_group" "awxterraformnsg" {
    name                = "awxNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.awxterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Asibel Tower"
    }
}

# Create network interface
resource "azurerm_network_interface" "awxterraformnic" {
    name                      = "awxNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.awxterraformgroup.name

    ip_configuration {
        name                          = "awxNicConfiguration"
        subnet_id                     = azurerm_subnet.awxterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.awxterraformpublicip.id
    }

    tags = {
        environment = "Asibel Tower"
    }
}


# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "awx" {
    network_interface_id      = azurerm_network_interface.awxterraformnic.id
    network_security_group_id = azurerm_network_security_group.awxterraformnsg.id
}


# Create (and display) an SSH key
resource "tls_private_key" "awx_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.awx_ssh.private_key_pem 
    sensitive = true
}


# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvmawx" {
    name                  = "awxVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.awxterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myterraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "awxvm"
    admin_username = "aphinn"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "aphinn"
        public_key     = tls_private_key.awx_ssh.public_key_openssh
    }

 
    tags = {
        environment = "Ansible Tower"
    }
}