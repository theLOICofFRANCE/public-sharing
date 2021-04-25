#!/bin/sh
# Version 20210419 / BSD-2-Clause
# Copyright (c) 2021, HacKurx
# All rights reserved.

# Seul l'utilisateur root peut exécuter le script
if [ "$(id -u)" -ne "0" ]; then
	echo "Le script doit être exécuté en tant que root !" 1>&2
	exit 1
fi

# Introduction
echo
echo -e "\033[1;34;40mBienvenue dans le programme d'installation de HardenedBSD-Mate.\033[0m"
echo

while :; do
	read -p '(I)nstallation, (L)icence ou (S)ortir ? ' RINTRO

	case $RINTRO in
	[iI]*)	break;;
	[lL]*)	echo -e "\nScript sous licence BSD à deux clauses.\n" && RINTRO="";;
	[sS]*)	exit;;
	esac
done

cat <<__EOT
Début de l'installation...
__EOT

# Création des variables
ALPHA2MIN=$(grep "^keymap=" '/etc/rc.conf' | cut -d\" -f2 | cut -d\. -f1)
ALPHA2MAJ=$(echo $ALPHA2MIN | tr '[a-z]' '[A-Z]')
LANGUEUTF8=$(echo "$ALPHA2MIN"_"$ALPHA2MAJ".UTF-8)
UTILISATEUR=$(grep 1001 /etc/group | cut -d: -f1)

# Test de la présence d'un utilisateur avec un UID de 1001
if grep -q '1001' /etc/group 1>&2 ; then
	echo -e "\nPersonnalisation du système pour $UTILISATEUR."
else
	echo -e "\nCréation d'un utilisateur avec un UID de 1001."
	adduser -u 1001
fi

# Confirmer la proposition de la langue pour les locales UTF-8
read -p "Activer la locale $LANGUEUTF8 ? [O/n] " REPVAR
if [ "$REPVAR" = "N" ] || [ "$REPVAR" = "n" ] ; then
        echo -n "Entrer le nom de la locale UTF-8 à utiliser: "
        read LANGUEUTF8
        read -p "Utiliser la locale $LANGUEUTF8 ? [O/n] " REPVAR2
        if [ "$REPVAR2" = "N" ] || [ "$REPVAR2" = "n" ] ; then
			echo "Je reviendrai..."
			exit 0
        fi
        echo "$LANGUEUTF8 sera utilisé."
else
        echo "$LANGUEUTF8 sera utilisé."
fi

# MàJ verbeuse avec sauvegarde de l'ancien noyau
test -f /usr/sbin/hbsd-update && hbsd-update -C

read -p "Faire la mise à jour du système de base de HardenedBSD ? [N/o] " REPVAR3
if [ "$REPVAR3" = "O" ] || [ "$REPVAR3" = "o" ] ; then
	test -f /usr/sbin/hbsd-update && hbsd-update -V -K ancienHBSD
fi

# Installer le bureau Mate
env ASSUME_ALWAYS_YES=YES pkg bootstrap
pkg install -fy mate xinit xorg xdg-user-dirs slim slim-themes

# Permettre le démarrage de Mate
cat > /home/$UTILISATEUR/.xinitrc <<EOF
export LANG="$LANGUEUTF8"
export LC_ALL="$LANGUEUTF8"
export LC_MESSAGES="$LANGUEUTF8"
export LC_CTYPE="$LANGUEUTF8"
export LC_COLLATE="$LANGUEUTF8"
exec mate-session
EOF
chown $UTILISATEUR:$UTILISATEUR /home/$UTILISATEUR/.xinitrc

# Personnaliser SLIM
fetch https://github.com/HacKurx/public-sharing/raw/master/files/slim-hardenedbsd.tar.bz2
tar jxvf slim-hardenedbsd.tar.bz2
mv hardenedbsd/ /usr/local/share/slim/themes/hardenedbsd
sed -i -r "s/.*current_theme.*/current_theme hardenedbsd/g" /usr/local/etc/slim.conf
sed -i -r "s/.*simone.*/default_user $UTILISATEUR/g" /usr/local/etc/slim.conf

# Télécharger quelques fonds d'écran
mkdir -p /usr/local/share/backgrounds/hardenedbsd
fetch -o /usr/local/share/backgrounds/hardenedbsd/HardenedBSD-DarkBlue1.png https://github.com/HacKurx/public-sharing/raw/master/files/HardenedBSB-DarkBlue1.png
fetch -o /usr/local/share/backgrounds/hardenedbsd/HardenedBSD-DarkBlue2.png https://github.com/HacKurx/public-sharing/raw/master/files/HardenedBSB-DarkBlue2.png
fetch -o /usr/local/share/backgrounds/hardenedbsd/HardenedBSD-BlueSun.jpg https://github.com/HacKurx/public-sharing/raw/master/files/HardenedBSD-BlueSun.jpg
sed -i -r "s/3C8F25/0B324A/g" /usr/local/share/glib-2.0/schemas/org.mate.background.gschema.xml

# Permettre à l'utilisateur de lancer su, d'éteindre la machine et d'accéder au DRI
pw groupmod wheel -m $UTILISATEUR
pw groupmod operator -m $UTILISATEUR
pw groupmod video -m $UTILISATEUR

# Autoriser l'utilisateur à utiliser sudo (exemple pour octopkg)
echo "$UTILISATEUR ALL=(ALL) ALL" >> /usr/local/etc/sudoers

# Installer les logiciels les plus utilisés
pkg install -fy firefox vlc gimp cups cups-filters system-config-printer gnumeric abiword claws-mail claws-mail-pgp meld octopkg keepassxc
pw groupmod cups -m $UTILISATEUR

# Installer les utilitaires les plus utilisés
pkg install -fy zip unzip unrar p7zip sudo networkmgr seahorse gvfs bash fish nano wget sysinfo hardening-check automount
cp /usr/local/etc/automount.conf.sample /usr/local/etc/automount.conf

# Utiliser bash sur le profil utilisateur
chsh -s /usr/local/bin/bash $UTILISATEUR

# Configuration pour le wifi (à comparer avec networkmgr)
#wpa_passphrase "LAN" "Azertyui" > /etc/wpa_supplicant.conf
sysrc wlans_ath0="wlan0"
sysrc ifconfig_wlan0="WPA SYNCDHCP"

cat >/etc/wpa_supplicant.conf <<EOF
network={
        ssid="LAN"
        psk=c92487af1618e5b7063807302ee26bfb7fdd98d87fd0d9a6f6466c9a704c05a8
}
EOF

# Désactiver MPROTECT pour Firefox
hbsdcontrol pax disable mprotect /usr/local/lib/firefox/firefox
hbsdcontrol pax disable mprotect /usr/local/lib/firefox/plugin-container

# Configuration du système en Français
# Pour firefox: https://addons.mozilla.org/addon/fran%C3%A7ais-language-pack/
cat >>/etc/login.conf <<EOF

french|French Users Accounts:\
       :charset=UTF-8:\
       :lang=$LANGUEUTF8:\
       :tc=default:
EOF

setconfig -f /etc/profile LANG="$LANGUEUTF8"
setconfig -f /etc/profile CHARSET="UTF-8"

cat > /usr/local/etc/X11/xorg.conf.d/10-keyboard.conf <<EOF
Section "InputClass"
        Identifier "Keyboard Defauls"
        #Driver "keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
EndSection
EOF

echo "defaultclass = french" >> /etc/adduser.conf

# Activer les services pour le bureau Mate
sysrc moused_enable=yes dbus_enable=yes hald_enable=yes slim_enable=yes

# Personnaliser les autres services
# Activer "ipv6_privacy=yes" si IPV6 est utilisé
sysrc sendmail_enable=none clear_tmp_enable=yes background_dhclient=yes ipv6_network_interfaces=none

# Optimiser le système pour un usage desktop
setconfig -f /etc/sysctl.conf kern.sched.preempt_thresh=224
setconfig -f /etc/sysctl.conf kern.ipc.shmmax=67108864
setconfig -f /etc/sysctl.conf kern.ipc.shmall=32768
setconfig -f /etc/sysctl.conf vfs.usermount=1

# Diminuer le timeout du menu du boot loader
sysrc -f /boot/loader.conf autoboot_delay=3

# Firewall à regarder avec "ipfw show"
service firewall enable
sysrc firewall_type=workstation
sysrc firewall_myservices="22/tcp"
sysrc firewall_allowservices=any
sysrc firewall_quiet=yes
sysrc firewall_logdeny=yes
service ipfw start

# Activer l'autostart de networkmgr
mkdir -p "/home/$UTILISATEUR/.config/autostart/"
cat > /home/$UTILISATEUR/.config/autostart/networkmgr.desktop  <<EOF
[Desktop Entry]
Type=Application
Exec=networkmgr
Hidden=false
X-MATE-Autostart-enabled=true
Name[fr_FR]=networkmgr
Name=networkmgr
Comment[fr_FR]=networkmgr
Comment=networkmgr
X-MATE-Autostart-Delay=1
EOF
chown -R $UTILISATEUR:$UTILISATEUR "/home/$UTILISATEUR/.config/"
chmod 644 "/home/$UTILISATEUR/.config/autostart/networkmgr.desktop"

# Utiliser NTPdate pour synchroniser l'heure au démarrage sans utiliser le daemon NTP
sysrc ntpd_sync_on_start=no
sysrc ntpdate_enable=yes

# procfs pour l'environnement de bureau MATE
if [ $(grep -q "/proc" "/etc/fstab"; echo $?) == 1 ]; then
	echo "proc            /proc           procfs  rw      0       0" >> /etc/fstab
fi

# Installer le fork de mate-tweak
fetch https://github.com/HacKurx/public-sharing/raw/master/files/station-tweak-0.7.txz
pkg install -fy station-tweak-0.7.txz

# Installer les ports
if [ ! -d "/usr/ports" ]; then
    pkg install -fy git-lite
    git clone --depth=1 https://github.com/HardenedBSD/hardenedbsd-ports.git /usr/ports
fi

# Spécifique à HardenedBSD
pkg install -fy secadm secadm-kmod

FHOSTS=$(sha256 /etc/hosts | awk '{print $4}')

cat > /usr/local/etc/secadm.rules <<EOF
secadm {
  integriforce {
    path: "/etc/hosts",
    hash: "$FHOSTS",
    type: "sha256",
    mode: "hard",
  }
}
EOF

# Attente correction du Bug n°38 pour activation
sysrc secadm_enable=NO
#/usr/local/etc/rc.d/secadm start
#echo ERREUR-SECADM >> "/etc/hosts"
#grep SECADM /var/log/messages /etc/hosts

# Installer les Additions invité VirtualBox ou sinon les microcodes du CPU
if [ $(pciconf -lv | grep -i virtualbox 1>&2 ; echo $?) = "0" ]; then
	pkg install -fy virtualbox-ose-additions
	sysrc vboxguest_enable=yes vboxservice_enable=yes
	sysrc moused_enable=no
else
       pkg install -fy devcpu-data drm-kmod
       service microcode_update enable
       service microcode_update start
fi

# Redémarrage
reboot
