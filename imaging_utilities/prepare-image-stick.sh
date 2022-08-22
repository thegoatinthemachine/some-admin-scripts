#!/usr/bin/env bash

#Purpose: To prepare MDS imaging USB sticks in parallel
#Version: 2021.06.22.11.13
#Author: Stewart Johnston;
#Comment: quit breaking my shit

#options
readonly opt_ERASURE=true; #Erase the disks before copying files?
readonly opt_CP_MDS=false; #Copy files from the IMAGR_DMG directory to the
                           #MDS_VOLUME_NAME partition?
readonly opt_OS_INSTALLER=true; #Is the installer partition relevant?
readonly opt_OVERWRITE_INSTALLER=true; #Use createinstallmedia to make
                                        #bootable?
readonly opt_DEBUG=true;
readonly opt_RENAME_VOLUMES=false; #Rename the volumes in batch?
readonly opt_CP_OTHER=false; #Copy files from OTHER_RESOURCES to the main
                            #partition?
readonly opt_INSTALLER_ONLY=true; #Make only one partition for the installer,
                                  #or one for the installer and one for mds
                                  #resources?

#environment constants
readonly REVISION_DATE="2021-06-17";
readonly IMAGR_DMG="/Volumes/mdsresources";
#readonly OS_DMG="/Volumes/Install_macOS_10.15.7-19H15/";
#readonly OS_DMG="/Volumes/Install_macOS_11.4-20F71";
readonly OS_DMG="/Volumes/Install_macOS_12.4-21F79/";
readonly INSTALLER_VOLUME_NAME="${REVISION_DATE} Install macOS Monterey 12.4";
readonly INSTALLER_APP_NAME="Install macOS Monterey.app";
readonly PART_FORMAT="GPT";
readonly FILESYSTEM_FORMAT="JHFS+";
readonly MDS_VOLUME_NAME="mds";
readonly DISK_RGX_PATTERN="disk[0-9]+";
readonly OTHER_RESOURCES="/Users/localadmin/Desktop/other_resources";

#param/disk list
${opt_DEBUG} && echo "Number of parameters passed is ${#}, they are ${@}";
declare -a disks=$*;

#global mounting status array
declare increment=0;
declare -a vol_mount_success[];

function debug_print_current_disk {
	${opt_DEBUG} && [[ ${disk} ]] && echo "Current disk in $(caller 0) is ${disk}"
}

function cp_other_resources {
	debug_print_current_disk

	echo "Some rsync errors may occur, especially with metadata files like Spotlight-V100. That kind of error can be safely ignored, everything else unless otherwise stated will transfer safely."
	rsync -au --ignore-errors "${OTHER_RESOURCES}/" "/Volumes/${disk}/${INSTALLER_VOLUME_NAME}/";
	chmod +x "/Volumes/${disk}/${INSTALLER_VOLUME_NAME}/"*;
	sleep 5;
}

function print_wrapup_information {
	for i in ${vol_mount_success};
	do
		echo "Volume mount success for index (likely in the order of arguments entered) ${index} is ${vol_mount_success[${i}]}. Failure is bad, recommend investigation";
	done

	echo "Listing the disks passed as arguments so you can verify their status"
	list_disks

	check_mount_point_presence
}

function check_mount_point_presence {
	declare FAILURE=false;

	for disk in ${disks}
	do
		if [[ -d /Volumes/${disk} ]];
		then
			echo "Directory /Volumes/${disk} exists, probably from a borked run. Please remove the directory before running this script again."

			if [[ "$(ls -A /Volumes/${disk})" || "$(mount | grep ${disk})" ]];
			then
				echo "Directory /Volumes/${disk} either has files or is still mounted! Highly advised to double-check its status";
			declare FAILURE=true;
			fi
		fi
	done

	${FAILURE} && exit 1;
}

function rename_volumes {
	if [[ true == ${opt_RENAME_VOLUMES} ]];
	then
		echo "Renaming Installer and mds volumes";
		for disk in ${disks}
		do 
			echo "Renaming volumes on disk ${disk}";

			if [[ ! "$(mount | grep ${disk})" ]];
			then
				echo "Disk ${disk} wasn't completely mounted, mounting now;"
				declare unmount_after=true;
				mkdir_and_mount
			fi

			${opt_OS_INSTALLER} && diskutil rename ${disk}s2 "${INSTALLER_VOLUME_NAME}"
			${opt_CP_MDS} && diskutil rename ${disk}s3 "${MDS_VOLUME_NAME}"

			${unmount_after} && echo "Should only appear if disk ${disk} wasn't already mounted before renaming" && remove_mount_points

		done;
	fi
}

