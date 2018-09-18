#!/bin/bash
echo "Set Interpreter"
 set -e

# update repos
echo "Updating Repositories"
apt-get -y update
apt-get -y -o Dpkg::Options::="--force-confold" upgrade

# Installation of Jenkins
echo "Installing Jenkins"
cd "/tmp"
wget -q -O - "https://pkg.jenkins.io/debian/jenkins-ci.org.key" | sudo apt-key add -
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update
apt-get install jenkins -y
ufw allow 8080
systemctl start jenkins

# Installation of Packer
echo "Create Packer Directory & Configure Permissions"
mkdir "/opt/packer"
chmod 777 "/opt/packer"
cd "/tmp"
echo "Download packer_1.2.5_linux_amd64"
wget "https://releases.hashicorp.com/packer/1.2.5/packer_1.2.5_linux_amd64.zip"
echo "Extract and place packer"
unzip packer_1.2.5_linux_amd64.zip -d "/opt/packer"

# Download Packer scripts from Sonar Github Account
echo "Download custom packer scripts and locate"
cd "/tmp"
wget "https://github.com/xtravirt/packer/archive/master.zip"
unzip master.zip -d "/tmp"
mv /tmp/packer-master/* "/opt/packer"

# Configure variables
echo "Update Environment"
export NMON=mndc
export PATH="$PATH:/usr/local/packer"

# Clean up files that are no longer needed
echo "Perform file system cleanup activity"
rm -f /tmp/master.zip
rm -f /tmp/packer_1.2.5_linux_amd64.zip
rm -d -f /tmp/packer-master
rm -f /tmp/jenkins.io.key
apt-get -y autoremove
apt-get -y purge
