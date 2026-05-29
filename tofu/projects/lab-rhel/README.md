# lab-rhel

VMs for Red Hat Certified Architect (RHCA) study, see [notes](https://github.com/Liana64/RHCA).
One VM per RHEL version, each with three virtual USB devices (HID mouse, HID
keyboard, 250MB mass-storage) for usbguard practice.

## Usage

1. Drop qcow2 cloud images into `images/` (see below).
2. Create `terraform.tfvars` with at least `proxmox_hosts` and `ssh_public_keys`:

   ```hcl
   proxmox_hosts = {
     "n3" = {
       endpoint = "https://n3.lianas.org:8006/"
       username = "root@pam"   # see auth note
       password = "..."
     }
   }
   ssh_public_keys = ["ssh-ed25519 AAAA... you@host"]
   ```

3. `tofu init && tofu apply`. Default guest user is `cloud-user`.

Download images from [access.redhat.com](https://access.redhat.com/) with a
(free) Red Hat Developer Subscription, under "KVM Guest Image".

**Defined images** (`images/`)

- `rhel-8.4-x86_64-kvm.qcow2`
- `rhel-9.2-x86_64-kvm.qcow2`
- `rhel-10.2-x86_64-kvm.qcow2`

Adjust `qcow2_filename_map` and the `rhel_versions` validator in `main.tf` /
`variables.tf` to add versions.

## Auth

The USB devices are attached through qemu-server's `args:` line, which PVE
restricts to `root@pam` — so the API `username` must be `root@pam`. Node-level
work (qcow2 disk import) runs over SSH as `ansible` with NOPASSWD sudo via the
provider `ssh {}` block; no root SSH is granted.

## Recreate

VMs carry `prevent_destroy`, so `-replace` and `destroy` are blocked. To rebuild:

```sh
tofu state rm 'module.vm["8.4"]' 'module.vm["9.2"]' 'module.vm["10.2"]'
ssh ansible@n3.lianas.org 'for id in 400 401 402; do sudo qm stop $id; sudo qm destroy $id --purge; done'
tofu apply
```

`--purge` without `--destroy-unreferenced-disks` keeps the `usb-flash.raw`
images (unreferenced while the VM is gone), so `terraform_data.usb_flash`
need not re-run.
