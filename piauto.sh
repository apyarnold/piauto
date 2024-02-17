#!/bin/bash

set -ex

#Set logging variables
logdir=~/logs
logfile="$logdir/piauto.log"
#Set nfs variables
mntdir="/mnt"
mntpoint="$mntdir/remotebackup"
nassvr="192.168.1.41"
nassvrpath=/volume2/Backups
nasdir="$nassvr:$nassvrpath"
nasdest="$nasdir/$HOSTNAME"
nastmpdir="$mntpoint/$HOSTNAME"
nasoptions="nfs auto 0 0"
nasautomount="$nasdest $mntpoint $nasoptions"
nasbadmount="$nasdir $mntpoint $nasoptions"
nfspkg="nfs-common"
nasfstab="/etc/fstab"
#Set kiauh variables 
kiauhscript="/home/ayarnold/kiauh/kiauh.sh"
kiauhlink="/bin/kiauh"


#Creating the log directory and file.
echo "Creating the log directory and log file."
if [ ! -d "$logdir" ]
then
    #Creates the log directory.
    mkdir "$logdir"
    #Creates the log file.
    touch "$logfile"
    #Checks if the log file already exists.
elif [ ! -f "$logfile" ]
then
        #Creates the log file.
        touch "$logfile"
        if [ -f "$logfile" ]
        then
            echo "Log file created successfully."
        fi
else
    echo "Log directory and file already exists"
fi

#Update all system files.
echo "Start system updates" |& tee -a "$logfile"
sudo apt update && sudo apt full-upgrade -y |& tee -a "$logfile"

#This function calls all other subordinate functions to get things done.
function_main() {
    echo "Start function_main" |& tee -a "$logfile"
    #Check if the wayvnc package is NOT installed. Only desktop has it
    #installed from scratch.
    if [[ ! "$(dpkg -s wayvnc)"  > /dev/null ]]
    then
        echo "Desktop not found. Starting lite installation" |& tee -a "$logfile"
        function_installnfs
        function_remotebackup
        function_automountnfs
        function_installkiauh
        function_easyrunkiauh
        function_sshkey
        echo "lite installation complete" |& tee -a "$logfile"
    else
        echo "Desktop found. Starting full installation" |& tee -a "$logfile"
        function_installnfs
        function_remotebackup
        function_automountnfs
        function_enablevnc
        function_sshkey
        echo "Desktop installation complete" |& tee -a "$logfile"
    fi
}

#This function checks if nfs-common package is installed. If it isn't
#installation will be performed.
function_installnfs() {
    echo "Start function_installnfs" |& tee -a "$logfile"
    #Checks if nfs-common package is installed
    if dpkg -s "$nfspkg" > /dev/null
    then
        echo "Package $nfspkg Installed. Continuing" |& tee -a "$logfile"
    else
        echo "Package $nfspkg NOT installed. Installing $nfspkg" |& tee -a "$logfile"
        #installs nfs-common package.
        sudo apt install "$nfspkg" -y
        #Checks if nfs-common package installed correctly
        if dpkg -s "$nfspkg" > /dev/null
        then
            echo "Package $nfspkg installed successfully" |& tee -a "$logfile"
        fi
    fi
}

