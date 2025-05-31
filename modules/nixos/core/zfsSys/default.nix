{ config, lib, ... }:

# Based on:
# https://github.com/notthebee/nix-config/blob/main/modules/zfs-root/default.nix
# https://github.com/KornelJahn/nixos-disko-zfs-test/blob/main/hosts/testhost.nix
# https://github.com/DerickEddington/nixos-config/blob/github/zfs/default.nix

let
  cfg = config.custom.zfsSys;
  inherit (builtins) hashString substring;
  inherit (lib)
    mapAttrsToList mkAfter mkDefault mkEnableOption mkForce mkIf mkMerge
    mkOption strings types;
in {

  # TODO: Default persist files?
  # TODO: diff_root script for finding permanent files.

  options.custom.zfsSys = {
    # Required for function
    enable = mkEnableOption "ZFS system setup";
    diskId = mkOption {
      description = "Set identifier of the ZFS disk";
      type = types.str;
      example = "ata-VBOX_VB6ed77170";
    };
    # TODO: Support at least mirrored drives for servers.
    # Optional
    immutable = mkOption {
      description = "Enable rollback of ZFS root during boot";
      type = types.bool;
      default = true;
      example = false;
    };
    devNodes = mkOption {
      description = "Set location for device and ZFS pools discovery";
      type = types.path;
      default = "/dev/disk/by-id/";
      example = "/dev/disk/by-uuid/";
      apply = x:
        assert (strings.hasSuffix "/" x
          || abort "devNodes '${x}' must have trailing slash");
        x;
      readOnly = true;
    };
    partitionScheme = mkOption {
      description = "Set ZFS disk partition identifiers";
      type = types.attrsOf types.str;
      default = {
        esp = "-part1";
        swap = "-part2";
        root = "-part3";
      };
      example = {
        esp = "-part3";
        swap = "-part2";
      };
    };
    espId = mkOption {
      description = "Set full path to ZFS disk ESP partition";
      type = types.str;
      default = "${cfg.devNodes}${cfg.diskId}${cfg.partitionScheme.esp}";
      example = "/dev/sda1";
    };
    swapIds = mkOption {
      description = "Set list of device paths of swap";
      type = types.listOf types.str;
      default = [ "${cfg.devNodes}${cfg.diskId}${cfg.partitionScheme.swap}" ];
      example = [ "/dev/sdb" "/dev/sdc2" ];
    };
    datasets = mkOption {
      description = "Set mountpoints of ZFS datasets";
      type = types.attrsOf types.str;
      default = {
        "rpool/ROOT" = "/";
        "rpool/nix" = "/nix";
        "rpool/home" = "/home";
        "rpool/persist" = "/persist";
      };
      example = {
        "rpool/local/x" = "/x";
        "rpool/local/y" = "/y";
      };
    };
  };

  config = mkIf (cfg.enable) (mkMerge [
    # boot
    {
      boot = {
        kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;
        loader = {
          efi.canTouchEfiVariables = mkDefault true;
          systemd-boot = {
            enable = mkDefault true;
            configurationLimit = 100;
            editor = false;
          };
        };
        supportedFilesystems = {
          btrfs = mkForce false;
          zfs = true;
        };
        tmp.cleanOnBoot = true;
        zfs = {
          allowHibernation = false;
          devNodes = cfg.devNodes;
          forceImportRoot = mkDefault false;
        };
      };
      systemd.enableEmergencyMode = false;
    }
    (mkIf cfg.immutable {
      boot.initrd.postDeviceCommands = mkAfter ''
        zfs rollback -r rpool/ROOT@blank
      '';
    })
    # filesystems
    {
      fileSystems = mkMerge ([{
        "/boot" = {
          device = "${cfg.espId}";
          fsType = "vfat";
          options = [
            "X-mount.mkdir"
            "noatime"
            "nofail"
            "umask=0077"
            "x-systemd.automount"
            "x-systemd.idle-timeout=1min"
          ];
        };
      }]) ++ mapAttrsToList (dataset: mountpoint: {
        "${mountpoint}" = {
          device = "${dataset}";
          fsType = "zfs";
          options = [ "X-mount.mkdir" ];
          neededForBoot = true;
        };
      }) cfg.datasets;
      swapDevices = map (swapId: {
        device = "${swapId}";
        discardPolicy = "both";
        randomEncryption = {
          enable = true;
          allowDiscards = true;
        };
      }) cfg.swapIds;
    }
    # networking
    {
      # TODO: Add support for SSH unlock for servers.
      networking.hostId = mkDefault substring 0 8
        (hashString "sha256" config.networking.hostName);
      time.timeZone = mkDefault "Etc/UTC";
    }
    # services
    {
      services = {
        sanoid = {
          enable = true;
          templates.default = {
            autoprune = true;
            autosnap = true;
            hourly = 48;
            daily = 31;
            monthly = 3;
            yearly = 0;
          };
          datasets = mkDefault {
            "rpool/home".useTemplate = [ "default" ];
            "rpool/persist".useTemplate = [ "default" ];
          };
        };
        # TODO: Enable syncoid.
        zfs = {
          autoScrub.enable = true;
          autoSnapshot.enable = false;
          trim.enable = true;
        };
      };
      systemd.services.zfs-mount.enable = false;
    }
    # TODO: Enable ZED notifications.
  ]);

}
