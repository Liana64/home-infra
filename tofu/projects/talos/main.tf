module "ms-01" {
  source    = "../../modules/proxmox-vm"
  providers = { proxmox = proxmox.ms-01 }

  name        = "talos-n1"
  target_node = "ms-01"
  vm_id       = 100
  cores       = 10
  memory      = 24576

  disks = [
    { size = 128 },
    { size = 755 },
  ]

  networks = [
    { bridge = "vmbr2", vlan_id = 10, mac_address = "BC:24:11:15:69:CB" },
    { bridge = "vmbr4", vlan_id = 10, mac_address = "BC:24:11:0D:E4:26" },
  ]

  smbios_uuid = "44960372-e9de-40e2-b1c3-0fd8799943a0"
}

module "n2" {
  source    = "../../modules/proxmox-vm"
  providers = { proxmox = proxmox.n2 }

  name         = "talos-n2"
  target_node  = "n2"
  vm_id        = 100
  cores        = 14
  memory       = 26624
  datastore_id = "local-mirror"

  disks = [
    { size = 128 },
    { size = 1280 },
  ]

  networks = [
    { bridge = "vmbr2", vlan_id = 10, mac_address = "BC:24:11:C7:0F:C6" },
    { bridge = "vmbr1", vlan_id = 10, mac_address = "BC:24:11:25:31:59" },
  ]

  # NVIDIA card, which I'm keeping unplugged right now
  #hostpci = [
  #  { mapping = "GTX_1080", pcie = true },
  #]

  smbios_uuid = "efd7776f-3f94-425d-bcb8-e2613708f4d1"
}

module "n3" {
  source    = "../../modules/proxmox-vm"
  providers = { proxmox = proxmox.n3 }

  name         = "talos-n3"
  target_node  = "n3"
  vm_id        = 100
  cores        = 4
  memory       = 3584
  datastore_id = "local-ssd"

  disks = [
    { size = 128 },
    { size = 512 },
  ]

  networks = [
    { bridge = "vmbr1", vlan_id = 10, mac_address = "BC:24:11:E9:CB:66" },
  ]

  smbios_uuid = "c4056b75-6e4d-4b4a-b83b-7c2b9c561702"
}

output "vm_ids" {
  value = {
    ms-01 = module.ms-01.vm_id
    n2    = module.n2.vm_id
    n3    = module.n3.vm_id
  }
}

output "ipv4_addresses" {
  value = {
    ms-01 = module.ms-01.ipv4_addresses
    n2    = module.n2.ipv4_addresses
    n3    = module.n3.ipv4_addresses
  }
}