#This function checks for "remotebackup" dir in /mnt/remotebackup. If it
#doesn't exist it is created.
function_remotebackup() {
    echo "Start function_remotebackup" |& tee -a "$logfile"
    #Checks if /mnt/remotebackup DOES NOT exist.
    if [ ! -d "$mntpoint" ] 
    then
        echo "NFS mount point does not exist. Creating the directory"
        #Makes the /mnt/remotebackup directory and sets permissions
        sudo mkdir "$mntpoint"
        sudo chown ayarnold:users "$mntpoint"
        sudo chmod 755 "$mntpoint"
        #Mounts the remote server
        sudo mount -t nfs "$nasdir" "$mntpoint"
        #Checks if the mount was successful
        if [[ $(findmnt -M "$mntpoint") > /dev/null ]]
        then
            echo "NFS mount point created successfully" |& tee -a "$logfile"
            #Checks if correct backup directory exists. i.e. /mnt/remotebackup/HOSTNAME
            if [ -d "$nastmpdir" ]
            then
                echo "Correct backup directoy exists" |& tee -a "$logfile"
                #As it exists unmounts the remote server
                sudo umount "$mntpoint"
            else
                echo "Correct backup directory does not exist. Creating it" |& tee -a "$logfile"
                #Creates the correct backup directory and sets permissions
                sudo mkdir "$nastmpdir"
                sudo chown ayarnold:users "$nastmpdir"
                #Checks that the directory was created successfully.
                if [ -d "$nastmpdir" ]
                then
                    echo "Correct backup directory created successfully" |& tee -a "$logfile"
                    #Unmounts the remote server
                    sudo umount "$mntpoint"
                    if [[ $(findmnt -M "$mntpoint") ]]
                    then
                        echo "Temporary NAS mount removed successfully" |& tee -a "$logfile"
                    fi
                fi
            fi
        fi
    else
        echo "$mntpoint already exists. Checking mount." |& tee -a "$logfile"
        #As the mount point exists, checks if the correct backup directory exists.
        if [[ $(findmnt -M "$mntpoint") > /dev/null ]]
        then
            echo "NAS already mounted. unmounting to ensure correct mount" |& tee -a "$logfile"
            sudo umount "$mntpoint"
            if [[ ! $(findmnt -M "$mntpoint") > /dev/null ]]
            then
                echo "Unknown NAS mount removed successfully" |& tee -a "$logfile"
                echo "Mounting correct backup directory" |& tee -a "$logfile"
                sudo mount -t nfs "$nasdir" "$mntpoint"
                if [[ $(findmnt -M "$mntpoint") > /dev/null ]]
                then
                    echo "Correct backup directory mounted successfully" |& tee -a "$logfile"
                fi
            fi
        fi
        if [ -d "$nastmpdir" ]
        then
            echo "Correct backup directory exists" |& tee -a "$logfile"
            #If the correct backup directory exists, unmounts the remote server
            sudo umount "$mntpoint"
            if [[ -z $(findmnt -M "$mntpoint") ]]
            then
                echo "Temporary NAS mount removed successfully" |& tee -a "$logfile"
            fi
        else
            echo "Correct backup directory does not exist. Creating it" |& tee -a "$logfile"
            #Checks if the NAS is NOT mounted
            if [[ -z $(findmnt -M "$mntpoint") ]]
            #Then mounts to check the correct backup directory exists.
            then 
                sudo mount -t nfs "$nasdir" "$mntpoint"
                #Checks if the correct backup directory exists
                if [ -d "$nastmpdir" ]
                then
                    echo "Correct backup directory exists" |& tee -a "$logfile"
                    #As the correct directory for the backups exists, unmounts the remote server
                    echo "Unmounting NAS mount" |& tee -a "$logfile"
                    sudo umount "$mntpoint"
                    #Checks if the temporary NAS mount is unmounted
                    if [[ -z $(findmnt -M "$mntpoint") ]]
                    then
                        echo "Temporary NAS mount removed successfully" |& tee -a "$logfile"
                    fi
                else
                    echo "Correct backup directory does not exist. Creating it" |& tee -a "$logfile"
                    #Creates the correct backup directory and sets permissions.
                    sudo mkdir "$nastmpdir"
                    sudo chown ayarnold:users "$nastmpdir"
                    sudo chmod 755 "$nastmpdir"
                    #Checks that the directory was created successfully.
                    if [ -d "$nasdest" ]
                    then
                        echo "Correct backup directory created successfully" |& tee -a "$logfile"
                        #Unmounts the remote server
                        echo "Removing temporary NAS mount" |& tee -a "$logfile"
                        sudo umount "$mntpoint"
                        #Checks if the temporary NAS mount is unmounted successfully.
                        if [[ -z "$(findmnt -M "$mntpoint" > /dev/null)" ]]
                        then
                            echo "Temporary NAS mount removed successfully" |& tee -a "$logfile"
                        fi
                    fi
                fi
            fi
        fi
    fi
    

echo "function_remotebackup completed successfully" |& tee -a "$logfile"
}

function_automountnfs() {
    echo "Start function_automountnfs" |& tee -a "$logfile"
    #Checks if the entry already exists in /etc/fstab for auto mount
    if grep "$nasautomount" "$nasfstab"
    then
        echo "Entry Exists!" |& tee -a "$logfile"
    else
        echo "Auto mount will now be setup" |& tee -a "$logfile"
        if grep "$nasbadmount" "$nasfstab"
        then
            echo "Incorrect mount entry exists" |& tee -a "$logfile"
            echo "Removing bad mount entry" |& tee -a "$logfile"
            sed -i.bak "/$nasbadmount/d" "$nasfstab"
            if ! grep "$nasbadmount" "$nasfstab"
            then
                echo "Bad mount entry removed successfully" |& tee -a "$logfile"
            fi
        fi
        #Appends the entry to /etc/fstab
        echo "$nasautomount" | sudo tee -a /etc/fstab |& tee -a "$logfile"
        if grep "$nasautomount" "$nasfstab"
        then
            echo "fstab file appended correctly" |& tee -a "$logfile"
            sudo mount "$mntpoint" |& tee -a "$logfile"
        fi
    fi
}

