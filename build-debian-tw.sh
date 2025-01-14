#!/bin/bash
# note: rootfs is mount point

[ "$EUID" != "0" ] && echo "please run as root" && exit 1

set -e
set -o pipefail

WorkDIR=$(cd .. & pwd)
os="debian"
os_ver="buster"
rootsize=1000

tmpdir="tmp"
output="output"
rootfs_mount_point="/mnt/${os}_rootfs"
qemu_static=$WorkDIR"/tools/qemu/qemu-aarch64-static"

cur_dir=$WorkDIR
#cur_dir=$(pwd)
DTB=armada-3720-catdrive.dtb

chroot_prepare() {
	if [ -z "$TRAVIS" ]; then
		echo "deb https://ftp.yzu.edu.tw/linux/debian/ ${os_ver} main contrib non-free" > $rootfs_mount_point/etc/apt/sources.list
		echo "nameserver 9.9.9.9" > $rootfs_mount_point/etc/resolv.conf
	else
		echo "deb http://ftp.yzu.edu.tw/linux/debian/ ${os_ver} main contrib non-free" > $rootfs_mount_point/etc/apt/sources.list
		echo "nameserver 8.8.8.8" > $rootfs_mount_point/etc/resolv.conf
	fi
}

ext_init_param() {
	:
}

chroot_post() {
	rm -f $rootfs_mount_point/etc/resolv.conf
	cat <<-EOF > $rootfs_mount_point/etc/apt/sources.list
deb https://ftp.yzu.edu.tw/linux/debian/ ${os_ver} main contrib non-free
deb https://ftp.yzu.edu.tw/linux/debian/ ${os_ver}-updates main contrib non-free
deb https://ftp.yzu.edu.tw/linux/debian-security ${os_ver}/updates main contrib non-free
deb https://ftp.yzu.edu.tw/linux/debian/ ${os_ver}-backports main contrib non-free

	EOF
}

generate_rootfs() {
	local rootfs=$1
	mirrorurl="https://ftp.yzu.edu.tw/linux/debian"
	if [ -n "$TRAVIS" ]; then
		mirrorurl="http://httpredir.debian.org/debian"
	fi
	echo "generate debian rootfs to $rootfs by debootstrap..."
	debootstrap --components=main,contrib,non-free --no-check-certificate --no-check-gpg \
		--include=apt-utils --arch=arm64 --variant=minbase --foreign --verbose $os_ver $rootfs $mirrorurl
}

add_resizemmc() {
	echo "add resize mmc script"
	cp $WorkDIR/tools/systemd/resizemmc.service $rootfs_mount_point/lib/systemd/system/
	cp $WorkDIR/tools/systemd/resizemmc.sh $rootfs_mount_point/sbin/
	mkdir -p $rootfs_mount_point/etc/systemd/system/basic.target.wants
	ln -sf /lib/systemd/system/resizemmc.service $rootfs_mount_point/etc/systemd/system/basic.target.wants/resizemmc.service
	touch $rootfs_mount_point/root/.need_resize
}

gen_new_name() {
	echo "$os-$os_ver-catdrive-`date +%Y-%m-%d`"
}

source $WorkDIR/common.sh
