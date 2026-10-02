#!/usr/bin/env zsh
# Mirror AlmaLinux 10 package repositories for the selected architecture.
setopt ERR_EXIT NO_UNSET PIPE_FAIL

mirror_root=/srv/offline/almalinux
mirror_arch=aarch64
script_name=$0

usage() {
    printf 'Usage: %s [--arch aarch64|x86_64] [DESTINATION]\nDefault destination: %s\nDefault architecture: %s\n' "$script_name" "$mirror_root" "$mirror_arch"
}

destination_set=0
while (( $# > 0 )); do
    case $1 in
        --help|-h) usage; exit 0 ;;
        --arch)
            if (( $# < 2 )); then
                printf 'Error: --arch requires aarch64 or x86_64.\n' >&2
                exit 2
            fi
            mirror_arch=$2
            shift 2
            ;;
        -*) printf 'Error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)
            if (( destination_set )) || [[ -z $1 ]]; then
                usage >&2
                exit 2
            fi
            mirror_root=$1
            destination_set=1
            shift
            ;;
    esac
done

case $mirror_arch in
    aarch64|x86_64) ;;
    *) printf 'Error: unsupported architecture: %s (choose aarch64 or x86_64).\n' "$mirror_arch" >&2; exit 2 ;;
esac

if ! command -v rsync >/dev/null 2>&1; then
    printf 'Error: install rsync before running this script.\n' >&2
    exit 1
fi

mirror_source=rsync://rsync.repo.almalinux.org/almalinux
mkdir -p "$mirror_root/10"

# Retain unfinished files and protect them from repository deletion rules.
run_rsync() {
    local sync_status=0
    rsync --partial-dir=.rsync-partial --progress --exclude='.rsync-partial/' "$@" || sync_status=$?
    if (( sync_status != 0 )); then
        printf 'Download stopped (rsync exit %s). Saved files remain in %s.\n' "$sync_status" "$mirror_root" >&2
        printf 'Rerun this script with the same destination and architecture (%s) to resume.\n' "$mirror_arch" >&2
        exit "$sync_status"
    fi
}

for repo in BaseOS AppStream extras CRB; do
    dest="$mirror_root/10/$repo/$mirror_arch/os"
    mkdir -p "$dest"
    printf 'Syncing %s for %s...\n' "$repo" "$mirror_arch"
    run_rsync -rlptvSH \
        --include='/Packages/***' \
        --include='/repodata/***' \
        --exclude='*' \
        --delete-delay --delay-updates \
        "$mirror_source/10/$repo/$mirror_arch/os/" \
        "$dest/"
done

run_rsync -rlptv \
    "$mirror_source/RPM-GPG-KEY-AlmaLinux-10" \
    "$mirror_root/"

printf 'Mirror complete: %s\n' "$mirror_root"
