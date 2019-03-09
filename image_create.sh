#!/bin/bash

set -e

if (($# != 4 && $# != 5)); then
	echo "usage: <output file name> <image size> <partition type> <dos or gpt> [files]"
	exit -1
fi

dos_parttype=""
case "$3" in
	"fat16" )
		dos_parttype="0e";;
	"fat32" )
		dos_parttype="0c";;
	"ext2" )
		dos_parttype="83";;
	"ext3" )
		dos_parttype="83";;
	"ext4" )
		dos_parttype="83";;
	* )
		echo "unsupported partition type";
		exit -2;;
esac

rootpart=""
case "$4" in
	"dos" )
		rootpart="p1"
		;;
	"gpt" )
		rootpart="p2"
		;;
	* )
		echo "unexpected partition table layout";
		exit -2;;
esac

# UUID of Windows data partition. Choose something else depending on your needs.
gpt_type="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"

rm -f $1
fallocate -l $2 $1

sudo losetup /dev/loop0 $1

case "$4" in
	"dos" )
		# For DOS layouts, install GRUB after the MBR.
		cat << END_SFDISK | sudo sfdisk /dev/loop0
label: dos
16MiB + $dos_parttype
END_SFDISK
		;;
	"gpt" )
		# For GPT layouts, install GRUB to its own partition.
		cat << END_SFDISK | sudo sfdisk /dev/loop0
label: gpt
- 16MiB 21686148-6449-6E6F-744E-656564454649
- +     $gpt_type
END_SFDISK
		;;
	* )
		echo "unexpected partition table layout, how did we get here?";
		exit -2;;
esac

sudo losetup -d /dev/loop0
sudo losetup -P /dev/loop0 $1

# Format root partition according to user-chosen type.
case "$3" in
	"fat16" )
		sudo mkfs.vfat -F 16 /dev/loop0$rootpart;;
	"fat32" )
		sudo mkfs.vfat -F 32 /dev/loop0$rootpart;;
	"ext2" )
		sudo mkfs.ext2 /dev/loop0$rootpart;;
	"ext3" )
		sudo mkfs.ext3 /dev/loop0$rootpart;;
	"ext4" )
		sudo mkfs.ext4 /dev/loop0$rootpart;;
	* )
		echo "unsupported partition type, how did we get here?";
		exit -3;;
esac

mountpoint=$(mktemp -d)

echo "tmp mountpoint is $mountpoint"

sudo mount /dev/loop0$rootpart $mountpoint
sudo mkdir -p $mountpoint/boot
sudo grub-install --target=i386-pc --boot-directory=$mountpoint/boot /dev/loop0

if (($# == 5)); then
	sudo cp -avr $5/* $mountpoint/
fi

sudo umount /dev/loop0$rootpart
rmdir $mountpoint

sudo losetup -d /dev/loop0
