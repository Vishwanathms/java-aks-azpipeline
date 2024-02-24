provider "azurerm" {
      features {}
}

terraform {
  backend "azurerm" {
    resource_group_name   = "docker-app-vishwa_group"
    storage_account_name  = "vishwa2024tfstate"
    container_name        = "tfstatefiles"
    key                   = "uat-vm-agent.tfstate"
  }
}

resource "random_integer" "ri" {
  count = var.instance_count
  min = 1000
  max = 2999
}

resource "azurerm_resource_group" "rg01" {
  name     = var.rg_name
  location = "East US"  # Replace with your desired Azure region
}

resource "azurerm_virtual_network" "vnet" {
  count = var.create_Vnet ? 1 : 0
  #name                = "${var.location}-vnet"
  name                = var.virtual_network_name
  location            = azurerm_resource_group.rg01.location
  resource_group_name = azurerm_resource_group.rg01.name
  address_space       = var.address_space
  tags                = { env = var.tag_env }
  dns_servers         = var.dns_servers
}

resource "azurerm_subnet" "subnet" {
  count             = length(var.subnet_cidrs)
  #count             = (length(var.subnet_cidrs) != 0 ? length(var.subnet_cidrs) : 0)
  name                = format("%s-%s-%s", var.subnet_type, var.tag_env, var.subnet_name[count.index] )
  resource_group_name  = azurerm_resource_group.rg01.name
  #virtual_network_name = var.virtual_network_name
  virtual_network_name = length(azurerm_virtual_network.vnet) > 0 ? azurerm_virtual_network.vnet[0].name : var.virtual_network_name
  address_prefixes     = [var.subnet_cidrs[count.index]]
}

# Ansible-controller 

resource "azurerm_public_ip" "pips" {
  count = var.instance_count
  name                = "pip-${random_integer.ri[count.index].result}"
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  allocation_method   = "Static"

  #tags = var.standard_tags["stnd_tag"]
}

resource "azurerm_network_interface" "main" {
  count = var.instance_count
  name                = "nic-${random_integer.ri[count.index].result}"
  location            = azurerm_resource_group.rg01.location
  resource_group_name = azurerm_resource_group.rg01.name

  ip_configuration {
    name                          = "nic-${random_integer.ri[count.index].result}"
    #making is simple to provision all the VM's in the same subnet
    subnet_id                     = azurerm_subnet.subnet[0].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pips[count.index].id
  }
}

# Define the storage account resource
resource "azurerm_storage_account" "main" {
  name                     = "vishwa2024vmdiag"  
  resource_group_name      = azurerm_resource_group.rg01.name  
  location                 = "East US"  
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "teamcontainer"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

resource "azurerm_virtual_machine" "main" {
  count = var.instance_count
  name                  = "${var.vm_name}-${random_integer.ri[count.index].result}"
  location              = azurerm_resource_group.rg01.location
  resource_group_name   = azurerm_resource_group.rg01.name
  network_interface_ids = [azurerm_network_interface.main[count.index].id]
  vm_size               = var.vm_size
  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_os_disk_on_termination = true

  boot_diagnostics {
    enabled = true  # Disable boot diagnostics
    storage_uri = azurerm_storage_account.main.primary_blob_endpoint
  }
  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.os_disk_name}-${random_integer.ri[count.index].result}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "${var.vm_name}-${random_integer.ri[count.index].result}"
    admin_username = var.admin_username
    admin_password = var.vm_pwd

  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = var.standard_tags["stnd_tag"]
  depends_on = [ azurerm_network_security_group.nsg, azurerm_storage_account.main]
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.name_nsg
  resource_group_name = azurerm_resource_group.rg01.name
  location            = azurerm_resource_group.rg01.location
  tags = var.standard_tags["stnd_tag"]
  
  dynamic "security_rule" {
    for_each = var.nsgrules 
    content {
      name                       = security_rule.value["name"] == "" ? "Default_Rule" : security_rule.value["name"]
      priority                   = security_rule.value["priority"]
      direction                  = security_rule.value["direction"] == "" ? "Inbound" : security_rule.value["direction"]
      access                     = security_rule.value["access"] == "" ? "Allow" : security_rule.value["access"]
      protocol                   = security_rule.value["protocol"] == "" ? "Tcp" : security_rule.value["protocol"]
      source_port_range          = "*"
      destination_port_range     = security_rule.value["destination_port_range"] == "" ? "*" : security_rule.value["destination_port_range"]
      source_address_prefix       =  security_rule.value["source_address_prefix"]
      destination_address_prefix =  security_rule.value["destination_address_prefix"]
      description                = "${security_rule.value["direction"]}_Port_${security_rule.value["destination_port_range"]}"
    }
  }
  
}

resource "azurerm_network_interface_security_group_association" "mySecGroupAssociation1" {
    count = var.instance_count
    network_interface_id      = azurerm_network_interface.main[count.index].id
    network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "null_resource" "Instal-az-agent" {

  /*triggers = {
    always_run = timestamp()
  }*/
  connection {
      type = "ssh"
      user = var.admin_username
      password = var.vm_pwd
      #host = azurerm_virtual_machine.main[0].public_ip_address
      host = azurerm_public_ip.pips[0].ip_address
      timeout = "60s"
      agent = false  
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir myagent",
      "wget -P myagent ${var.agent-url}",
      "tar zxvf myagent/vsts*.tar.gz",
      "./config.sh --unattended --url ${var.AZP_URL} --token ${var.AZP_TOKEN} --agent ${var.AZP_AGENT_NAME} --pool ${var.AZP_POOL}",
      "sleep 120",
      "nohup ./run.sh &",
    ]
  }
  depends_on = [ azurerm_network_security_group.nsg, azurerm_virtual_machine.main ]
}

resource "null_resource" "Instal-ansible" {

  triggers = {
    always_run = timestamp()
  }
  connection {
      type = "ssh"
      user = var.admin_username
      password = var.vm_pwd
      #host = azurerm_virtual_machine.main[0].public_ip_address
      host = azurerm_public_ip.pips[0].ip_address
      timeout = "60s"
      agent = false  
  }
  provisioner "file" {
    source      = "ansi-code/scripts.sh"
    destination = "scripts.sh"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt-add-repository ppa:ansible/ansible -y",
      "sudo apt update -y",
      "sudo apt install ansible -y",
      "sed -i 's/\r$//' scripts.sh",
      "chmod 770 scripts.sh",
      "./scripts.sh ${var.vm_pwd}"
    ]
  }
  depends_on = [ azurerm_network_security_group.nsg, azurerm_virtual_machine.main ]
}

output "pip" {
  value = azurerm_public_ip.pips[0].ip_address
}
