#!/bin/bash

echo "Hello. This is setup."

# Setting some environment variables
echo "OF_VERSION=${OF_VERSION}" >> /etc/environment

# Replace /boot/cmdline.txt since it contains root device mapping to a PARTUUID that 
# changed during parted resize. We try to disable the autoresize here as well.
echo "Replace /boot/cmdline.txt"
echo "dwc_otg.lpm_enable=0 console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet" > "${mount}/boot/cmdline.txt"
cat "${mount}/boot/cmdline.txt"

# Replace /etc/fstab since the non existing PARTUUID has to be changed here as well.
echo "Replace /etc/fstab"
echo "proc            /proc           proc    defaults          0       0" > "${mount}/etc/fstab"
echo "/dev/mmcblk0p1  /boot           vfat    defaults          0       2" >> "${mount}/etc/fstab"
echo "/dev/mmcblk0p2  /               ext4    defaults,noatime  0       1" >> "${mount}/etc/fstab"
cat "${mount}/etc/fstab"

# Give me number of cores avail!
cores=$(nproc)
echo "Number of processor cores: ${cores}"

# Debug disk space.
echo "Checking disk space."
df -h

# Disable automatic filesystem expansion on boot
#rm /usr/lib/raspi-config/init_resize.sh
rm /etc/init.d/resize2fs_once
rm /etc/rc3.d/S01resize2fs_once

echo "Setting hostname."
echo "openFrameworks" > /etc/hostname
cat /etc/hostname

echo "Setting gpu_mem."
if grep -q "gpu_mem" /boot/config.txt
then
    sed -i "s/gpu_mem.*//" /boot/config.txt
fi

echo "gpu_mem_256=${GPU_MEM_256}" >> /boot/config.txt
echo "gpu_mem_512=${GPU_MEM_512}" >> /boot/config.txt
echo "gpu_mem_1024=${GPU_MEM_1024}" >> /boot/config.txt
cat /boot/config.txt | grep "gpu_mem"

echo "Installing packages."
apt-get -y update
apt-get -y install git

echo "Downloading openFrameworks."
cd /home/pi
wget --no-check-certificate --progress=bar:force "${OF_URL}"
mkdir openFrameworks
echo "Unarchiving ${OF_FILE}"
tar xfz "${OF_FILE}" -C openFrameworks --strip-components 1
cd /home/pi/openFrameworks/scripts/linux/debian

# This is needed to install everything automatically without interaction
sed -i "s/apt-get/apt-get -y/g" install_dependencies.sh

./install_dependencies.sh
#make -j$(nproc) Release -C /home/pi/openFrameworks/libs/openFrameworksCompiled/project

echo "Congratulations! openFrameworks $OF_VERSION is ready to compile now."
