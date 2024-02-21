# Genral Values
tag_env = "dev"
rg_name = "capstone-rg"

# Vnet Values
virtual_network_name = "capstone-vnet"
create_Vnet = true
address_space = [ "10.10.0.0/16" ]

# Subnet Values
subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
subnet_name = ["capstone-sub01", "capstone-sub02"]
subnet_type = "public"

instance_count = 1
vm_name = "capstone-VM"
os_disk_name = "os_disk"
vm_size = "Standard_D2s_v3"

name_nsg = "capstone-nsg"

standard_tags = {
    stnd_tag = {
        Env   = "Dev"
        Owner = "V"
        Project = "p1"
        Location = "East us"
    }
}


nsgrules = [
  {
  name                       = "AllowWebIn"
  priority                   = 100
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "80"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  },
  {
  name                       = "AllowSSHIn"
  priority                   = 110
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "22"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  },
  {
  name                       = "Allow8080In"
  priority                   = 120
  direction                  = "Inbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "8080"
  source_address_prefix      = "*"
  destination_address_prefix = "*"
  }
]


#Values for Azure pipeline
organization = "Vishwacloudlab"
project = "APP-Development"
AZP_TOKEN = "4axbgqkmuxa5dgpfvknh5ee75fvhjy5phortcxl4bkoosoelw3oa"
AZP_POOL = "UAT"
agent-url = "https://vstsagentpackage.azureedge.net/agent/3.232.3/vsts-agent-linux-x64-3.232.3.tar.gz"
AZP_URL = "https://dev.azure.com/Vishwacloudlab"
AZP_AGENT_NAME = "Ag-3"
