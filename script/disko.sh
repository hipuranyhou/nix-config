#!/usr/bin/env bash

# https://github.com/KornelJahn/nixos-disko-zfs-test/blob/main/scripts/my-provision
# https://github.com/nix-community/impermanence/blob/master/create-directories.bash

set -o nounset           # Fail on use of unset variable.
set -o errexit           # Exit on command failure.
set -o pipefail          # Exit on failure of any command in a pipeline.
set -o errtrace          # Trap errors in functions and subshells.
set -o noglob            # Disable filename expansion (globbing).
shopt -s inherit_errexit # Inherit the errexit option status in subshells.

_arg0=$(basename "$0")
_usage="
Usage:
  $_arg0 [OPTIONS] <fs> <disk>

Options:
  -h         Show script help and quit.       [default=false]
  -n         Perform a dry run (no changes).  [default=false]
  -p PATH    Path to encryption password.     [default=PROMPT]
  -r SIZE    Reservation space size.          [default=32G]
  -s SIZE    Swap partition size for sgdisk.  [default=8G]
  -u         Disable root encryption.         [default=false]

Positionals:
  <fs>    Type of filesystem to use. Only ZFS is supported now.
  <disk>  Name of physical drive node in /dev/disk/by-id/.

Example:
  $_arg0 -r 24G -s 16G zfs nvme-Micron_XXX_XXX
"

err() {
	if [ $# -ge 2 ]; then
		msg="ERROR: $2"
	else
		msg="$_usage"
	fi
	echo "$msg" >&2
	exit "${1:?}"
}

_args=()
while getopts ':hnp:r:s:u' opt; do
	case $opt in
	h) err 0 ;;
	n) _args+=("--dry-run") ;;
	p) _args+=("--arg encPassPath $OPTARG") ;;
	r) _args+=("--arg reserveSize \"$OPTARG\"") ;;
	s) _args+=("--arg swapSize \"$OPTARG\"") ;;
	u) _args+=("--arg encEnable false") ;;
	*) err 1 ;;
	esac
done
shift $((OPTIND - 1))

[ $# -ge 2 ] ||
	err 2 "missing args: <fs> <disk>"

_fs="$1"
[ -f "disko/$_fs.nix" ] ||
	err 3 "unknown <fs>"

_disk="$2"
[ -e "/dev/disk/by-id/$_disk" ] ||
	err 4 "<disk> does not exist"

set -x
# shellcheck disable=SC2068
sudo nix \
	--experimental-features "nix-command flakes" \
	run github:nix-community/disko -- \
	${_args[@]} --arg diskId "\"$_disk\"" \
	--mode disko "disko/$_fs.nix"
