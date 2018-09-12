#!/bin/bash
set -e

# update repos
apt-get -y update
apt-get -y -o Dpkg::Options::="--force-confold" upgrade 

# Installation of Jenkins
wget https://pkg.jenkins.io/debian/jenkins.io.key
apt-key add jenkins.io.key
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update
apt-get install unzip ccze slurm ncdu nano nmon mingetty screen open-vm-tools apt-transport-https openjdk-8-jdk -y
apt-get update
apt-get install jenkins -y

# Installation of Packer
echo "Create Packer Directory & Configure Permissions"
mkdir /packer
chmod 777 /packer
cd /tmp
echo "Download packer_1.2.5_linux_amd64"
wget https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip
echo "Extract and place packer"
unzip packer_1.2.5_linux_amd64.zip -d /packer

# Download Packer scripts from Sonar Github Account
echo "Download custom packer scripts and locate"
wget https://github.com/xtravirt/packer/archive/master.zip
unzip master.zip -d /tmp
mv /tmp/packer-master/* /packer

# Configure variables
export NMON=mndc
export PATH="$PATH:/usr/local/packer"
echo "Update Environment"
source /etc/environment

# Clean up files that are no longer needed
echo "Perform file system cleanup activity"
rm -f /tmp/master.zip
rm -f /tmp/packer_1.2.5_linux_amd64.zip
rm -d -f /tmp/packer-master
rm -f /tmp/jenkins.io.key

apt-get -y autoremove
apt-get -y purge

# reboot
reboot
