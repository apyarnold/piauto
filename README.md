# RPI-Auto-Setup
A Script or set of files for setting up my Raspberry Pis

I have created a script that can be downloaded and run from any Raspberry Pi that has internet connectivity.

It should do all the first-time setups for the Pi depending on whether it's a fresh desktop or lite installation.

This will rely on the settings in Pi Imager that give the Pi its hostname, wifi config, and user creds and enable SSH with password, to get the ball rolling.

I would love to eventually be able to bare metal boot the Pis from a directory on my NAS and have the install and setup automated. Hmm! Should I be scripting or designing and printing. The bain of having too many interesting projects.

The script is a bit rough around the edges but I will gradually clean it up and may convert it to Python or some nonsense ;).

I'm still a noob and github so versioning may be off until I get a hang of it all.

The current script does the following:
1. updates the OS
2. Creates a log directory and log file.
3. Check whether wayvnc is installed to detect whether it is a desktop or lite install. NOTE: This may need to change if the OS stops using wayvnc.
4. Check whether nfs-common package is installed and install it if not.
5. Sets up the /mnt/remotebackup mount point and checks several things and creates the right conditions for my needs, including mounting my NAS using NFS and setting up the directory structure I use
6. Edits the /etc/fstab file to automount the NAS correct backup directory on startup
7. If lite install, installs kiauh for my klipper environment
8. Creates a symlink in /bin for kiauh.sh to save typing all the directory etc to run it. (Yes, laziness is no good unless well carried out)
9. If desktop enables VNC so that it is ready for first use.
10. Creates the ~/.ssh/authorized_keys directory and file for holding SSH keys and populates it with Public key.

At this point the above is working and has various checks to ensure that nothing too bad goes awry. So far so good.

This is still a work in progress and probably will remain so as I find other things I want installed automatically for testing etc.
