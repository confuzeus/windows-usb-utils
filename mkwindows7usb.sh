#!/bin/bash
# Script to make a bootable Windows 7 usb installation device from an 
# iso image.
# Doesn't work on UEFI systems... yet.

USAGE="./mkwindows7usb.sh <DEVICE PATH> <ISO PATH> \
  Example: ./mkwindows7usb /dev/sdb windows7.iso"

if [ -z "$1" ]; then
  echo "No Device specified"
  echo $USAGE
  exit 1
fi

if [ -z "$2" ]; then
  echo "No iso image specified"
  echo $USAGE
  exit 1
fi

USBDEVICE=$1
DISKIMAGE=$2

which parted > /dev/null
if (($? > 0)); then
  echo "Install parted first"
  exit 1
fi

which grub-install > /dev/null
if (($? > 0)); then
  echo "Install grub2 first"
  exit 1
fi

which os-prober > /dev/null
if (($? > 0)); then
  echo "Install os-prober first"
  exit 1
fi

which mkfs.fat > /dev/null
if (($? > 0)); then
  echo "Install dosfstools first"
  exit 1
fi

if [[ $(id -un) != "root" ]]; then
  echo "Run as root"
  exit 1
fi

for n in ${USBDEVICE}*; do
  umount $n 2> /dev/null
done

echo "Will setup $DISKIMAGE on $USBDEVICE"
echo "EVERYTHING ON $USBDEVICE WILL BE DESTROYED"
echo "Press Enter to continue..."
read

parted -s $USBDEVICE mklabel msdos mkpart primary 1MiB 100% set 1 boot on

USBPART=${USBDEVICE}1

mkfs.fat -F 32 $USBPART

ISODIR=$(mktemp -d)
USBDIR=$(mktemp -d)

mount $DISKIMAGE -o ro $ISODIR
mount $USBPART $USBDIR

echo "Copying files to $USBPART, this will take a long time."
cp -r $ISODIR/* $USBDIR
echo "Done copying files."
echo "Installing grub on $USBDEVICE"
grub-install --target=i386-pc --boot-directory="${USBDIR}/boot" --force \
  $USBDEVICE
echo "Writing grub.cfg to ${USBDIR}/boot/grub/grub.cfg"

GRUBPREFIX="hd"
DEVICEINDEX=${USBDEVICE:7}
GRUBDEVICE=${GRUBPREFIX}$(echo $DEVICEINDEX | tr abcdefghi 0123456789)
UUIDINFO=$(blkid $USBPART)
DEVICEUUID=$(echo $UUIDINFO | cut -d "\"" -f2)
cat << EOF > ${USBDIR}/boot/grub/grub.cfg
menuentry "Windows Installer" {
  insmod part_msdos
  insmod fat
  set root='${GRUBDEVICE},msdos1'
  search --no-floppy --fs-uuid --set=root --hint-bios=${GRUBDEVICE},msdos1 $DEVICEUUID
  ntldr /bootmgr
  boot
}
EOF

umount $USBPART
umount $ISODIR
echo "Done"
