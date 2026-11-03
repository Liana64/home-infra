module "ms-01" {
  source    = "../../modules/proxmox-vm"
  providers = { proxmox = proxmox.ms-01 }

  name         = "opnsense"
  target_node  = "ms-01"
  vm_id        = 101
  cores        = 4
  memory       = 4096
  datastore_id = "local-lvm"

  iso           = "none"
  serial_device = "socket"
  startup_order = "1"

  disks = [
    { size = 48 },
  ]

  networks = [
    { bridge = "vmbr2", mac_address = "BC:24:11:C4:32:01" },
    { bridge = "vmbr3", mac_address = "BC:24:11:C4:32:02" },
  ]

  smbios_uuid = "dceac24d-7983-4104-98f3-97ee745da225"
}

module "n2" {
  source    = "../../modules/proxmox-vm"
  providers = { proxmox = proxmox.n2 }

  name         = "opnsense"
  target_node  = "n2"
  vm_id        = 101
  cores        = 4
  memory       = 3072
  datastore_id = "local-lvm"

  iso           = "none"
  startup_order = "1"
  on_boot       = false

  disks = [
    { size = 48, ssd = false },
  ]

  networks = [
    { bridge = "vmbr0", mac_address = "BC:24:11:F8:7A:FB" },
  ]

  smbios_uuid = "f4598cb6-bf3a-4200-87da-a92ed6e2c36f"
}

output "vm_ids" {
  value = {
    ms-01 = module.ms-01.vm_id
    n2    = module.n2.vm_id
  }
}
