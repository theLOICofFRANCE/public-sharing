#!/bin/sh

# Installer Mate
pkg install mate xinit xorg nano wget

# Permettre son démarrage
pw groupmod wheel -m loic
cat > /home/loic/.xinitrc <<EOF
export LANG="fr_FR.UTF-8"
export LC_ALL="fr_FR.UTF-8"
export LC_MESSAGES="fr_FR.UTF-8"
exec mate-session
EOF
chown loic:loic /home/loic/.xinitrc

# Installer les logiciels
pkg install firefox vlc gimp cups system-config-printer xdg-user-dirs zip unzip gnumeric abiword sylpheed octopkg sudo meld wifimgr seahorse

#Configuration pour wifimgr (à comparer avec networkmgr)
cat >>/etc/rc.conf <<EOF
wlans_ath0=wlan0
ifconfig_wlan0="WPA DHCP"
EOF

# Autoriser loic à utiliser sudo (pour octopkg)
echo "loic ALL=(ALL) ALL" >> /usr/local/etc/sudoers

# Désactiver MPROTECT
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

# Permettre le montage automatique des clés USB sous Mate
service dbus enable

# Installer le fork de mate-tweak
wget http://pkg.fr.ghostbsd.org/stable/FreeBSD:12:amd64/latest/All/station-tweak-0.7.txz
pkg install station-tweak-0.7.txz
