resource "azurerm_resource_group" "pipelineproject" {
  name     = "robert-jennings-rg"
  location = "West Europe"
}


resource "azurerm_virtual_network" "pipepronetwork" {
  name                = "pipelineproject"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.pipelineproject.location
  resource_group_name = azurerm_resource_group.pipelineproject.name
}

resource "azurerm_subnet" "pipeprosubnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.pipelineproject.name
  virtual_network_name = azurerm_virtual_network.pipepronetwork.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "jenkinspublicip" {
  name                = "jenkins-public-ip"
  resource_group_name = azurerm_resource_group.pipelineproject.name
  location            = azurerm_resource_group.pipelineproject.location
  allocation_method   = "Dynamic"

}

resource "azurerm_network_interface" "jenkinsnic" {
  name                = "jenkins-nic"
  location            = azurerm_resource_group.pipelineproject.location
  resource_group_name = azurerm_resource_group.pipelineproject.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.pipeprosubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkinspublicip.id
  }

depends_on = [
  azurerm_public_ip.jenkinspublicip
]
}
resource "azurerm_network_security_group" "pipelineproject" {
  name                = "pipelineproject-nsg"
  location            = azurerm_resource_group.pipelineproject.location
  resource_group_name = azurerm_resource_group.pipelineproject.name


}
resource "azurerm_network_security_rule" "allout" {
  name                        = "web"
  priority                    = 201
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.pipelineproject.name
  network_security_group_name = azurerm_network_security_group.pipelineproject.name
}
resource "azurerm_network_interface_security_group_association" "jenkinsnsg" {
  network_interface_id      = azurerm_network_interface.jenkinsnic.id
  network_security_group_id = azurerm_network_security_group.pipelineproject.id
}




resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "jenkins-vm"
  resource_group_name = azurerm_resource_group.pipelineproject.name
  location            = azurerm_resource_group.pipelineproject.location
  size                = "Standard_B1s"
  admin_username      = "robjennings"
  network_interface_ids = [
    azurerm_network_interface.jenkinsnic.id,
  ]

  admin_ssh_key {
    username   = "robjennings"
    public_key = file("./id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
}