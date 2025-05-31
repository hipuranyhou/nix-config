# nix-config

Configuration of all my systems running NixOS.


## 1. SSH

First, setup a password for the `nixos` user using `passwd`. Now you can use SSH.


## 2. Partitioning

Partitioning is done using `disko`. A helper script in `script/disko.sh` should
be used for this. For now, the configurations in `disko/` only support ZFS.

Encryption is enabled by default. It can be provided a password file for
an unattended installation or disabled. Swap size is set to 8 GiB by default (I
never use hibernation) but can be changed. There is a 32 GiB reservation dataset
by default (for SSDs).

Only disk nodes through `/dev/disk/by-id/` are supported. Example usage:

```Shell
./script/disko.sh -- zfs 'ata-VBOX_HARDDISK_VB6ed77170-cf2aa59c'
```
