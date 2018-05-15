#!/bin/bash

# Setup script error handling see https://disconnected.systems/blog/another-bash-strict-mode for details
set -xuo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR
IFS=$'\n\t'

# Ensure we are root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Image creation constants.
# See .travis.yml for environment variables.
MOUNT="mnt"
SCRIPT="image-compile-script.sh"

# Unmount drives and general cleanup on exit, the trap ensures this will always
# run execpt in the most extream cases.
cleanup() {
    [[ -f "${MOUNT}/tmp/${SCRIPT}" ]] && rm "${MOUNT}/tmp/${SCRIPT}"
    if [[ -d "${MOUNT}" ]]; then
        umount "${MOUNT}/dev/pts" || true
        umount "${MOUNT}/dev" || true
        umount "${MOUNT}/proc" || true
        umount "${MOUNT}/sys" || true
        umount "${MOUNT}/boot" || true
        umount "${MOUNT}" || true
        rmdir "${MOUNT}" || true
    fi
    [ -n "${loopdev:-}" ] && losetup --detach "${loopdev}" || true
}
trap cleanup EXIT

# Clean the existing image files
(ls *.img >> /dev/null 2>&1 && rm *.img) || echo "no .img files to remove"

# Unzip image file
unzip -u "${IMAGE}.zip"

# Configure loopback device to expand partition 2
loopdev=$(losetup --find --show "${IMAGE}")
echo "Created loopback device ${loopdev}"

# Mount the image
echo "Mounting filesystem."

bootdev="${loopdev}p1"
rootdev="${loopdev}p2"
partprobe "${loopdev}"

[ ! -d "${MOUNT}" ] && mkdir "${MOUNT}"
mount "${rootdev}" "${MOUNT}"
[ ! -d "${MOUNT}/boot" ] && mkdir "${MOUNT}/boot"
mount "${bootdev}" "${MOUNT}/boot"

# Copy our installation script and other artifacts.
install -Dm755 "${SCRIPT}" "${MOUNT}/tmp/${SCRIPT}"

# Prep the chroot.
mount --bind /proc "${MOUNT}/proc"
mount --bind /sys "${MOUNT}/sys"
mount --bind /dev "${MOUNT}/dev"
mount --bind /dev/pts "${MOUNT}/dev/pts"

cp /etc/resolv.conf "${MOUNT}/etc/resolv.conf"
cp /usr/bin/qemu-arm-static "${MOUNT}/usr/bin"
cp "${MOUNT}/etc/ld.so.preload" "${MOUNT}/etc/_ld.so.preload"
echo "" > "${MOUNT}/etc/ld.so.preload"

# Run the installation script as if we would be inside the Raspberry Pi.
chroot "${MOUNT}" "/tmp/${SCRIPT}"

# Put back the old ld.so.preload script.
mv "${MOUNT}/etc/_ld.so.preload" "${MOUNT}/etc/ld.so.preload"
