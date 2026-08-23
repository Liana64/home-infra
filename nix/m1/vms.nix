{
  pkgs,
  lib,
  ...
}: let
  talosVersion = "v1.12.6";
  schematicNvidia = "6951b9af7ee1333ba6431429e14c6f096ef257d27c82ffdfa976ff55a293b409";
  talosISO = pkgs.fetchurl {
    url = "https://factory.talos.dev/image/${schematicNvidia}/${talosVersion}/nocloud-amd64-secureboot.iso";
    hash = "sha256-k12DiG2Zr25GsZ7sjt4k726BoZnfHm075xW80UpUJwo=";
  };

  mkHostdev = {
    bus,
    slot,
    fn,
  }: ''
    <hostdev mode="subsystem" type="pci" managed="yes">
      <source>
        <address domain="0x0000" bus="${bus}" slot="${slot}" function="${fn}"/>
      </source>
    </hostdev>
  '';

  mkDisk = {
    zvol,
    dev,
    boot ? null,
  }: ''
    <disk type="block" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native" discard="unmap"/>
      <source dev="/dev/zvol/rpool/vms/${zvol}"/>
      <target dev="${dev}" bus="scsi"/>
      ${lib.optionalString (boot != null) ''<boot order="${toString boot}"/>''}
    </disk>
  '';

  mkTalosVM = {
    name,
    uuid,
    mac,
    vlan,
    vcpus,
    memoryGiB,
    disks,
    hostdevs ? [],
  }: {
    active = true;
    restart = false;
    definition = pkgs.writeText "${name}.xml" ''
      <domain type="kvm">
        <name>${name}</name>
        <uuid>${uuid}</uuid>
        <memory unit="GiB">${toString memoryGiB}</memory>
        <vcpu placement="static">${toString vcpus}</vcpu>
        <iothreads>1</iothreads>
        <os>
          <type arch="x86_64" machine="q35">hvm</type>
          <loader readonly="yes" type="pflash">${pkgs.OVMF.fd}/FV/OVMF_CODE.fd</loader>
          <nvram template="${pkgs.OVMF.fd}/FV/OVMF_VARS.fd">/var/lib/libvirt/qemu/nvram/${name}.fd</nvram>
        </os>
        <features>
          <acpi/>
          <apic/>
        </features>
        <cpu mode="host-passthrough"/>
        <clock offset="utc"/>
        <devices>
          <emulator>${pkgs.qemu_kvm}/bin/qemu-system-x86_64</emulator>
          <controller type="scsi" model="virtio-scsi">
            <driver iothread="1"/>
          </controller>
          ${lib.concatMapStrings mkDisk disks}
          <disk type="file" device="cdrom">
            <driver name="qemu" type="raw"/>
            <source file="${talosISO}"/>
            <target dev="sdz" bus="sata"/>
            <readonly/>
            <boot order="2"/>
          </disk>
          <interface type="bridge">
            <source bridge="br0"/>
            <mac address="${mac}"/>
            <vlan>
              <tag id="${toString vlan}"/>
            </vlan>
            <model type="virtio"/>
          </interface>
          <serial type="pty"/>
          <console type="pty"/>
          <channel type="unix">
            <target type="virtio" name="org.qemu.guest_agent.0"/>
          </channel>
          <tpm model="tpm-crb">
            <backend type="emulator" version="2.0"/>
          </tpm>
          <rng model="virtio">
            <backend model="random">/dev/urandom</backend>
          </rng>
          <graphics type="vnc" autoport="yes"/>
          <video>
            <model type="virtio"/>
          </video>
          <memballoon model="none"/>
          ${lib.concatMapStrings mkHostdev hostdevs}
        </devices>
      </domain>
    '';
  };

  gpu = fn: {
    bus = "0x01";
    slot = "0x00";
    inherit fn;
  };
in {
  virtualisation.libvirt = {
    enable = true;
    swtpm.enable = true;
    connections."qemu:///system".domains = [
      (mkTalosVM {
        name = "talos-nas";
        uuid = "c0ff6d31-0000-4000-8000-000000000014";
        mac = "52:54:00:c0:fe:14";
        vlan = 10;
        vcpus = 6;
        memoryGiB = 40;
        disks = [
          {
            zvol = "talos-os";
            dev = "sda";
            boot = 1;
          }
          {
            zvol = "talos-pool";
            dev = "sdb";
          }
        ];
        hostdevs = [(gpu "0x0") (gpu "0x1")];
      })
    ];
  };
}