function check_euid {
	if [[ $EUID -ne 0 ]];
	then
		echo "This script must be run as root; try with sudo";
		exit 1;
	fi
}

function check_for_volumes {
	if [[ ( true == ${opt_CP_MDS} ) && ( ! -d ${IMAGR_DMG} ) ]];
	then 
		echo "Mount ${IMAGR_DMG} before using this script!";
		exit 1;
	fi

	if [[ ( true == ${opt_OS_INSTALLER} ) && ( ! -d ${OS_DMG} ) ]];
	then
		echo "Mount ${OS_DMG} before using this script!"
		exit 1;
	fi
}

function check_for_empty_arglist {
	if [[ -z ${disks} || ( ! ${disks[@]} =~ ${DISK_RGX_PATTERN} ) ]];
	then
		echo "Arglist empty or malformed; run this script with a list of disks, e.g. 'disk{2..4}' as arguments";
		echo "'diskutil list external physical' should list all USB disks";
		exit 1;
	fi
}

function list_disks {
	for disk in ${disks}
	do
		diskutil list ${disk} || \
			{ echo "${disk} not valid"; exit 1; }
	done
}

function confirm_disks {
	echo "Please confirm if these are the disks you want to process";
	select confirmation in yes no;
	do
		echo "You have chosen ${confirmation}";
		if [[ ${confirmation} != 'yes' ]];
		then
			echo "Exiting script because of non-yes answer";
			exit 1;
		elif [[ ${confirmation} == 'yes' ]];
		then break;
		fi;
	done
}

function erase_and_partition {
	debug_print_current_disk
	${opt_DEBUG} && echo "erasure with:${FILESYSTEM_FORMAT} and ${PART_FORMAT}";
	diskutil eraseDisk ${FILESYSTEM_FORMAT} "${REVISION_DATE}_macOS_image" ${PART_FORMAT} ${disk};

	if [[ false == ${opt_INSTALLER_ONLY} ]];
	then
		${opt_DEBUG} && echo "partitioning with:${INSTALLER_VOLUME_NAME}, ${FILESYSTEM_FORMAT}, and ${MDS_VOLUME_NAME}";
		diskutil partitionDisk $disk 2 ${PART_FORMAT} ${FILESYSTEM_FORMAT} \
			"${INSTALLER_VOLUME_NAME}" 10Gi \
			${FILESYSTEM_FORMAT} "${MDS_VOLUME_NAME}" R;
	else
		${opt_DEBUG} && echo "partitioning with:${INSTALLER_VOLUME_NAME}, ${FILESYSTEM_FORMAT}";
		diskutil partitionDisk $disk ${PART_FORMAT} ${FILESYSTEM_FORMAT} \
			"${INSTALLER_VOLUME_NAME}" R;
	fi
		

}

function mkdir_and_mount {
	debug_print_current_disk
	#to give legible mount points
	diskutil unmountDisk ${disk};
	sleep 5;

	${opt_OS_INSTALLER} && echo "opt_OS_INSTALLER is ${opt_OS_INSTALLER}" && \
		mkdir -p "/Volumes/${disk}/${INSTALLER_VOLUME_NAME}" && \
		echo "Installer mkdir on disk ${disk} success!" && \
		diskutil mount -mountPoint "/Volumes/${disk}/${INSTALLER_VOLUME_NAME}/" "/dev/${disk}s2" && \
		echo "Installer mount for disk ${disk} success!" || \
		( ${opt_OS_INSTALLER} && vol_mount_success[$index]=false );
	${opt_DEBUG} && echo "Installer volume mounting for ${disk} with index ${index}: ${vol_mount_success[$index]}";

	${opt_DEBUG} && echo "opt_CP_MDS is ${opt_CP_MDS}"
	${opt_CP_MDS} && echo "MDS mkdir success!" && \
		mkdir -p "/Volumes/${disk}/${MDS_VOLUME_NAME}" && \
		echo "MDS mkdir on disk ${disk} success!" && \
		diskutil mount -mountPoint "/Volumes/${disk}/${MDS_VOLUME_NAME}/" "/dev/${disk}s3" && \
		echo "MDS mount for disk ${disk} success!" || \
		( ${opt_CP_MDS} && vol_mount_success[$index]=false );
	${opt_DEBUG} && echo "MDS volume mounting for ${disk} with index ${index}: ${vol_mount_success[$index]}";

	#-1 here is the default value of the variable
	if [[ -1 -eq  ${vol_mount_success[$index]} ]];
	then
		vol_mount_success[$index]=true;
	fi
		${opt_DEBUG} && echo "volume mounting for ${disk} with index ${index}: ${vol_mount_success[$index]}";
}

