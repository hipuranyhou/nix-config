{ diskId, swapSize ? "8G", reserveSize ? "32G", encEnable ? true
, encPassPath ? null, ... }: {
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = "/dev/disk/by-id/" + diskId;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "2G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            swap = {
              size = swapSize;
              type = "8200";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
            nixos = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "rpool";
              };
            };
          }; # partitions
        }; # content
      }; # disk0
    }; # disk
    zpool = {
      rpool = {
        type = "zpool";
        options = {
          ashift = "12";
          autotrim = "off";
        };
        rootFsOptions = {
          canmount = "off";
          mountpoint = "none";
          acltype = "posixacl";
          xattr = "sa";
          dnodesize = "auto";
          normalization = "formD";
          relatime = "on";
          compression = "zstd";
          "com.sun:auto-snapshot" = "false";
        } // (if encEnable then {
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = (if builtins.isPath encPassPath then
            "file://" + encPassPath
          else
            "prompt");
          pbkdf2iters = "1000000";
        } else
          { });
        datasets = {
          "ROOT" = {
            type = "zfs_fs";
            mountpoint = "/";
            options.mountpoint = "legacy";
            postCreateHook = ''
              zfs snapshot rpool/ROOT@blank
            '';
          };
          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options.mountpoint = "legacy";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              atime = "off";
              mountpoint = "legacy";
            };
          };
          "persist" = {
            type = "zfs_fs";
            mountpoint = "/persist";
            options.mountpoint = "legacy";
          };
          "reserve" = {
            type = "zfs_fs";
            options = {
              canmount = "off";
              reservation = reserveSize;
            };
          };
        }; # datasets
      } // (if builtins.isPath encPassPath then {
        postCreateHook = ''
          zfs set keylocation="prompt" rpool
        '';
      } else
        { }); # rpool
    }; # zpool
  }; # disko.devices
}