#This function checks to see if the kiauh.sh file exists. If it doesn't
#kiauh is installed. Note that the syntax is -f to detect a file instead
#of -d which detects a directory.
function_installkiauh() {
    echo "Start function_installkiauh" |& tee -a "$logfile"
    #Checks if the kiauh.sh file DOES NOT exist.
    if [ ! -f "$kiauhscript" ]
    then
        echo "kiauh will be installed!" |& tee -a "$logfile"
        #Installs kiauh by cloning the repository.
        cd ~ && git clone https://github.com/dw-0/kiauh.git |& tee -a "$logfile"
    else
        echo "kiauh already exists! Continuing" |& tee -a "$logfile"
    fi
}

#easyrunkiauh creates a symbolic link in the /bin dir to /home/ayarnold/kiauh/kiauh.sh
#so that kiauh can be run without the path or .sh
function_easyrunkiauh() {
    echo "Start function_easyrunkiauh" |& tee -a "$logfile"
    #Checks if the symbolic link for kiauh.sh already exists
    if [ -L "${kiauhlink}" ] && [ -e "${kiauhlink}" ]
    then
        echo "kiauh symbolic link exists! Continuing" |& tee -a "$logfile"
    else
        echo "kiauh symbolic link is being created" |& tee -a "$logfile"
        #Creates the symbolic link to kiauh.sh
        sudo ln -s "$kiauhscript" "$kiauhlink" |& tee -a "$logfile"
        #Checks if the symbolic link was created successfully.
        if [ -L "${kiauhlink}" ] && [ -e "${kiauhlink}" ]
        then
            echo "Symbolic link kiauh created successfully" |& tee -a "$logfile"
        fi
    fi
}

#This function sets the ssh public key for the ayarnold user.
function_sshkey () {
    publickey="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdVjvtAcAGzl0/gRF/sSZnKFRIAmgwPetABigclqk8z eddsa-key-20240210"
    sshdir="$HOME/.ssh"
    sshfile="$sshdir/authorized_keys"
    #Checks that the SSH directory DOES NOT exist.
    if [ ! -d "$sshdir" ]
    then
        echo ".ssh does not exist" |& tee -a "$logfile"
        #Installs the .ssh directory and sets permissions
        install -d -m 700 "$sshdir"
        touch "$sshfile"
        sudo chmod 644 "$sshfile"
        sudo chown ayarnold:ayarnold "$sshfile"
        #Appends the public key to the authorized_keys file.
        echo "$publickey" | tee -a "$sshfile" > /dev/null
        if grep "$publickey" "$sshfile" > /dev/null
        then
            echo "SSH Public key set successfully." |& tee -a "$logfile"
        fi
    #Checks that the SSH authorized_keys file DOES NOT exist.
    elif [ ! -f "$sshfile" ]
    then
        echo ".ssh dir exists but authorized_keys file doesn't" |& tee -a "$logfile"
        echo "Creating authorized_keys file." |& tee -a "$logfile"
        #Creates the Authorized_keys file and sets permissions.
        touch "$sshfile"
        sudo chmod 644 ~/.ssh/authorized_keys
        sudo chown ayarnold:ayarnold "$sshfile"
        if [ -f "$sshfile" ]
        then
            echo "Authorized_keys file created successfully." |& tee -a "$logfile"
        fi
        #Appends the public key to the authorized_keys file.
        echo "$publickey" | tee -a "$sshfile"
        #Checks that the key was apended correctly.
        if grep "$publickey" "$sshfile" > /dev/null
        then
            echo "Public key appended successfully." |& tee -a "$logfile"
        fi
    fi

}

#This function enables wayvnc for Pis running desktops
function_enablevnc() {
    #Checks if wayvnc is installed
    if [ "$(dpkg -s wayvnc)" ] > /dev/null
    then
        if systemctl is-active --quiet wayvnc.service
        then
            echo "wayvnc is already enabled. Continuing" |& tee -a "$logfile"
        else
            echo "Configuring and starting wayvnc" |& tee -a "$logfile"
            #Enables wayvnc
            sudo systemctl enable wayvnc.service
            sudo systemctl start wayvnc.service
            if systemctl is-active --quiet wayvnc.service
            then
                echo "wayvnc enabled successfully" |& tee -a "$logfile"
            fi
        fi
    else
        echo "wayvnc is not installed. Continuing" |& tee -a "$logfile"
        #Installs wayvnc
        sudo apt install wayvnc -y
        #Checks if wayvnc is installed successfully.
        if [ "$(dpkg -s wayvnc)" ] > /dev/null
        then
            echo "wayvnc installed successfully" |& tee -a "$logfile"
        fi
        #Enables wayvnc
        sudo systemctl enable wayvnc.service
        sudo systemctl start wayvnc.service
        echo "wayvnc enabled successfully" |& tee -a "$logfile"
        
    fi
}

function_main