function cp_mds_resources {
	debug_print_current_disk
	echo "Some rsync errors may occur, especially with metadata files like Spotlight-V100. That kind of error can be safely ignored, everything else unless otherwise stated will transfer safely."
	rsync -au --delete-after --ignore-errors "${IMAGR_DMG}/" "/Volumes/${disk}/${MDS_VOLUME_NAME}/";
	sleep 5;
}

function eject_hanging_shared_support {

	debug_print_current_disk

	if [[ ! $(hdiutil info | grep "Shared Support") ]]; then
		return 0;
	fi;

	declare OLDIFS=${IFS};
	declare IFS=$'\n';

	declare -a disk_images=($(hdiutil info | grep image-path | cut -d':' -f2 | sed -e 's/^ //'));

	for image in ${disk_images[@]}
	do
		[[ ${target} ]] && echo "var target exists, resetting" && unset target;
	${opt_DEBUG} && echo "disk image is ${image}";
	df ${image} | grep ${disk} && declare target=${image};
	${opt_DEBUG} && echo "$(df ${image})";
	${opt_DEBUG} && [[ ${target} ]] && echo "target: ${target}";
	[[ ${target} ]] && hdiutil detach $(hdiutil attach ${target} -nomount | awk 'END{print $1}');
	done;

	IFS=${OLDIFS}
}


function create_installer_volume {
	debug_print_current_disk
	${opt_OVERWRITE_INSTALLER} || return;

	${opt_DEBUG} && echo "Running ${OS_DMG}/Applications/${INSTALLER_APP_NAME}/Contents/Resources/createinstallmedia" && \
		echo "with options --volume /Volumes/${disk}/${INSTALLER_VOLUME_NAME} --nointeraction";
	"${OS_DMG}/Applications/${INSTALLER_APP_NAME}/Contents/Resources/createinstallmedia" --volume "/Volumes/${disk}/${INSTALLER_VOLUME_NAME}" --nointeraction;
	sleep 5;
}

function remove_mount_points {
	sleep 5;
	diskutil unmountDisk ${disk};
	sleep 5;
	${opt_DEBUG} && echo "Removing mount-point directories for ${disk}";
	rmdir /Volumes/${disk}/*;
	rmdir "/Volumes/${disk}/";
}

function prepare_disks {
	for disk in ${disks}
	do

		local index=$increment && ((increment++)); 
		${opt_DEBUG} && echo "Index for ${disk}" is ${index};

		(
		vol_mount_success[$index]=-1;
		${opt_DEBUG} && echo "Default volume mounting for ${disk} with index ${index}: ${vol_mount_success[$index]}";

		if [[ true == ${opt_ERASURE} ]];
		then
			erase_and_partition 
		fi

		mkdir_and_mount

		#the meat and potatoes of the shebang, run in the background
		if [[ true == ${vol_mount_success[$index]} ]];
		then
			if [[ true == ${opt_CP_MDS} ]];
			then
				cp_mds_resources &
			fi

			if [[ true == ${opt_OVERWRITE_INSTALLER} ]];
			then
				create_installer_volume &
			fi
		else
			echo "${disk} failed to mount correctly for copying!";
		fi

		sleep 5;
		wait < <(jobs -p);

		eject_hanging_shared_support
		#necessary to check for this now, because the mounted diskimage
		#is recognized as being at the location /Volumes/Install macOS
		#etc, and if that location gets changed out from underneath the
		#program, it won't correctly recognize the disk to eject

		#This step is necessary because the partition doesn't keep the
		#given name, the `createinstallmedia` command overwrites the name
		#with "Install macOS <version>", and this needs to be done
		#while the disk is still mounted. The option check just
		#prevents redundant fiddle-farting around.
		${opt_DEBUG} && echo "Checking options to rename volume in one-off now, or as batch later";
		${opt_RENAME_VOLUMES} || diskutil rename ${disk}s2 "${INSTALLER_VOLUME_NAME}"

		mkdir_and_mount

		${opt_OS_INSTALLER} && ${opt_CP_OTHER} && cp_other_resources;

		#If revising existing disks and renaming is all that is wanted,
		#the function and option to rename has been added as of 2021-02-04. 

		sleep 15; #to give background jobs an opportunity to wrap up, if needed

		#to get rid of the mount points
		remove_mount_points

		) &
		sleep 5;
	done

	#wait for all background jobs by pid lifted from
	#https://stackoverflow.com/a/36038185
	wait < <(jobs -p)
}

function main {
	check_euid
	check_for_volumes
	check_for_empty_arglist
	check_mount_point_presence
	list_disks 
	confirm_disks
	prepare_disks
	${opt_RENAME_VOLUMES} && rename_volumes
	print_wrapup_information
}

main

${opt_DEBUG} && echo "Complete!";

exit 0
