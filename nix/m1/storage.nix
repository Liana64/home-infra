{
  config,
  lib,
  ...
}: let
  net = {
    cluster = [
      "172.16.4.11"
      "172.16.4.12"
      "172.16.4.13"
      "172.16.4.14"
    ];
    home = ["172.16.100.0/24"];
    admin = ["172.16.99.0/24"];
  };

  ids = {
    media = 1000;
    documents = 1100;
    backup = 1200;
  };

  base = "rw,no_subtree_check,crossmnt";
  access = {
    owned = id: "${base},root_squash,anonuid=${toString id},anongid=${toString id}";
    user = _: "${base},root_squash";
    anon = id: "${base},all_squash,anonuid=${toString id},anongid=${toString id}";
  };

  lan = level: {
    home = level;
    admin = level;
  };

  people = lib.filterAttrs (_: u: u.isNormalUser && u.uid != null) config.users.users;

  homes = lib.mapAttrs' (name: u:
    lib.nameValuePair "tank/home/${name}" {
      id = u.uid;
      gid = config.users.groups.${u.group}.gid;
      mode = "0700";
      props.quota = "1T";
      grants = lan access.user;
    })
  people;

  datasets =
    {
      "tank/media" = {
        id = ids.media;
        mode = "2775";
        props = {
          recordsize = "1M";
          quota = "14.5T";
        };
        grants = {cluster = access.owned;} // lan access.user;
      };
      "tank/media/downloads" = {
        id = ids.media;
        mode = "2775";
        props = {
          recordsize = "128K"; # torrent fragmentation
          quota = "2T";
        };
      };
      "tank/home" = {
        id = 0;
        mode = "0755";
        props.quota = "5T";
        grants = lan access.user;
      };
      "tank/home/photos" = {
        id = ids.documents;
        mode = "2770";
        grants = {cluster = access.anon;} // lan access.anon;
      };
      "tank/home/shared" = {
        id = ids.documents;
        mode = "2770";
        grants = lan access.anon;
      };
      "tank/home/shared/landfill" = {
        id = ids.documents;
        mode = "2770";
      };
      "tank/backups" = {
        id = 0;
        mode = "0700";
        props.quota = "5T";
      };
      "tank/backups/volsync" = {
        id = ids.media;
        mode = "0770";
        grants.cluster = access.anon;
      };
      "tank/backups/framework" = {
        id = ids.backup;
        mode = "0700";
        allow = "backup receive,create,mount,hold";
      };
    }
    // homes;

  exported = lib.filterAttrs (_: s: s ? grants) datasets;

  exportLine = path: s:
    "/${path} "
    + lib.concatStringsSep " " (lib.flatten (
      lib.mapAttrsToList (group: level: map (c: "${c}(${level s.id})") net.${group}) s.grants
    ));

  ensure = path: s:
    ''
      zfs list -H ${path} >/dev/null 2>&1 || zfs create -p ${path}
    ''
    + lib.concatStrings (lib.mapAttrsToList (k: v: "zfs set ${k}=${v} ${path}\n") (s.props or {}))
    + lib.optionalString (s ? allow) "zfs allow ${s.allow} ${path}\n"
    + ''
      chown ${toString s.id}:${toString (s.gid or s.id)} /${path}
      chmod ${s.mode} /${path}
    '';
in {
  boot = {
    zfs.extraPools = ["tank"];
    kernelParams = ["zfs.zfs_arc_max=12884901888"];
  };

  users = {
    groups = {
      media.gid = ids.media;
      documents.gid = ids.documents;
      backup.gid = ids.backup;
    };
    users.backup = {
      uid = ids.backup;
      group = "backup";
      isSystemUser = true;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = [];
    };
  };

  services = {
    nfs.server = {
      enable = true;
      exports = lib.concatStringsSep "\n" (lib.mapAttrsToList exportLine exported);
    };
    nfs.settings.nfsd = {
      vers3 = false;
      udp = false;
      threads = 16;
    };

    sanoid = {
      enable = true;
      templates = {
        tank = {
          hourly = 48;
          daily = 30;
          monthly = 6;
          autosnap = true;
          autoprune = true;
        };
        backup = {
          hourly = 48;
          daily = 30;
          monthly = 6;
          autosnap = false;
          autoprune = true;
        };
      };
      datasets = {
        tank = {
          useTemplate = ["tank"];
          recursive = true;
        };
        "tank/media/downloads" = {
          autosnap = false;
          autoprune = false;
        };
        "tank/home/shared/landfill" = {
          autosnap = false;
          autoprune = false;
        };
        "tank/backups" = {
          useTemplate = ["backup"];
          recursive = true;
        };
      };
    };

    smartd.enable = true;

    prometheus.exporters = {
      node.enable = true;
      smartctl.enable = true;
    };
  };

  systemd.services.zfs-datasets = {
    wantedBy = ["multi-user.target"];
    requiredBy = ["nfs-server.service"];
    after = ["zfs-mount.service"];
    before = ["nfs-server.service"];
    path = [config.boot.zfs.package];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatStrings (lib.mapAttrsToList ensure datasets);
  };
}
