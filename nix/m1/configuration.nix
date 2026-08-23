_: let
  gpuIds = "10de:1b80,10de:10f0";
in {
  nixpkgs.hostPlatform = "x86_64-linux";

  boot = {
    loader.grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      configurationLimit = 20;
      mirroredBoots = [
        {
          devices = ["nodev"];
          path = "/boot0";
          efiSysMountPoint = "/boot0";
        }
        {
          devices = ["nodev"];
          path = "/boot1";
          efiSysMountPoint = "/boot1";
        }
      ];
    };
    supportedFilesystems = ["zfs"];
    zfs.devNodes = "/dev/disk/by-id";
    zfs.forceImportRoot = false;
    kernelParams = ["intel_iommu=on" "iommu=pt" "vfio-pci.ids=${gpuIds}"];
    initrd.kernelModules = ["vfio_pci" "vfio" "vfio_iommu_type1"];
    blacklistedKernelModules = ["nouveau"];
  };

  networking = {
    hostName = "m1";
    hostId = "c0ff6d31";
    useDHCP = false;
    vlans = {
      cluster = {
        id = 10;
        interface = "enp2s0f0";
      };
      mgmt = {
        id = 99;
        interface = "enp2s0f1";
      };
      home = {
        id = 100;
        interface = "enp0s31f6";
      };
    };
    bridges.br0.interfaces = ["cluster"];
    interfaces = {
      br0.useDHCP = true;
      mgmt.useDHCP = true;
      home.useDHCP = true;
    };
    firewall.interfaces = {
      br0.allowedTCPPorts = [2049 9100 9633];
      mgmt.allowedTCPPorts = [22 2049 9100 9633];
      home.allowedTCPPorts = [22 2049];
    };
    dhcpcd.extraConfig = ''
      interface br0
      nogateway
      interface home
      nogateway
    '';
  };

  hardware.cpu.intel.updateMicrocode = true;

  time.timeZone = "America/Chicago";

  zramSwap = {
    enable = true;
    memoryPercent = 25;
  };

  services = {
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    zfs.autoScrub = {
      enable = true;
      interval = "monthly";
    };
    zfs.trim.enable = true;
  };

  users.users = {
    liana = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = ["wheel" "libvirtd" "media" "documents"];
      openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILeTWOmGCJ4CGx9RQPoCwXb81sZbN3gbk9iaGliu47aM liana@fw-2026"];
    };
    maxine = {
      isNormalUser = true;
      uid = 1001;
      extraGroups = ["media" "documents"];
      openssh.authorizedKeys.keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDIH1DudmoKZzEukU5A0ZTc5lmFl2ZARgXwejLG0oLkIKLF8I3pMVtauKDkjd5lA5zHLZ0dsyl0GjSVNP0JMfV0su2Db8DGajjfFSHuaUc70WoMCAQfspsOlnyrjNsKaB4CQJVVVaIHgJPJglQ1yQm7uJSLawyePZ3Nh3A+sCzLnlsT6W3hLJvQcEEznYiLUrAfrs5H9PIGUe7x301BijQLtv3ZqocoeiBO2v//iCcZ07PrpUZE8boBT8v5tj9vwM0TrtQI3TKlsa2F+9BXq7pgHHLdS+LmAi5R3aLDGf5y73SUaXPCQxDmm0m2HRF2VnJF9H6yTApswBxLqvQ/KMw+6OfHJ3bRbXnhnC/n2K20P3xi083bwexbEHRG4Gd4U1qbW/2jk002R6V2AE351wsEaBfmPLM+70sgIWTWtx8FbJOYlRBhpVooaXO7aHvuyGDySPcYFAanj0NRj6bBuLa1Uou/yEXQaUb6tov/ADDWmZLF/6Wnes8hRf0ws+7XBj0= maxine@frame"];
    };
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];

  system.stateVersion = "26.05";
}
