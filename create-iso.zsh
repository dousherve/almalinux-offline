#!/usr/bin/env zsh
# Build a mountable package-repository ISO on macOS.
setopt ERR_EXIT NO_UNSET PIPE_FAIL

script_dir=${0:A:h}
mirror_root="$script_dir/almalinux"
iso_path="$script_dir/almalinux-10-offline.iso"

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    printf 'Usage: %s [MIRROR_ROOT] [ISO_PATH]\nDefault source: %s\nDefault ISO: %s\n' "$0" "$mirror_root" "$iso_path"
    exit 0
fi
if (( $# > 2 )); then
    printf 'Usage: %s [MIRROR_ROOT] [ISO_PATH]\n' "$0" >&2
    exit 2
fi
mirror_root=${1:-$mirror_root}
iso_path=${2:-$iso_path}
mirror_root=${mirror_root:A}
iso_path=${iso_path:A}

if ! command -v hdiutil >/dev/null 2>&1; then
    printf 'Error: this script requires macOS hdiutil.\n' >&2
    exit 1
fi
if [[ ! -d "$mirror_root/10" || ! -f "$mirror_root/RPM-GPG-KEY-AlmaLinux-10" ]]; then
    printf 'Error: mirror root must contain 10/ and RPM-GPG-KEY-AlmaLinux-10.\n' >&2
    exit 1
fi
if [[ "$iso_path" == "$mirror_root/"* || -e "$iso_path" ]]; then
    printf 'Error: choose a new ISO path outside the mirror directory.\n' >&2
    exit 1
fi

cp "$script_dir/configure-offline-repo.sh" "$mirror_root/configure-offline-repo.sh"
cp "$script_dir/ISO-README.txt" "$mirror_root/README-ISO.txt"
mkdir -p "${iso_path:h}"
hdiutil makehybrid -udf -udf-volume-name ALMA_OFFLINE -o "$iso_path" "$mirror_root"
printf 'ISO created: %s\n' "$iso_path"
