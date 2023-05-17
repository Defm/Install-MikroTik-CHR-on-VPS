#!/bin/bash -e

echo
echo "=== MikroTik 7 Installer ==="
echo
sleep 3

# must be root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# unzip needed
if ! [ -x "$(command -v unzip)" ]; then
  echo "Error: unzip is not installed" >&2
  exit 1
fi

INIROS=$(cat << EOF
:do {
  :log warning "USERS -----------------------------------------------------------------------------"
  :local mgmtUsername "owner"; # main administrator
  :log info "CREATING MAIN ADMIN USER. new username W/O password (SET IT AFTER FIRST LOGON)- '$mgmtUsername'";
  /user remove [/user find name=$mgmtUsername];
  /user add name=$mgmtUsername group=full comment="management user" password="";
  :local mgmtUsername "reserved"; # additional admin user, it has its own script to periodically regenerate password
  :local thePass ([/certificate scep-server otp generate minutes-valid=0 as-value]->"password");
  :log info "CREATING ADDITIONAL ADMIN USER. new username - '$mgmtUsername':'$thePass'";
  /user remove [/user find name=$mgmtUsername];
  /user add name=$mgmtUsername group=full comment="additional admin" password="$thePass";
  :local mgmtUsername "automation"; # user for /system ssh-exec
  :local thePass ([/certificate scep-server otp generate minutes-valid=0 as-value]->"password");
  :log info "CREATING NEW USER AND CHANGING SCRIPTS AND SCHEDULES OWNAGE. new username - '$mgmtUsername':'$thePass'";
  /user remove [/user find name=$mgmtUsername];
  /user add name=$mgmtUsername group=full comment="outgoing SSH user" password="$thePass";
  :log warning "USERS - OK"
} on-error={ 
  :log error "USERS - ERROR"
}
EOF
)

echo "Did you boot your cloud VPS in System-Rescue mode (usually its live-CD from https://www.system-rescue.org/).." && \

# Latest Stable
CHR_VERSION=7.8 && \
STORAGE=`lsblk | grep disk | cut -d ' ' -f 1 | head -n 1` && \
ETH=`ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p'` && \
ADDRESS=`ip addr show $ETH | grep global | cut -d' ' -f 6 | head -n 1` && \
GATEWAY=`ip route list | grep default | cut -d' ' -f 3` && \

read -p "CHR version to install (${CHR_VERSION}): " CHR_VERSION && \

echo "Picking ROS from officials" && \
mkdir /tmp/ros && \
mount -t tmpfs -o size=200M tmpfs /tmp/ros/ && \
cd /tmp/ros && \
wget --no-check-certificate -qO routeros.zip https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip && \
echo "Unzipping image" && \
unzip routeros.zip && \
sleep 5 && \

echo "Disks info" && \
lsblk && \
fdisk -l && \
read -p "DISK to install to (${STORAGE}): " STORAGE

mount -o loop,offset=512 chr-$CHR_VERSION.img /mnt
echo "Here is image internals" && \
ls /mnt  && \
sleep 5 && \
echo $INIROS > /mnt/rw/autorun.scr  && \
umount /mnt  && \

echo u > /proc/sysrq-trigger && \
echo "Write the disk image to the disk using dd. This image is small and only takes a few seconds to write to the disk" && \
dd if=chr-$CHR_VERSION.img of=/dev/$STORAGE && \

echo "Verify that the disk image was written successfully with lsblk. You should see two partitions: vda1 and vda2" && \
parted /dev/$STORAGE && \
sleep 10 && \
echo "sync disk" && \
echo s > /proc/sysrq-trigger && \
echo "Sleep 5 seconds" && \
sleep 5 && \
echo "Ok, reboot" && \
echo b > /proc/sysrq-trigger
