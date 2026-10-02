# AlmaLinux 10 offline package repository

As of 2 October 2026, AlmaLinux 10.2 is the latest stable release. The `10/` tree is the current AlmaLinux 10 repository and includes updates published since 10.2. Sync it again before taking your final offline copy. When a later AlmaLinux 10 minor release becomes stable, `10/` will advance to it.

This guide is for **installing additional packages on an existing AlmaLinux 10 aarch64 or x86_64 system**. It copies only the RPMs and DNF metadata for these repositories:

| Repository | Why include it |
| --- | --- |
| BaseOS | Core packages and dependencies |
| AppStream | Most additional applications and runtimes |
| extras | AlmaLinux extra and repository release packages |
| CRB | Additional libraries and development dependencies; enabled by default on AlmaLinux 10 |

These commands omit ISOs, boot files, `kickstart/` trees, other CPU architectures, and optional specialty repositories. EPEL and other third-party repositories are separate and are not covered here.

## 1. Download on an internet-connected machine

Install `zsh` and `rsync` and choose a destination with enough free space for the RPMs. From this folder, run [sync-packages.zsh](sync-packages.zsh) with write access to the destination:

```zsh
./sync-packages.zsh --arch aarch64 /srv/offline/almalinux
# Or download x86_64 packages:
./sync-packages.zsh --arch x86_64 /srv/offline/almalinux
```

The destination argument is optional and defaults to `/srv/offline/almalinux`. You can instead pass a writable directory on removable storage. Use `sudo` if the chosen destination requires it. The download machine can use any CPU architecture; the script selects the architecture specified by `--arch`, defaulting to `aarch64`. Both architectures can share the same destination: their package trees are stored separately. The defaults can be changed in `mirror_root` and `mirror_arch` near the top of the script. Run `./sync-packages.zsh --help` to see its usage. The script stops if a download fails; transfer the mirror only after it reports completion.

If the download fails or you interrupt it, rerun the same command with the same destination and architecture. Rsync skips unchanged completed files and reuses unfinished downloads saved in `.rsync-partial` directories. Keep those directories until the sync succeeds. The script reports an error and exits with rsync's failure code if a transfer fails. It resumes when you run it again; it does not retry automatically.

The resulting tree has `10/{BaseOS,AppStream,extras,CRB}/<architecture>/os/{Packages,repodata}` and `RPM-GPG-KEY-AlmaLinux-10` at its root. Keep both `Packages/` and `repodata/` intact. Do not run `createrepo`: AlmaLinux's DNF metadata is already present.

The command downloads **all RPMs in those four repositories for the selected architecture**, including any `noarch` RPMs they publish. If you repeat it, rsync downloads changes and removes files no longer present upstream. Transfer the completed `/srv/offline/almalinux` directory to the offline environment using removable storage or a local network.

## 2. Make the mirror available to the client

For a local copy, place the tree at `/srv/offline/almalinux` on the client. For several clients, serve that directory with a local HTTP server instead; the URL paths must still end in `10/<repo>/<architecture>/os/`.

Run [configure-offline-repo.sh](configure-offline-repo.sh) on the client to create `/etc/yum.repos.d/almalinux-offline.repo`:

```bash
# Use the default mirror root: /srv/offline/almalinux
sudo ./configure-offline-repo.sh

# Or specify the local directory containing 10/ and the signing key:
sudo ./configure-offline-repo.sh /mnt/usb/almalinux

# Or use a mirror on your local network:
sudo ./configure-offline-repo.sh http://mirror.lan/almalinux
```

The script creates entries for BaseOS, AppStream, extras, and CRB, with RPM signature checking enabled. DNF expands `$basearch` to the client architecture, so the same configuration works for aarch64 and x86_64. The signing key is loaded from the chosen mirror root. Running the script again replaces the existing `almalinux-offline.repo` with the new configuration.

By default, the script runs `dnf config-manager --set-disabled '*'` before writing the offline configuration, then runs `dnf config-manager --set-enabled offline-baseos offline-appstream offline-extras offline-crb`. These commands save the enabled/disabled settings permanently. The script requires `dnf-plugins-core` on the client; install it before switching to the offline mirror. If new repository definitions are installed later, rerun the script to disable them too.

To preserve the other repositories' existing settings, pass `--keep-other-repos`. To re-enable an online repository later, use `sudo dnf config-manager --set-enabled REPO_ID`.

You can change the default in `repo_root` near the top of the Bash script. To preview the file without writing it or needing sudo:

```bash
./configure-offline-repo.sh --print /mnt/usb/almalinux
```

## 3. Verify and install

On the client, confirm `uname -m` prints the architecture you downloaded (`aarch64` or `x86_64`), then run:

```bash
sudo dnf repolist --enabled
sudo dnf makecache
sudo dnf install PACKAGE_NAME
```

After the default setup, `dnf repolist --enabled` should show only `offline-baseos`, `offline-appstream`, `offline-extras`, and `offline-crb`. Replace `PACKAGE_NAME` with the package you need. If DNF reports a missing dependency from EPEL or a specialty repository, mirror that repository separately before retrying.

## Sources

- [AlmaLinux release status](https://wiki.almalinux.org/release-notes/)
- [AlmaLinux mirror and rsync instructions](https://wiki.almalinux.org/Mirrors)
- [Rsync partial download and update options](https://download.samba.org/pub/rsync/rsync.1)
- [DNF config-manager commands](https://dnf-plugins-core.readthedocs.io/en/latest/config_manager.html)
- [AlmaLinux repository descriptions](https://wiki.almalinux.org/repos/AlmaLinux)
- [Example aarch64 AppStream directory](https://mirrors.aliyun.com/almalinux/10/AppStream/aarch64/os/)
