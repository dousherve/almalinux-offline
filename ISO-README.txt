AlmaLinux 10 offline package repository

Attach this ISO to the AlmaLinux VM's virtual CD/DVD drive.
In the VM, run:

    sudo mkdir -p /mnt/almalinux
    sudo mount -t udf -o ro /dev/sr0 /mnt/almalinux
    sudo bash /mnt/almalinux/configure-offline-repo.sh /mnt/almalinux
    sudo dnf repolist --enabled
    sudo dnf makecache
    sudo dnf install PACKAGE_NAME

Use the actual virtual optical device if it differs from /dev/sr0.
The setup script requires dnf-plugins-core. It persistently disables the
other DNF repositories and enables the four offline AlmaLinux repositories.
The ISO must be mounted at /mnt/almalinux whenever DNF uses those repositories.
Mount it again after rebooting the VM.

Contains BaseOS, AppStream, extras, CRB, and the AlmaLinux 10 signing key.
DNF chooses the VM's architecture via $basearch; that architecture must have
been downloaded before creating the ISO. EPEL is not included.
