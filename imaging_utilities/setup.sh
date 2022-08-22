#!/bin/bash

# This script performs a “secure” erase of the internal MacBook drive, then installs OS_RELEASE

readonly DISK="/dev/disk0";
readonly FS_FORMAT="APFS";
readonly PARTITION_NAME="macOS";
readonly OS_RELEASE="Monterey";
readonly MNT_POINT="/Volumes/macOS";
readonly DRIVE_LABEL="BIGSUR-6-15";

readonly opt_ERASE=false;
readonly opt_PARTITION=true;

echo "This script is $0"
readonly HERE=$(perl -MFile::Basename=dirname -s -e 'print(dirname($script_location))' -- -script_location=$0)
echo "HERE is ${HERE}"

erase_internal_disk() {
${opt_ERASE} || return;
  echo -e "\n[+] Starting secureErase on ${DISK} (CTRL-C to stop)";
  sleep 5;
  diskutil secureErase 1 ${DISK};
}

partition_internal_disk() {
${opt_PARTITION} || return;
  echo -e "\n[+] Partition Disk: ${DISK}; Format: ${FS_FORMAT}; Label:${PARTITION_NAME} (CTRL-C to stop)";
  sleep 5;
  diskutil partitionDisk ${DISK} ${FS_FORMAT} ${PARTITION_NAME} 100%;
}

start_os_install() {
  echo -e "\n[+] Starting macOS $OS_RELEASE install on /Volumes/$PARTITION_NAME (CTRL-C to stop)";
  sleep 5;

  ##/Volumes/$DRIVE_LABEL/Install\ macOS\ Big\ Sur.app/Contents/Resources/startosinstall \

  "${HERE}/Install macOS ${OS_RELEASE}.app/"Contents/Resources/startosinstall \
  --agreetolicense --volume /Volumes/${PARTITION_NAME} --rebootdelay 5;
}

main() {
  diskutil list $DISK;

  erase_internal_disk;

  partition_internal_disk;

  startosinstall;
}

main
