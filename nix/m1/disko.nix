let
  mkBoot = idx: device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        esp = {
          size = "2G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot${toString idx}";
            mountOptions = ["umask=0077"];
          };
        };
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "rpool";
          };
        };
      };
    };
  };
in {
  disko.devices = {
    disk = {
      boot0 = mkBoot 0 "/dev/nvme0n1";
      boot1 = mkBoot 1 "/dev/nvme1n1";
    };

    zpool.rpool = {
      type = "zpool";
      mode = "mirror";
      options.ashift = "12";
      rootFsOptions = {
        mountpoint = "none";
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
      };
      datasets = {
        reserved = {
          type = "zfs_fs";
          options = {
            mountpoint = "none";
            refreservation = "10G";
          };
        };
        root = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
        };
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };
        var = {
          type = "zfs_fs";
          mountpoint = "/var";
          options.mountpoint = "legacy";
        };
        home = {
          type = "zfs_fs";
          mountpoint = "/home";
          options.mountpoint = "legacy";
        };
        vms = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };
        "vms/talos-os" = {
          type = "zfs_volume";
          size = "128G";
        };
        "vms/talos-pool" = {
          type = "zfs_volume";
          size = "256G";
        };
      };
    };
  };
}
