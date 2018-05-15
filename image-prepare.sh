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
SCRIPT="image-prepare-script.sh"

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

# Download raspbian arm only if we have not already done so
[ ! -f "${RPI_ZIP}" ] && wget --progress=bar:force "${RPI_URL}"

# Clean the existing image files
(ls *.img >> /dev/null 2>&1 && rm *.img) || echo "no .img files to remove"

# Unzip Raspbian
# -u  update files, create if necessary
unzip -u "${RPI_ZIP}"

mv "$(ls *.img | head -n 1)" "${IMAGE}"

# Add 1G to the image size
dd if=/dev/zero bs=1M count=1024 >> "${IMAGE}"

# Configure loopback device to expand partition 2
loopdev=$(losetup --find --show "${IMAGE}")
echo "Created loopback device ${loopdev}"

parted --script "${loopdev}" print
parted --script "${loopdev}" resizepart 2 100%
parted --script "${loopdev}" print

e2fsck -f -y "${loopdev}p2"
resize2fs "${loopdev}p2"

# Mount the image
echo "Mounting filesystem."

bootdev=$(ls "${loopdev}"*1)
rootdev=$(ls "${loopdev}"*2)
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

# Forward constants that we will need in the script.
chroot "${MOUNT}" /bin/bash -c 'OF_VERSION="${OF_VERSION}"'
chroot "${MOUNT}" /bin/bash -c 'OF_FILE="${OF_FILE}"'
chroot "${MOUNT}" /bin/bash -c 'OF_URL="${OF_URL}"'
chroot "${MOUNT}" /bin/bash -c 'GPU_MEM_256="${GPU_MEM_256}"'
chroot "${MOUNT}" /bin/bash -c 'GPU_MEM_512="${GPU_MEM_512}"'
chroot "${MOUNT}" /bin/bash -c 'GPU_MEM_1024="${GPU_MEM_1024}"'

# Run the installation script as if we would be inside the Raspberry Pi.
chroot "${MOUNT}" "/tmp/${SCRIPT}"

# Put back the old ld.so.preload script.
mv "${MOUNT}/etc/_ld.so.preload" "${MOUNT}/etc/ld.so.preload"
