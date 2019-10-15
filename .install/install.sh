#!/bin/sh

while getopts ":a:u:p:m:s:f:h" o; do case "${o}" in
	a) aurhelper=${OPTARG} ;;
	u) name=${OPTARG} ;;
	p) password=${OPTARG} ;;
	m) mainconfig=${OPTARG} ;;
	s) sucklessconfig=${OPTARG};;
	f) progsfile=${OPTARG};;
	h) printf "Optional arguments for custom use:\\n -a: AUR helper (must have pacman-like syntax)\\n  -h: Show this message\\n" && exit ;;
	*) printf "Invalid option: -%s\\n" $OPTARG && exit ;;
esac done

# DEFAULTS:
[ -z $aurhelper ] && aurhelper=yay
[ -z $name ] && name=avi
[ -z $password ] && password=password
[ -z $mainconfig ] && mainconfig=arch-dwm-desktop
[ -z $sucklessconfig ] && sucklessconfig=config-1
[ -z $progsfile ] && progsfile=home/$name/.install/progs.csv

### FUNCTIONS ###

error() { clear; printf "ERROR:\\n%s\\n" $1; exit;}

welcomemsg() { \
	dialog --title "Welcome" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "Welcome to Avi's Auto-Configuration Script (Based on Luke's Auto-Rice Bootstrapping Script)!\\n\\nThis script will automatically install a fully-featured dwm Arch Linux desktop, which I use as my main machine.\\n\\n The installation will be totally automated." 13 50 || { clear; exit; }
}

adduserandpass(){\
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel $name > /dev/null 2>&1 ||
	usermod -a -G wheel $name && mkdir -p /home/name && chown $name:wheel /home/$name
	echo "$name:$password" | chpasswd
	unset password
}

refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
}

installconfigfiles(){\
	dialog --infobox "Installing config files..." 4 40
	[ -f /usr/bin/git ] || pacman --noconfirm --needed -S git >/dev/null 2>&1
	sudo -u $name git clone --bare https://github.com/aar015/config-repo.git /home/$name/.config-repo >/dev/null 2>&1
	sudo -u $name git --git-dir=/home/$name/.config-repo --work-tree=/home/$name/ checkout $mainconfig >/dev/null 2>&1
	sudo -u $name git --git-dir=/home/$name/.config-repo --work-tree=/home/$name/ config --local status.showUntrackedFiles no
}

installsucklessprogram(){ for program in $@; do
	dialog --infobox "Installing \"$program\", a suckless program..." 5 70
	[ -f /usr/bin/git ] || pacman --noconfirm --needed -S git >/dev/null 2>&1
	[ -d /home/$name/.suckless ] || sudo -u $name mkdir /home/$name/.suckless
	sudo -u $name git clone https://github.com/aar015/$program.git /home/$name/.suckless/$program > /dev/null 2>&1
	sudo -u $name git --git-dir=/home/$name/.suckless/$program/.git --work-tree=/home/$name/.suckless/$program checkout $sucklessconfig > /dev/null 2>&1
	sudo make -C /home/$name/.suckless/$program clean install >/dev/null 2>&1
	done
}

manualinstall() {
	[ -f /usr/bin/$1 ] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 4 50
	cd /tmp || exit
	sudo rm -rf /tmp/$1*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz &&
	sudo -u $name tar -xvf $1.tar.gz >/dev/null 2>&1 &&
	cd $1 &&
	sudo -u $name makepkg --noconfirm -si >/dev/null 2>&1
	cd /tmp || return) ;
}

maininstall() {
	dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	pacman --noconfirm --needed -S $1 >/dev/null 2>&1
}

aurinstall() { \
	dialog --title "LARBS Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 5 70
	echo $aurinstalled | grep "^$1$" >/dev/null 2>&1 && return
	sudo -u $name $aurhelper -S --noconfirm $1 >/dev/null 2>&1
}

pipinstall() { \
	dialog --title "LARBS Installation" --infobox "Installing the Python package \`$1\` ($n of $total). $1 $2" 5 70
	command -v pip || pacman -S --noconfirm --needed python-pip >/dev/null 2>&1
	yes | pip install $1
}

installationloop() { \
	([ -f $progsfile ] && cp $progsfile /tmp/progs.csv) || curl -Ls $progsfile | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qm | awk '{print $1}')
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo $comment | grep "^\".*\"$" >/dev/null 2>&1 && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case $tag in
			"") maininstall "$program" "$comment" ;;
			"A") aurinstall "$program" "$comment" ;;
			"G") gitmakeinstall "$program" "$comment" ;;
			"P") pipinstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;
}

serviceinit() { for service in $@; do
	dialog --infobox "Enabling \"$service\"..." 4 40
	systemctl enable $service
	systemctl start $service
	done ;
}

systembeepoff() { dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;
}

resetpulse() { dialog --infobox "Reseting Pulseaudio..." 4 50
	killall pulseaudio
	sudo -n $name pulseaudio --start ;
}

finalize(){ \
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment (it will start automatically in tty1)." 12 80
}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Check if user is root on Arch distro. Install dialog.
pacman -Syu --noconfirm --needed dialog ||  error "Are you sure you're running this as the root user? Are you sure you're using an Arch-based distro? ;-) Are you sure you have an internet connection? Are you sure your Arch keyring is updated?"

# Welcome user.
welcomemsg || error "User exited."

# Add new user
adduserandpass || error "Error creating new user."

# Refresh Arch keyrings.
refreshkeys || error "Error automatically refreshing Arch keyring. Consider doing so manually."

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Install dot files
installconfigfiles || error "Error installing the config files"

# Install suckless programs
installsucklessprogram dwm st dmenu || error "Error installing a suckless program"

# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf

# Install the aur helper
manualinstall $aurhelper || error "Failed to install AUR helper."

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop || error "Failed to install all programs"

# Pulseaudio, if/when initially installed, often needs a restart to work immediately.
[ -f /usr/bin/pulseaudio ] && resetpulse

# Enable services here.
serviceinit NetworkManager nordvpnd

# Most important command! Get rid of the beep!
systembeepoff

# Change the default shell to zsh
chsh -s /bin/zsh $name

# Last message! Install complete!
finalize
clear
