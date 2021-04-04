#!/bin/sh

# Installer le bureau Mate
pkg install -fy mate xinit xorg nano wget

# Permettre le démarrage de Mate
pw groupmod wheel -m loic
cat > /home/loic/.xinitrc <<EOF
export LANG="fr_FR.UTF-8"
export LC_ALL="fr_FR.UTF-8"
export LC_MESSAGES="fr_FR.UTF-8"
exec mate-session
EOF
chown loic:loic /home/loic/.xinitrc

# Installer les logiciels les plus utilisés
pkg install -fy firefox vlc gimp cups system-config-printer xdg-user-dirs zip unzip gnumeric abiword sylpheed octopkg sudo meld wifimgr seahorse gvfs bash

# Utiliser bash sur le profil utilisateur
chsh -s /usr/local/bin/bash loic

#Configuration pour wifimgr (à comparer avec networkmgr)
cat >>/etc/rc.conf <<EOF
wlans_ath0=wlan0
ifconfig_wlan0="WPA DHCP"
EOF

# Autoriser loic à utiliser sudo (pour octopkg)
echo "loic ALL=(ALL) ALL" >> /usr/local/etc/sudoers

# Désactiver MPROTECT pour Firefox
hbsdcontrol pax disable mprotect /usr/local/lib/firefox/firefox
hbsdcontrol pax disable mprotect /usr/local/lib/firefox/plugin-container

# Configuration du système en Français
cat >>/etc/login.conf <<EOF

french|French Users Accounts:\
       :charset=UTF-8:\
       :lang=fr_FR.UTF-8:\
       :tc=default:
EOF

cat > /usr/local/etc/X11/xorg.conf.d/10-keyboard.conf <<EOF
Section "InputClass"
        Identifier "Keyboard Defauls"
        Driver "keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "fr"
EndSection
EOF

echo "defaultclass = french" >> /etc/adduser.conf

# Permettre aux utilisateurs de monter des périphériques
echo "vfs.usermount=1" >> /etc/sysctl.conf

# Activer les services pour le bureau Mate
sysrc moused_enable=yes dbus_enable=yes hald_enable=yes slim_enable=yes

# Installer le fork de mate-tweak
wget http://pkg.fr.ghostbsd.org/stable/FreeBSD:12:amd64/latest/All/station-tweak-0.7.txz
pkg install -fy station-tweak-0.7.txz
