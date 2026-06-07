terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.101"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name          = var.name
  node_name     = var.target_node
  vm_id         = var.vm_id
  on_boot       = var.on_boot
  started       = var.started
  kvm_arguments = var.kvm_arguments

  startup {
    order = var.startup_order
  }

  agent {
    enabled = true
  }

  bios    = "ovmf"
  machine = "q35"

  cpu {
    cores   = var.cores
    sockets = var.sockets
    type    = var.cpu_type
    numa    = false
  }

  memory {
    dedicated = var.memory
    floating  = 0
  }

  operating_system {
    type = "l26"
  }

  efi_disk {
    datastore_id = var.datastore_id
    type         = "4m"
  }

  tpm_state {
    datastore_id = var.datastore_id
    version      = "v2.0"
  }

  cdrom {
    file_id   = var.iso # set to none for empty
    interface = "ide2"
  }

  dynamic "disk" {
    for_each = var.disks
    content {
      datastore_id = var.datastore_id
      interface    = "scsi${disk.key}"
      size         = disk.value.size
      file_id      = disk.value.file_id
      file_format  = disk.value.file_format
      discard      = "on"
      iothread     = true
      ssd          = disk.value.ssd
      aio          = disk.value.aio
    }
  }

  dynamic "initialization" {
    for_each = var.cloud_init != null ? [var.cloud_init] : []
    content {
      datastore_id = coalesce(initialization.value.datastore_id, var.datastore_id)
      interface    = initialization.value.interface

      dynamic "user_account" {
        for_each = initialization.value.user_account != null ? [initialization.value.user_account] : []
        content {
          username = user_account.value.username
          password = user_account.value.password
          keys     = user_account.value.keys
        }
      }

      dynamic "dns" {
        for_each = initialization.value.dns != null ? [initialization.value.dns] : []
        content {
          domain  = dns.value.domain
          servers = dns.value.servers
        }
      }

      dynamic "ip_config" {
        for_each = initialization.value.ip_config
        content {
          dynamic "ipv4" {
            for_each = ip_config.value.ipv4 != null ? [ip_config.value.ipv4] : []
            content {
              address = ipv4.value.address
              gateway = ipv4.value.gateway
            }
          }
          dynamic "ipv6" {
            for_each = ip_config.value.ipv6 != null ? [ip_config.value.ipv6] : []
            content {
              address = ipv6.value.address
              gateway = ipv6.value.gateway
            }
          }
        }
      }
    }
  }

  scsi_hardware = "virtio-scsi-single"

  boot_order = concat(
    [for i, _ in var.disks : "scsi${i}"],
    ["ide2"]
  )

  dynamic "network_device" {
    for_each = var.networks
    content {
      bridge      = network_device.value.bridge
      model       = "virtio"
      firewall    = network_device.value.firewall
      vlan_id     = network_device.value.vlan_id
      mac_address = network_device.value.mac_address
    }
  }

  dynamic "smbios" {
    for_each = var.smbios_uuid != null ? [1] : []
    content {
      uuid = var.smbios_uuid
    }
  }

  dynamic "serial_device" {
    for_each = var.serial_device != null ? [1] : []
    content {
      device = var.serial_device
    }
  }

  dynamic "hostpci" {
    for_each = var.hostpci
    content {
      device   = "hostpci${hostpci.key}"
      mapping  = hostpci.value.mapping
      id       = hostpci.value.id
      pcie     = hostpci.value.pcie
      rombar   = hostpci.value.rombar
      xvga     = hostpci.value.xvga
      rom_file = hostpci.value.rom_file
      mdev     = hostpci.value.mdev
    }
  }

  # Global safety net: VMs managed by this module cannot be destroyed by
  # `tofu destroy` or an implicit replace. Intentional rebuilds require
  # `tofu state rm` first (see .taskfiles/tofu.yaml nuke-talos).
  lifecycle {
    prevent_destroy = true
  }
}
