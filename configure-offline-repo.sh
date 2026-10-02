#!/usr/bin/env bash
# Create DNF repository definitions for an AlmaLinux 10 offline mirror.
set -euo pipefail

repo_root=/srv/offline/almalinux
config_file=/etc/yum.repos.d/almalinux-offline.repo
print_only=0
disable_others=1

usage() {
    printf 'Usage: %s [--print] [--keep-other-repos] [REPO_PATH_OR_URL]\nDefault mirror root: %s\nWrites: %s\nDisables every other configured repository persistently by default.\n' "$0" "$repo_root" "$config_file"
}

root_supplied=0
while (( $# )); do
    case $1 in
        --help|-h) usage; exit 0 ;;
        --print) print_only=1; shift ;;
        --keep-other-repos) disable_others=0; shift ;;
        -*) printf 'Error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
        *)
            if (( root_supplied )) || [[ -z $1 ]]; then
                usage >&2
                exit 2
            fi
            repo_root=$1
            root_supplied=1
            shift
            ;;
    esac
done

if [[ $repo_root == *[[:cntrl:]]* ]]; then
    printf 'Error: the mirror root must not contain control characters.\n' >&2
    exit 2
fi

case $repo_root in
    /*)
        # Encode URL-sensitive characters in a local filesystem path.
        repo_base=${repo_root//%/%25}
        repo_base=${repo_base// /%20}
        repo_base=${repo_base//#/%23}
        repo_base=${repo_base//\?/%3F}
        repo_base=${repo_base//\$/%24}
        repo_base="file://$repo_base"
        ;;
    http://?*|https://?*|file:///*)
        if [[ $repo_root == *[[:space:]]* || $repo_root == *\?* || $repo_root == *\#* ]]; then
            printf 'Error: supply a base URL without whitespace, a query, or a fragment.\n' >&2
            exit 2
        fi
        repo_base=$repo_root
        ;;
    *)
        printf 'Error: use an absolute filesystem path or a file://, http://, or https:// URL.\n' >&2
        exit 2
        ;;
esac
repo_base=${repo_base%/}

render_config() {
    local repo repo_id
    for repo in BaseOS AppStream extras CRB; do
        case $repo in
            BaseOS) repo_id=baseos ;;
            AppStream) repo_id=appstream ;;
            extras) repo_id=extras ;;
            CRB) repo_id=crb ;;
        esac
        printf '[offline-%s]\nname=AlmaLinux 10 %s $basearch offline\nbaseurl=%s/10/%s/$basearch/os/\nenabled=1\ngpgcheck=1\ngpgkey=%s/RPM-GPG-KEY-AlmaLinux-10\n\n' \
            "$repo_id" "$repo" "$repo_base" "$repo" "$repo_base"
    done
}

if (( print_only )); then
    if (( disable_others )); then
        printf 'Preview only: applying this configuration will persistently disable all other configured repositories.\n' >&2
    fi
    render_config
    exit 0
fi
if (( EUID != 0 )); then
    printf 'Error: run this script with sudo to write %s, or use --print to preview.\n' "$config_file" >&2
    exit 1
fi

if ! command -v dnf >/dev/null 2>&1 || ! dnf config-manager --help-cmd >/dev/null 2>&1; then
    printf 'Error: dnf config-manager is required. Install dnf-plugins-core before running this script.\n' >&2
    exit 1
fi

mkdir -p /etc/yum.repos.d
config_temp=$(mktemp /etc/yum.repos.d/.almalinux-offline.XXXXXX)
trap 'rm -f -- "$config_temp"' EXIT
render_config > "$config_temp"
chmod 644 "$config_temp"

if (( disable_others )); then
    dnf config-manager --set-disabled '*'
fi
mv -f -- "$config_temp" "$config_file"
dnf config-manager --set-enabled offline-baseos offline-appstream offline-extras offline-crb
printf 'Created and enabled %s using mirror root %s\n' "$config_file" "$repo_root"
