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

echo "Preparation ..."
apt install unzip -y

# Latest Stable
CHR_VERSION=7.8

wget -qO routeros.zip https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip && \
unzip routeros.zip && \
rm -rf routeros.zip

STORAGE=`lsblk | grep disk | cut -d ' ' -f 1 | head -n 1` && \
ETH=`ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p'` && \
ADDRESS=`ip addr show $ETH | grep global | cut -d' ' -f 6 | head -n 1` && \
GATEWAY=`ip route list | grep default | cut -d' ' -f 3` && \

#mount -o loop,offset=512 chr-$CHR_VERSION.img /mnt
#ls /mnt
#echo "" > /mnt/rw/autorun.scr
#umount /mnt

echo u > /proc/sysrq-trigger && \
dd if=chr-$CHR_VERSION.img of=/dev/$STORAGE && \
echo "sync disk" && \
echo s > /proc/sysrq-trigger && \
echo "Sleep 5 seconds" && \
sleep 5 && \
echo "Ok, reboot" && \
echo b > /proc/sysrq-trigger
