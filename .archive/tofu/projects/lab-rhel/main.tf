locals {
  qcow2_filename_map = {
    "8.4"  = "rhel-8.4-x86_64-kvm.qcow2"
    "9.2"  = "rhel-9.2-x86_64-kvm.qcow2"
    "10.2" = "rhel-10.2-x86_64-kvm.qcow2"
  }

  # Source of truth for VM identity. Map key is the state address; the first instance per version keeps the bare version so existing state survives. enabled defaults false (powered off, autostart disabled).
  instances = {
    "8.4"   = { version = "8.4", environment = "a", vm_id = 400, mac = "BC:24:11:B1:D7:E1" }
    "9.2"   = { version = "9.2", environment = "a", vm_id = 401, mac = "BC:24:11:B6:50:3D", enabled = true }
    "9.2-b" = { version = "9.2", environment = "b", vm_id = 403, mac = "BC:24:11:B6:50:3E", enabled = true }
    "10.2"  = { version = "10.2", environment = "a", vm_id = 402, mac = "BC:24:11:20:13:08", enabled = true }
  }

  # One staged image per version, shared by all its instances (must not re-stage or race the destroy rm).
  versions = {
    for ver, file in local.qcow2_filename_map :
    ver => {
      qcow2_local_path = "${path.module}/images/${file}"
      # PVE's iso parser rejects .qcow2; stage as .img and let file_format="qcow2" describe the bytes.
      staged_filename = replace(file, ".qcow2", ".img")
    }
  }

  # Enrich each instance with its derived, version-shared fields.
  vms = {
    for key, inst in local.instances :
    key => merge(inst, {
      enabled         = try(inst.enabled, false)
      vm_name         = "lab-rhel${split(".", inst.version)[0]}-${inst.environment}"
      staged_filename = local.versions[inst.version].staged_filename
      # 250MB raw image backing the virtual usb-storage device, parked under PVE's per-VM `local` path.
      usb_image_path = "/var/lib/vz/images/${inst.vm_id}/usb-flash.raw"
    })
  }
}

# Stage qcow2 via scp+ssh (ansible NOPASSWD sudo); the provider's HTTP upload chokes on large images.
resource "terraform_data" "rhel_qcow2" {
  for_each = local.versions

  triggers_replace = {
    file_hash = filemd5(each.value.qcow2_local_path)
    target    = var.target_node
    filename  = each.value.staged_filename
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      scp -o StrictHostKeyChecking=accept-new \
        ${each.value.qcow2_local_path} \
        ansible@${var.target_node}.lianas.org:/tmp/${each.value.staged_filename}
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${var.target_node}.lianas.org \
        sudo install -m 0644 -o root -g root \
          /tmp/${each.value.staged_filename} \
          /var/lib/vz/template/iso/${each.value.staged_filename}
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${var.target_node}.lianas.org \
        rm -f /tmp/${each.value.staged_filename}
    EOT
  }

  # Destroy provisioners see only `self`, so pull filename/target from triggers_replace.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${self.triggers_replace.target}.lianas.org \
        sudo rm -f /var/lib/vz/template/iso/${self.triggers_replace.filename}
    EOT
  }
}

# Virtual USB devices for usbguard testing (HID mouse, HID keyboard, 250MB mass-storage), wired via qemu's `args:`.
resource "terraform_data" "usb_flash" {
  for_each = local.vms

  triggers_replace = {
    target = var.target_node
    path   = each.value.usb_image_path
    size   = "250M"
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${var.target_node}.lianas.org \
        sudo install -d -m 0750 -o root -g root $(dirname ${each.value.usb_image_path})
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${var.target_node}.lianas.org \
        "sudo test -f ${each.value.usb_image_path} || sudo truncate -s 250M ${each.value.usb_image_path}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      ssh -o StrictHostKeyChecking=accept-new \
        ansible@${self.triggers_replace.target}.lianas.org \
        sudo rm -f ${self.triggers_replace.path}
    EOT
  }
}

module "vm" {
  for_each = local.vms
  source   = "../../modules/proxmox-vm"

  target_node  = var.target_node
  datastore_id = var.datastore_id
  iso          = "none"

  name     = each.value.vm_name
  vm_id    = each.value.vm_id
  cores    = 2
  memory   = 2048
  cpu_type = "host"
  started  = each.value.enabled
  on_boot  = each.value.enabled

  disks = [
    {
      size        = 20
      file_id     = "${var.image_datastore_id}:iso/${each.value.staged_filename}"
      file_format = "qcow2"
    },
    { size = 12 },
    { size = 8 },
  ]

  networks = [{ bridge = "vmbr1", vlan_id = 80, mac_address = each.value.mac }]

  kvm_arguments = join(" ", [
    "-device usb-mouse,id=usbguard-mouse",
    "-device usb-kbd,id=usbguard-kbd",
    "-drive if=none,id=usbguard-flash,file=${each.value.usb_image_path},format=raw,cache=none",
    "-device usb-storage,drive=usbguard-flash,id=usbguard-flash,serial=usbguard-test",
  ])

  cloud_init = {
    user_account = {
      username = var.admin_username
      password = var.admin_password
      keys     = var.ssh_public_keys
    }
    dns = { servers = ["1.1.1.1", "9.9.9.9"] }
    ip_config = [{
      ipv4 = {
        address = var.ip_config.ipv4_address
        gateway = var.ip_config.ipv4_gateway
      }
    }]
  }

  depends_on = [terraform_data.rhel_qcow2, terraform_data.usb_flash]
}

output "labs" {
  description = "Map of deployed labs keyed by instance."
  value = {
    for key, vm in local.vms :
    key => {
      vm_id          = module.vm[key].vm_id
      vm_name        = vm.vm_name
      ipv4_addresses = module.vm[key].ipv4_addresses
    }
  }
}
