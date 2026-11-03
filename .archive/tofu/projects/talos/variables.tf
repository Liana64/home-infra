variable "nodes" {
  description = "Talos VMs, keyed by short name (n1, n2, ...). Each VM's name becomes talos-<key>."

  type = map(object({
    target_node  = string
    vm_id        = number
    cores        = number
    memory       = number
    datastore_id = optional(string, "local-pool")
    disks = list(object({
      size = number
      ssd  = optional(bool, true)
      aio  = optional(string, "native")
    }))
    networks = list(object({
      bridge      = string
      vlan_id     = optional(number)
      firewall    = optional(bool, true)
      mac_address = optional(string)
    }))
    hostpci = optional(list(object({
      mapping  = optional(string)
      id       = optional(string)
      pcie     = optional(bool)
      rombar   = optional(bool)
      xvga     = optional(bool)
      rom_file = optional(string)
      mdev     = optional(string)
    })), [])
    smbios_uuid = string
  }))

  default = {
    ms-01 = {
      target_node  = "ms-01"
      vm_id        = 100
      cores        = 10
      memory       = 24576
      datastore_id = "local-pool"
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

    n2 = {
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
      hostpci = [
        { mapping = "GTX_1080", pcie = true },
      ]
      smbios_uuid = "efd7776f-3f94-425d-bcb8-e2613708f4d1"
    }

    n3 = {
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
  }
}
