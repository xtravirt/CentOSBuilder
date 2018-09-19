#!/usr/bin/env bash

# file names & paths
tmp="/tmp"  # destination folder to store the final iso file
hostname="centos"
currentuser="$( whoami)"
build_file="builder.sh"
ks_file="kickstart.cfg"

# define spinner function for slow tasks
# courtesy of http://fitnr.com/showing-a-bash-spinner.html
spinner()
{
    local pid=$1
    local delay=0.75
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# define download function
# courtesy of http://fitnr.com/showing-file-download-progress-using-wget.html
download()
{
    local url=$1
    echo -n "    "
    wget --progress=dot $url 2>&1 | grep --line-buffered "%" | \
        sed -u -e "s,\.,,g" | awk '{printf("\b\b\b\b%4s", $2)}'
    echo -ne "\b\b\b\b"
    echo " DONE"
}

# define function to check if program is installed
# courtesy of https://gist.github.com/JamieMason/4761049
function program_is_installed {
    # set to 1 initially
    local return_=1
    # set to 0 if not found
    type $1 >/dev/null 2>&1 || { local return_=0; }
    # return value
    echo $return_
}

# print a pretty header
echo
echo " +---------------------------------------------------+"
echo " |            UNATTENDED CENTOS ISO MAKER            |"
echo " +---------------------------------------------------+"
echo

# ask if script runs without sudo or root priveleges
if [ $currentuser != "root" ]; then
    echo " you need sudo privileges to run this script, or run it as root"
    exit 1
fi

#check that we are in centos 7

fgrep VERSION_ID='"7"' /etc/os-release >/dev/null 2>&1

if [ $? -eq 0 ]; then
     cent7="yes"
fi

#install apps required for this script
yum install -y wget expect genisoimage
echo "Required apps for script installed: Pass"

# ask whether to include vmware tools or not
while true; do
    echo " which CentOS edition would you like to remaster:"
    echo
    echo "  [1] CentOS 7 Minimal 64bit"
    echo
    read -p " please enter your preference: [1]: " ubver
    case $ubver in
        [1]* )  download_file="CentOS-7-x86_64-Minimal-1804.iso"
                download_location="http://mirror.cwcs.co.uk/centos/7/isos/x86_64/"
                new_iso_name="CentOS-7-x86_64-Minimal-1804-unattended.iso"
                break;;
        * ) echo " please answer [1]";;
    esac
done

timezone="Europe/London"

# ask the user questions about his/her preferences
read -ep " please enter your preferred timezone: " -i "${timezone}" timezone
read -ep " please enter your preferred username: " -i "sonar" username
read -sp " please enter your preferred password: " password
printf "\n"
read -sp " confirm your preferred password: " password2
printf "\n"
#read -ep " Make ISO bootable via USB: " -i "no" bootable

# check if the passwords match to prevent headaches
if [[ "$password" != "$password2" ]]; then
    echo " your passwords do not match; please restart the script and try again"
    echo
    exit
fi
echo "Password Check: Pass"

# download the centos iso. If it already exists, do not delete in the end.
cd $tmp


if [ ! -f $tmp/$download_file ]; then
    echo -n " Downloading $download_file: "
    wget "$download_location$download_file"
fi
if [ ! -f $tmp/$download_file ]; then
  echo "Error: Failed to download ISO: $download_location$download_file"
  echo "This file may have moved or may no longer exist."
  echo
  echo "You can download it manually and move it to $tmp/$download_file"
  echo "Then run this script again."
  exit 1
fi
echo "Download $download_file iso: Pass"

# download seed file

if [[ ! -f $tmp/$ks_file ]]; then
    echo -n " downloading $ks_file: "
    download "https://raw.githubusercontent.com/xtravirt/CentOSBuilder/master/$ks_file"
    echo "Download seed file: Pass"
    echo -n " downloading $build_file: "
    download "https://raw.githubusercontent.com/xtravirt/CentOSBuilder/master/$build_file"
    echo "Download builder file: Pass"
fi

# create working folders
echo " remastering your iso file"
mkdir -p $tmp
mkdir -p $tmp/iso_org
mkdir -p $tmp/iso_new

# mount the image
mount -o loop $tmp/$download_file $tmp/iso_org > /dev/null 2>&1
echo "Mount image: Pass"
# copy the iso contents to the working directory
(cp -rT $tmp/iso_org $tmp/iso_new > /dev/null 2>&1) & spinner $!
echo "Copy to working directory: Pass"
#change directory permissions for new image
chmod -R u+w $tmp/iso_new > /dev/null 2>&1
echo "New image directory permissions changed: Pass"

#copy Kickstart file to image directory
mkdir -p $tmp/iso_new/isolinux
cp -rT $tmp/$ks_file $tmp/iso_new/isolinux/$ks_file
echo "Copy the install seed file to the iso: Pass"

#add kickstart to boot options.
sed -i 's/append\ initrd\=initrd.img/append initrd=initrd.img\ ks\=cdrom:\/ks.cfg/' $tmp/iso_new/isolinux/isolinux.cfg
echo "Modified kickstart boot options: Pass"

# generate the password hash
pwhash=$(echo $password | mkpasswd -s 1)
echo "Generate the password hash: Pass"

# update the seed file to reflect the users' choices
# the normal separator for sed is /, but both the password and the timezone may contain it
# so instead, I am using @
sed -i "s@{{username}}@$username@g" $tmp/iso_new/isolinux/$ks_file
sed -i "s@{{pwhash}}@$password@g" $tmp/iso_new/isolinux/$ks_file
sed -i "s@{{hostname}}@$hostname@g" $tmp/iso_new/isolinux/$ks_file
sed -i "s@{{timezone}}@$timezone@g" $tmp/iso_new/isolinux/$ks_file
echo "Update the seed file to reflect the users choices: Pass"

# calculate checksum for seed file
seed_checksum=$(md5sum $tmp/iso_new/isolinux/$ks_file)
echo "Calculate checksum for seed file: Pass"

echo "Creating the remastered iso"
cd $tmp/iso_new
(mkisofs -o $tmp/$new_iso_name -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -V "CentOS 7 x86_64" -R -J -v -T isolinux/. . > /dev/null 2>&1) & spinner $!
echo "Creating the remastered iso: Pass"

# cleanup
umount $tmp/iso_org
cd $tmp
rm -rf $tmp/iso_new
rm -rf $tmp/iso_org
rm -rf $tmphtml
rm -rf $tmp/install.seed
rm -rf $tmp/download_file
echo "Cleanup: Pass"

# print info to user
echo " -----"
echo " Finished remastering your ubuntu iso file"
echo " The new file is located at: $tmp/$new_iso_name"
echo " Your username is: $username"
echo " Your password is: $password"
echo " Your hostname is: $hostname"
echo " Your timezone is: $timezone"
echo

# unset vars
unset username
unset password
unset hostname
unset timezone
unset pwhash
unset download_file
unset download_location
unset new_iso_name
unset tmp
unset ks_file
