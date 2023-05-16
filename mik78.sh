#!/bin/bash -e

echo
echo "=== MikroTik 7 Installer ==="
echo
sleep 3

# Must be root !
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Did you boot your cloud VPS in System-Resque mode??.." && \

# Latest Stable
CHR_VERSION=7.8

echo "We need unzip utility before. Installing it.." && \
apt install unzip -y && \

read -p 'CHR version to install ($CHR_VERSION): ' CHR_VERSION && \

echo "Picking ROS from officials" && \
wget --no-check-certificate -qO routeros.zip https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip && \
echo "Unzipping image" && \
unzip routeros.zip && \
echo "Clearing old files" && \
rm -rf routeros.zip

STORAGE=`lsblk | grep disk | cut -d ' ' -f 1 | head -n 1` && \
ETH=`ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p'` && \
ADDRESS=`ip addr show $ETH | grep global | cut -d' ' -f 6 | head -n 1` && \
GATEWAY=`ip route list | grep default | cut -d' ' -f 3` && \

read -p 'DISK to install to ($STORAGE): ' STORAGE

#mount -o loop,offset=512 chr-$CHR_VERSION.img /mnt
#ls /mnt
#echo "" > /mnt/rw/autorun.scr
#umount /mnt

echo u > /proc/sysrq-trigger && \
echo "Write the disk image to the disk using dd. This image is small and only takes a few seconds to write to the disk" && \
dd if=chr-$CHR_VERSION.img of=/dev/$STORAGE && \

echo "Verify that the disk image was written successfully with lsblk. You should see two partitions: vda1 and vda2" && \
lsblk && \
sleep 5 && \
echo "sync disk" && \
echo s > /proc/sysrq-trigger && \
echo "Sleep 5 seconds" && \
sleep 5 && \
echo "Ok, reboot" && \
echo b > /proc/sysrq-trigger
