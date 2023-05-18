#!/bin/bash -e

# must be root
if [[ $EUID -ne 0 ]]; then
   echo -e "\x1b[31mThis script must be run as root...\x1b[0m"
   exit 1
fi

# unzip needed
if ! [ -x "$(command -v unzip)" ]; then
  echo -e "\x1b[31mError: unzip is not installed...\x1b[0m"
  exit 1
fi

echo
echo "CLOUD Mikrotik CHR installer"
echo
sleep 3


echo "Did you boot your cloud VPS in System-Rescue mode (usually its live-CD from https://www.system-rescue.org/).." && \
echo "If you would like SSH (not VNC) - stop Iptables first with: systemctl stop iptables" && \
echo "And set root password with: passwd" && \

# Latest Stable
CHR_VERSION=7.8 && \
STORAGE=`lsblk | grep disk | cut -d ' ' -f 1 | head -n 1` && \
ETH=`ip route show default | sed -n 's/.* dev \([^\ ]*\) .*/\1/p'` && \
ADDRESS=`ip addr show $ETH | grep global | cut -d' ' -f 6 | head -n 1` && \
GATEWAY=`ip route list | grep default | cut -d' ' -f 3` && \

echo "Address ${ADDRESS}" && \
echo "Gateway ${GATEWAY}" && \
echo "Target disk ${STORAGE}" && \

read -p "CHR version to install (${CHR_VERSION}): " CHR_VERSION && \
CHR_URL="https://download.mikrotik.com/routeros/${CHR_VERSION}/chr-${CHR_VERSION}.img.zip" && \
#CHR_URL="https://github.com/Defm/iCHR/releases/download/v7.8-noff/chr-7.8.img.zip" && \

echo "Picking ROS from officials" && \
mkdir -p /tmp/ros && \
mount -t tmpfs -o size=200M tmpfs /tmp/ros/ && \
cd /tmp/ros && \
echo "Downloading" && \
wget --no-check-certificate -qO chr.img.zip "${CHR_URL}" && \
sleep 2 && \
echo "Unzipping" && \
unzip chr.img.zip && \
sleep 5 && \

echo "Disks info" && \
lsblk && \
fdisk -l && \
read -p "DISK to install to (${STORAGE}): " STORAGE

echo "Attach image as loop device" && \
LOOP_DEV=`losetup --show -Pf chr-${CHR_VERSION}.img`  && \
echo "Mount ROSv7 boot partition fot initial script deploy" && \
# boot partition for ROS v7 locates here, yep p2 is not an occasion
mkdir -p /mnt/ros && \
mount ${LOOP_DEV}p2 /mnt/ros  && \
echo "Here is image internals" && \
ls /mnt/ros  && \
sleep 5 && \
cat > '/mnt/ros/rw/autorun.scr' <<EOF
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

echo "We're almost ready" && \
dmesg -n 1 && \
echo "Unmounting /mnt" && \
#umount --detach-loop /mnt/ros && \
echo "Detaching ROSv7 boot partition, etc" && \
#losetup -d ${LOOP_DEV} && \ 
echo u > /proc/sysrq-trigger && \
echo "Well, start DD" && \
dd if=chr-${CHR_VERSION}.img bs=32768 of=/dev/${STORAGE} conv=fsync && \
echo -e "\x1b[31mGOODBYE...\x1b[0m" && \
sleep 1 && \
echo "When you're ready to restart type: echo b > /proc/sysrq-trigger"
