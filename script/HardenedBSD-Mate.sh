#!/bin/sh

# Installer le bureau Mate
pkg update -f
pkg install -fy mate xinit xorg xdg-user-dirs slim slim-themes

# Permettre le démarrage de Mate
cat > /home/loic/.profile <<EOF
export LANG="fr_FR.UTF-8"
export LC_ALL="fr_FR.UTF-8"
export LC_MESSAGES="fr_FR.UTF-8"
export LC_CTYPE="fr_FR.UTF-8"
export LC_COLLATE="fr_FR.UTF-8"
EOF
echo "exec mate-session" > /home/loic/.xinitrc
chown loic:loic /home/loic/.xinitrc /home/loic/.profile

# Personnaliser SLIM
sed -i -r 's/.*current_theme.*/current_theme rainbow/g' /usr/local/etc/slim.conf
sed -i -r 's/.*simone.*/default_user loic/g' /usr/local/etc/slim.conf

# Permettre à Loic de lancer su, d'éteindre la machine et d'accéder au DRI
pw groupmod wheel -m loic
pw groupmod operator -m loic
pw groupmod video -m loic

# Autoriser loic à utiliser sudo (exemple pour octopkg)
echo "loic ALL=(ALL) ALL" >> /usr/local/etc/sudoers

# Installer les logiciels les plus utilisés
pkg install -fy firefox vlc gimp cups cups-filters system-config-printer gnumeric abiword claws-mail claws-mail-pgp meld octopkg
pw groupmod cups -m loic

# Installer les utilitaires les plus utilisés
pkg install -fy zip unzip unrar p7zip sudo networkmgr seahorse gvfs bash nano wget sysinfo hardening-check automount
cp /usr/local/etc/automount.conf.sample /usr/local/etc/automount.conf

# Utiliser bash sur le profil utilisateur
chsh -s /usr/local/bin/bash loic

# Configuration pour le wifi (à comparer avec networkmgr)
# wpa_passphrase "LAN" "123456" > /etc/wpa_supplicant.conf
cat >>/etc/rc.conf <<EOF
wlans_ath0=wlan0
ifconfig_wlan0="WPA SYNCDHCP"
EOF

# Désactiver MPROTECT pour Firefox
hbsdcontrol pax disable mprotect /usr/local/lib/firefox/firefox
hbsdcontrol pax disable mprotect /usr/local/lib/firefox/plugin-container

# Configuration du système en Français
# Pour firefox: https://addons.mozilla.org/addon/fran%C3%A7ais-language-pack/
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

# Personnaliser les autres services
sysrc sendmail_enable=none clear_tmp_enable=yes background_dhclient=yes ipv6_privacy=yes

# Optimiser le scheduler pour un usage desktop
sysrc -f /etc/sysctl.conf kern.sched.preempt_thresh=224

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

# Mise à jour du microcode CPU
pkg install -fy devcpu-data
service microcode_update enable
service microcode_update start

# Activer l'autostart de networkmgr
mkdir -p '/home/loic/.config/autostart/'
cat > /home/loic/.config/autostart/networkmgr.desktop  <<EOF
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
chown -R loic:loic '/home/loic/.config/autostart/'
chmod 644 '/home/loic/.config/autostart/networkmgr.desktop'

# Utiliser NTPdate pour synchroniser l'heure au démarrage sans utiliser le daemon NTP
sysrc ntpd_sync_on_start=no
sysrc ntpdate_enable=yes

# procfs pour l'environnement de bureau MATE
echo "proc            /proc           procfs  rw      0       0" >> /etc/fstab

# Installer le fork de mate-tweak
wget https://github.com/HacKurx/public-sharing/raw/master/files/station-tweak-0.7.txz
pkg install -fy station-tweak-0.7.txz
