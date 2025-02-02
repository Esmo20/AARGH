#!/bin/sh
# An Arch Ricing Gentle Helper (AARGH)
# [based off LARBS by Luke Smith for my own setup]
# License: GNU GPLv3

# SLOC: 153

### OPTIONS AND VARIABLES ###

while getopts ":a:r:b:p:sh" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="git@github.com:Esmo20/dotfiles.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/Esmo20/AARGH/master/progs.csv"
[ -z "$aurhelper" ] && aurhelper="paru"

### FUNCTIONS ###

# Initial settings
installpkg(){ pacman --noconfirm --needed -S "$@" >/dev/null 2>&1 ;}
grepseq="\"^[PGA]*,\""

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit;}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to Esmos An Arch Ricing Gentle Helper!\\n\\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-Fra" 10 60

	dialog --colors --title "Important Note!" --yes-label "All ready!" --no-label "Return..." --yesno "Be sure the computer you are using has current pacman updates and refreshed Arch keyrings.\\n\\nIf it does not, the installation of some programs might fail." 8 70
	}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! (id -u "$name" >/dev/null) 2>&1 ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. AARGH can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nAARGH will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that AARGH will change $name's password to the one you just gave." 14 70
	}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
	}


	
		 
	
	

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#AARGH/d" /etc/sudoers
	echo "$* #AARGH" >> /etc/sudoers ;}

manualinstall() { # Installs $1 manually if not installed.
	[ -f "/usr/bin/$1" ] || (
	dialog --infobox "Installing \"$1\"." 4 50
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "AARGH Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "AARGH Installation" --infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return ; sudo -u "$name" git pull origin master;}
	cd "$dir" || exit
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return ;}

aurinstall() { \
	dialog --title "AARGH Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo "$aurinstalled" | grep "^$1$" >/dev/null 2>&1 && return
	sudo -u "$name" $aurhelper --skipreview --needed -S --noconfirm "$1" >/dev/null 2>&1
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}

putgitrepo() {
	[ ! -d "/home/$name" ] && mkdir -p "/home/$name"
	sudo -u "$name" mkdir -p "/home/$name/.config/dots"
	chown "$name":wheel "/home/$name"
	# Install dotbare from AUR
		dialog --title "AARGH Installation" --infobox "Installing \`dotbare\` from AUR to manage dotfiles" 5 70
		sudo -u "$name" $aurhelper --skipreview -S --noconfirm dotbare >/dev/null 2>&1
	# set dotbare ENV variables and run dotbare
		export DOTBARE_DIR="/home/$name/.config/dots"
    export DOTBARE_TREE="/home/$name"
    sudo -u "$name" dotbare finit -u $dotfilesrepo -s
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Install dialog.
installpkg dialog || error "Are you sure you're running this as the root user and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

adduserandpass || error "Error adding username and/or password."

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."



dialog --title "AARGH Installation" --infobox "Installing \`basedevel\` and \`git\` for installing other software required for the installation of other programs." 5 70
installpkg curl base-devel git ntp

dialog --title "AARGH Installation" --infobox "Synchronizing system time to ensure successful and secure installation of software..." 4 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Make pacman colorful and add eye candy on the progress bar.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

manualinstall $aurhelper-bin || error "Failed to install AUR helper."
# Removed packages
manualinstall dmenu-bachoseven-git
manualinstall sxiv-bachoseven-git

# make ssh key in an interactive way
dialog --title "AARGH Installation" --infobox "Generating ssh key (you can optionally import it into your github account): insert your email" 5 70
printf "email:\n"
read -r email
sudo -u "$name" ssh-keygen -t rsa -b 4096 -C "$email"
curl -sF"file=@/home/$name/.ssh/id_rsa.pub" https://0x0.st
echo "go to github..."
read -r _

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

### POST-INSTALLATION
dialog --title "AARGH Installation" --infobox "Activating services (post-installation)" 5 70
sudo -u "$name" systemctl --user enable mpd.service
systemctl enable bluetooth.service
systemctl enable tlp.service
systemctl enable systemd-timesyncd.service
systemctl start pkgstats.service
systemctl set-default multi-user.target

# Install the dotfiles in the user's home directory
[ -d "/home/$name/.config/dots" ] || putgitrepo

# Uninstall unneeded packages
dialog --title "AARGH Installation" --infobox "Removing useless packages from installation" 5 70
sudo -u "$name" $aurhelper -Rsc --noconfirm ntp dialog

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1

# Create dirs to unclutter ~
sudo -u "$name" mkdir -p "/home/$name/.local/share/tig/" "/home/$name/.local/share/octave/" "/home/$name/.config/weechat/python/autoload" "/home/$name/.local/share/gnupg" "/home/$name/.config/nvim/sessions" "/home/$name/.config/browser/bkp/hist" "/home/$name/.config/browser/bkp/bm"
sudo -u "$name" touch "/home/$name/.local/share/bg"
chmod 700 "/home/$name/.local/share/gnupg"

# Enable user to turn bluetooth on/off with `rfkill`
usermod -aG rfkill "$name"

# Create useful mount dirs under /mnt
mkdir -p /mnt/usb1 /mnt/usb2 /mnt/iso /mnt/backup /mnt/backup/home /mnt/backup/root /mnt/roba /mnt/fraEl /mnt/fraPass

# Start/restart PulseAudio.
killall pulseaudio >/dev/null 2>&1; sudo -u "$name" pulseaudio --start

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
newperms "%wheel ALL=(ALL) ALL #AARGH
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/nmtui,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman,/usr/bin/systemctl restart NetworkManager,/usr/bin/pacnews"
