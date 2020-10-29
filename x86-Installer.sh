#!/usr/bin/bash

function pass() {
	notimportant="yes"
}

function PrintHelp() {
echo "
Advanced Android x86 Installer by SupremeGamers
Developed by Kiddo Jaxparrow.

use $0 {Android image file} - Install the image on the current directory ( At the same partition ).
use $0 --data-create to create data.img ( 4,8,16,32GB )

create a file named '.include' where you run the script and add the files you want to copy in the iso.
e.g. gearlock or kernel.benares. NOTE : Useful for developers/Modders.

.include file rules:-
* one filename per line
* Should not be empty ( empty file will be skipped)

Supports Ext4 and Other file systems too~

GRUB Code and updating for plain grub or  give grub for manually for other Boot Loaders.. ( Will be fixed later ).

Just for testing purposes."
exit
}

if [[ $@ == *"--help" ]];then
	PrintHelp
fi

if [[ $(whoami) != "root" ]];then

	echo "Error : Must be run as root ( Current user - $(whoami) )
Fix : Please Run this as a root user ( use sudo $0 $@ )"
	exit
fi

if [[ -z $1 ]];then
	echo "Error : Please spescify an valid file
Fix : use $0 --help for more details"
	exit
fi


if [[ -f .include ]];then
	if [[ -z $(cat .include) ]];then
		rm .include
	else
		inclist=$(cat .include)
		incl=true
	fi
fi


function DataImage() {

	HEIGHT=13
	WIDTH=45
	CHOICE_HEIGHT=10
	TITLE="Data Image"
	MENU="Choose Data image size"

	OPTIONS=(1 "4 GB"
	         2 "8 GB"
	         3 "16 GB"
	         4 "32 GB")

	CHOICE=$(./bin/dialog --clear --cancel-label "Exit" \
	                --title "$TITLE" \
	                --menu "$MENU" \
	                $HEIGHT $WIDTH $CHOICE_HEIGHT \
	                "${OPTIONS[@]}" \
	                2>&1 >/dev/tty)

    case $CHOICE in
    	1)bs=4096
		count=4194304;;
		2)bs=8192
		count=8388608;;
		3)bs=16384
		count=16777216;;
		4)bs=32768
		count=33554432;;

	esac
}

if [[ "$@" == *"--data-create"* ]];then
DataImage
./bin/dialog --title "Creating Data" --infobox "Please wait... Creating Data Image... Time depending on the size of the image." 10 50
sudo dd if=/dev/zero of="${osname}/data.img" bs=$bs count=$count
./bin/dialog --title "Complete" --msgbox "Done Creating Data.img" 7 45
clear
exit
fi

#Defining Variables

filename=$(echo "${@%/}")
ext=".iso"
osname=$(echo $filename | sed s/"$ext"//)
parttype=$(./bin/df -Th . | head -2 | tail -1 | awk '{print $2;}')
currentpartition=$(./bin/df -h . | head -2 | tail -1 | awk '{print $1;}')

if [[ -f "$filename" ]];then
echo ""
else
echo "
Error : Not a valid file
Use $0 --help for more details"
exit
fi

if [[ $parttype == *"ext"* ]];then
	ext="true";
else
	ext="false"
fi




clear
./bin/dialog --title "Install Location"  --yesno "Would you like to Install $osname on $currentpartition partition ($parttype)" 9 55

if [[ $? -eq 0 ]];then

	mkdir temp temp2 "${osname}"
	clear
	./bin/7za x $filename -otemp -aoa
	clear
	./bin/7za x temp/system.sfs -otemp2 -aoa
	clear
	./bin/dialog --title "Installing" --infobox "Copying Files" 7 45
	{
	mv temp/initrd.img "${osname}/"
	mv temp/ramdisk.img "${osname}/"
	mv temp/kernel "${osname}/"
	mv temp/install.img "${osname}/"
	mv temp2/system.img "${osname}/"
	touch "${osname}/${osname}"
	} &>/dev/null

	if [[ $incl == true ]];then
		clear
		./bin/dialog --title "Installing" --infobox "Copying files included in .include list" 7 45
		cd temp
		cp ${inclist[@]} "../${osname}/"
		cd ..
	fi

	rm temp temp2 -r
	clear
	if [[ $ext == "true" ]];then
		./bin/dialog --title "Info" --msgbox "Current Disk is ext detected. No Data image needed." 7 45
		mkdir "${osname}/data/";
	else
		./bin/dialog --title "Info" --msgbox "Current Disk is not detected as ext format.
Select Data Size next." 7 45
		DataImage
		./bin/dialog --title "Creating Data" --infobox "Please wait... Creating Data Image of $datasize GB.. It will take more time depending on the size of the data." 9 50
		{
		sudo dd if=/dev/zero of="${osname}/data.img" bs=$bs count=$count
		} &>/dev/null
	fi

clear
			# Adding Boot Entries

			if [[ -f "/etc/grub.d/40_custom" ]];then
			echo "
menuentry '$osname' {
insmod all_video
search --set=root --file $osname
linux /kernel quiet root=/dev/ram0 androidboot.selinux=permissive acpi_sleep=s3_bios,s3_mode SRC=/
initrd /initrd.img
}" >> "/etc/grub.d/40_custom"

sudo update-grub

else
echo "Saved grub code to 'grubcode' file. You need to manually add it to boot."
echo "insmod all_video
search --set=root --file $osname
linux /kernel quiet root=/dev/ram0 androidboot.selinux=permissive acpi_sleep=s3_bios,s3_mode SRC=/
initrd /initrd.img" > grubcode

./bin/dialog --title "Info" --msgbox "Saved grub code to grubcode" 7 50

fi

			./bin/dialog --title "Complete" --msgbox "Done Installing $osname" 7 45
			clear
			echo ""

	else
		./bin/dialog --title "Cancelled" --msgbox "Okay As your wish" 7 45
		{ rm temp temp2 -r
		} &>/dev/null
		clear
		exit
	fi