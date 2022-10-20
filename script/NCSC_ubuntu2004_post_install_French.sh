#!/bin/bash
HIGHLIGHT='\033[1;32m'
NC='\033[0m'

function promptPassphrase {
	PASS=""
	PASSCONF=""
	while [ -z "$PASS" ]; do
		read -s -p "Mot de passe: " PASS
		echo ""
	done
	
	while [ -z "$PASSCONF" ]; do
		read -s -p "Confirmer le mot de passe: " PASSCONF
		echo ""
	done
	echo ""
}

function getPassphrase {
	promptPassphrase
	while [ "$PASS" != "$PASSCONF" ]; do
		echo "Les mots de passe ne correspondent pas, réessayez..."
		promptPassphrase
	done
}

if [[ $UID -ne 0 ]]; then
 echo "Ce script doit être exécuté en tant que root (avec sudo)."
 exit 1
fi

# Obtenez l'utilisateur admin.
users=($(ls /home))
echo "Utilisateurs existants:"
echo
for index in ${!users[*]}
do
	echo -e "\t[$index]: " ${users[$index]}
done
echo

while [ -z "$SELECTION" ]; do read -p "Veuillez sélectionner l'utilisateur que vous avez créé lors de l'installation d'Ubuntu: " SELECTION; done
ADMINUSER=${users[$SELECTION]}
if [ -z "$ADMINUSER" ]; then
	echo "Utilisateur non valide sélectionné. Veuillez relancer le script."
	exit
fi

# Obtenez le nom d'utilisateur pour l'utilisateur principal.
echo
echo "Veuillez entrer un nom d'utilisateur pour l'utilisateur principal de l'appareil qui sera créé par ce script."
while [ -z "$ENDUSER" ]; do read -p "Nom d'utilisateur pour l'utilisateur principal de l'appareil: " ENDUSER; done
if [ -d "/home/$ENDUSER" ]; then
	if [ "$ENDUSER" == "$ADMINUSER" ]; then
		echo "L'utilisateur principal ne peut pas être le même que l'utilisateur admin."
		exit
	fi

	read -p "Le nom d'utilisateur que vous avez saisi existe déjà. Voulez-vous continuer ? [o/n]: " CONFIRM
	if [ "$CONFIRM" != "o" ]; then
		exit
	fi
fi

echo "Si vous n'utilisez pas les dépôts Internet par défaut, vous devez le configurer avant d'exécuter ce script."
echo "Vous devez également disposer d'une connexion réseau active avec les dépôts."
read -p "Continuer ? [o/n]: " CONFIRM
if [ "$CONFIRM" != "o" ]; then
 exit
fi

echo -e "${HIGHLIGHT}Mises à jour du système...${NC}"
# Réactualiser.
apt-get update
# Mise à jour.
apt-get dist-upgrade -y
# Retirer les paquets.
apt-get remove -y popularity-contest
# Et installer les paquets nécessaires.
apt-get install -y apparmor-profiles apparmor-utils auditd 

# Configuration du montage et de grub. Nous devons nous assurer que le script est lancé pour la première fois.
echo -e "${HIGHLIGHT}Configuration du fstab...${NC}"
read -p "Est-ce la première fois que vous exécutez le script de post-installation ? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
	# Mise à jour du fstab.
	echo -e "${HIGHLIGHT}Écriture de la configuration fstab...${NC}"
	sed -ie '/\s\/home\s/ s/defaults/defaults,noexec,nosuid,nodev/' /etc/fstab
	EXISTS=$(grep "/tmp/" /etc/fstab)
	if [ -z "$EXISTS" ]; then
		echo "none /tmp tmpfs rw,noexec,nosuid,nodev 0 0" >> /etc/fstab
	else
		sed -ie '/\s\/tmp\s/ s/defaults/defaults,noexec,nosuid,nodev/' /etc/fstab
	fi
	echo "none /run/shm tmpfs rw,noexec,nosuid,nodev 0 0" >> /etc/fstab
	# Relier /var/tmp à /tmp pour appliquer les mêmes options de montage lors du démarrage du système
 	echo "/tmp /var/tmp none bind 0 0" >> /etc/fstab
	# Rendre temporairement le répertoire /tmp exécutable avant d'exécuter apt-get et supprimer le drapeau d'exécution 
	# par la suite. En effet, apt écrit parfois des fichiers dans /tmp et les exécute à partir de là.
	echo -e "DPkg::Pre-Invoke{\"mount -o remount,exec /tmp\";};\nDPkg::Post-Invoke {\"mount -o remount /tmp\";};" >> /etc/apt/apt.conf.d/99tmpexec
	chmod 644 /etc/apt/apt.conf.d/99tmpexec
fi

# Définir le mot de passe de grub.
echo -e "${HIGHLIGHT}Configuration de grub...${NC}"
echo "Veuillez entrer un mot de passe sysadmin pour grub..."
getPassphrase

echo "set superusers=\"sysadmin\"" >> /etc/grub.d/40_custom
echo -e "$PASS\n$PASS" | grub-mkpasswd-pbkdf2 | tail -n1 | awk -F" " '{print "password_pbkdf2 sysadmin " $7}' >> /etc/grub.d/40_custom
sed -ie '/echo "menuentry / s/echo "menuentry /echo "menuentry --unrestricted /' /etc/grub.d/10_linux
sed -ie '/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/"$/ module.sig_enforce=yes"/' /etc/default/grub
echo "GRUB_SAVEDEFAULT=false" >> /etc/default/grub
update-grub

# Définir les autorisations pour le répertoire personnel de l'utilisateur admin.
chmod 700 "/home/$ADMINUSER"

# Configurer les mises à jour automatiques.
echo -e "${HIGHLIGHT}Configuration des mises à jour automatiques...${NC}"
EXISTS=$(grep "APT::Periodic::Update-Package-Lists" /etc/apt/apt.conf.d/20auto-upgrades)
if [ -z "$EXISTS" ]; then
	sed -i '/APT::Periodic::Update-Package-Lists/d' /etc/apt/apt.conf.d/20auto-upgrades
	echo "APT::Periodic::Update-Package-Lists \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
fi

EXISTS=$(grep "APT::Periodic::Unattended-Upgrade" /etc/apt/apt.conf.d/20auto-upgrades)
if [ -z "$EXISTS" ]; then
	sed -i '/APT::Periodic::Unattended-Upgrade/d' /etc/apt/apt.conf.d/20auto-upgrades
	echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
fi

EXISTS=$(grep "APT::Periodic::AutocleanInterval" /etc/apt/apt.conf.d/10periodic)
if [ -z "$EXISTS" ]; then
	sed -i '/APT::Periodic::AutocleanInterval/d' /etc/apt/apt.conf.d/10periodic
	echo "APT::Periodic::AutocleanInterval \"7\";" >> /etc/apt/apt.conf.d/10periodic
fi

chmod 644 /etc/apt/apt.conf.d/20auto-upgrades
chmod 644 /etc/apt/apt.conf.d/10periodic

# Empêcher l'utilisateur standard d'exécuter su.
echo -e "${HIGHLIGHT}Configure l'exécution de su...${NC}"
dpkg-statoverride --update --add root adm 4750 /bin/su

# Protéger les répertoires personnels des utilisateurs.
echo -e "${HIGHLIGHT}Configuration des répertoires personnels et de l'accès au shell...${NC}"
sed -ie '/^DIR_MODE=/ s/=[0-9]*\+/=0700/' /etc/adduser.conf
sed -ie '/^UMASK\s\+/ s/022/077/' /etc/login.defs

read -p "Configuration du shell de l'utilisateur :
[0] Définissez le shell à /bin/passwd (permet de changer de mot de passe, en contournant le bug de Gnome) (par défaut)
[1] Définissez le shell à /sbin/nologin (empêche l'accès au shell)
[2] Définissez le shell à /bin/bash (permet l'accès au shell bash)
" LEVEL
	if [ "$LEVEL" == "1" ]; then
		# Désactivez l'accès au shell pour les nouveaux utilisateurs (sans affecter l'utilisateur admin existant).
		sed -ie '/^SHELL=/ s/=.*\+/=\/usr\/sbin\/nologin/' /etc/default/useradd
		sed -ie '/^DSHELL=/ s/=.*\+/=\/usr\/sbin\/nologin/' /etc/adduser.conf
	elif [ "$LEVEL" == "2" ]; then
		# Conserver l'accès shell pour les nouveaux utilisateurs (sans affecter l'utilisateur admin existant).
		sed -ie '/^SHELL=/ s/=.*\+/=\/bin\/bash/' /etc/default/useradd
		sed -ie '/^DSHELL=/ s/=.*\+/=\/bin\/bash/' /etc/adduser.conf	
	else
		# Conserver l'accès au shell pour les nouveaux utilisateurs afin d'éviter un bug de Gnome concernant les mots de passe (sans affecter l'utilisateur admin existant). Option par défaut.
		sed -ie '/^SHELL=/ s/=.*\+/=\/bin\/passwd/' /etc/default/useradd
		sed -ie '/^DSHELL=/ s/=.*\+/=\/bin\/passwd/' /etc/adduser.conf		
	fi

# Installation de libpam-pwquality 
echo -e "${HIGHLIGHT}Configuration des exigences minimales en matière de mot de passe...${NC}"
apt-get install -f libpam-pwquality

# Créer l'utilisateur standard.
adduser "$ENDUSER"

# Définir quelques profils AppArmor en mode renforcé.
echo -e "${HIGHLIGHT}Configuration de apparmor...${NC}"
aa-enforce /etc/apparmor.d/usr.bin.firefox || aa-enforce /usr/share/apparmor/extra-profiles/usr.lib.firefox.firefox
aa-enforce /etc/apparmor.d/usr.sbin.avahi-daemon
aa-enforce /etc/apparmor.d/usr.sbin.dnsmasq
aa-enforce /etc/apparmor.d/bin.ping
aa-enforce /etc/apparmor.d/usr.sbin.rsyslogd

# Mise en place de l'audit.
echo -e "${HIGHLIGHT}Configuration de l'audit du système...${NC}"
if [ ! -f /etc/audit/rules.d/tmp-monitor.rules ]; then
echo "# Surveiller les changements et les exécutions au sein de /tmp
-w /tmp/ -p wa -k tmp_write
-w /tmp/ -p x -k tmp_exec" > /etc/audit/rules.d/tmp-monitor.rules
fi

if [ ! -f /etc/audit/rules.d/admin-home-watch.rules ]; then
echo "# Surveiller l'accès de l'administrateur aux répertoires /home
-a always,exit -F dir=/home/ -F uid=0 -C auid!=obj_uid -k admin_home_user" > /etc/audit/rules.d/admin-home-watch.rules
fi
augenrules
systemctl restart auditd.service

# Configurez les paramètres de la fenêtre contextuelle "Bienvenue" lors de la première connexion.
echo -e "${HIGHLIGHT}Configuration des paramètres de la première connexion de l'utilisateur...${NC}"
mkdir -p "/home/$ENDUSER/.config"
echo yes > "/home/$ENDUSER/.config/gnome-initial-setup-done"
chown -R "$ENDUSER:$ENDUSER" "/home/$ENDUSER/.config"
sudo -H -u "$ENDUSER" ubuntu-report -f send no

# Désactiver les services de rapport des erreurs
echo -e "${HIGHLIGHT}Configuration du signalement des erreurs...${NC}"
systemctl stop apport.service
systemctl disable apport.service
systemctl mask apport.service

systemctl stop whoopsie.service
systemctl disable whoopsie.service
systemctl mask whoopsie.service

if [ ! -f "/etc/dconf/profile/user" ]; then
	touch /etc/dconf/profile/user
fi

EXISTS=$(grep "user-db:user" /etc/dconf/profile/user)
if [ -z "$EXISTS" ]; then
	echo "user-db:user" >> /etc/dconf/profile/user
fi

EXISTS=$(grep "system-db:local" /etc/dconf/profile/user)
if [ -z "$EXISTS" ]; then
	echo "system-db:local" >> /etc/dconf/profile/user
fi

# Désactiver optionnellement le bluetooth
read -p "Voulez-vous désactiver le bluetooth pour tous les utilisateurs ? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
systemctl disable bluetooth.service
fi

# Paramètres de verrouillage de l'économiseur d'écran Gnome
echo -e "${HIGHLIGHT}Configuration des paramètres de verrouillage de l'économiseur d'écran Gnome...${NC}"
mkdir -p /etc/dconf/db/local.d/locks
echo "[org/gnome/login-screen]
disable-user-list=true

[org/gnome/desktop/session]
idle-delay=600

[org/gnome/desktop/screensaver]
lock-enabled=true
lock-delay=0
ubuntu-lock-on-suspend=true" > /etc/dconf/db/local.d/00_custom-lock

echo "/org/gnome/desktop/session/idle-delay
/org/gnome/desktop/screensaver/lock-enabled
/org/gnome/desktop/screensaver/lock-delay
/org/gnome/desktop/screensaver/ubuntu-lock-on-suspend
/org/gnome/login-screen/disable-user-list" > /etc/dconf/db/local.d/locks/00_custom-lock

# Supprimer la liste des utilisateurs de la page de connexion
sed -ie '/^\# disable-user-list\=true/ s/#//' /etc/gdm3/greeter.dconf-defaults

read -p "Voulez-vous désactiver les notifications de l'écran de verrouillage ? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
echo "
[org/gnome/desktop/notifications]
show-in-lock-screen=false

[org/gnome/login-screen]
banner-message-enable=false" >> /etc/dconf/db/local.d/00_custom-lock

echo "/org/gnome/desktop/notifications/show-in-lock-screen
/org/gnome/login-screen/banner-message-enable" >> /etc/dconf/db/local.d/locks/00_custom-lock

fi

# Désactiver les services de localisation en option
read -p "Voulez-vous désactiver les services de localisation ? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
echo "
[org/gnome/system/location]
max-accuracy-level='country'
enabled=false" >> /etc/dconf/db/local.d/00_custom-lock

echo "/org/gnome/system/location/max-accuracy-level
/org/gnome/system/location/enabled" >> /etc/dconf/db/local.d/locks/00_custom-lock
fi

# Autres paramètres de confidentialité
echo "
[org/gnome/desktop/privacy]
report-technical-problems=false" >> /etc/dconf/db/local.d/00_custom-lock
echo "/org/gnome/desktop/privacy/report-technical-problems" >> /etc/dconf/db/local.d/locks/00_custom-lock

# Configuration facultative des restrictions USB (situé dans org/gnome/desktop/privacy)
read -p "Voulez-vous limiter l'utilisation de l'USB? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
echo "usb-protection=true" >> /etc/dconf/db/local.d/00_custom-lock
read -p "Définir le niveau de restriction :
[0] bloquer l'USB sur l'écran de verrouillage (par défaut)
[1] toujours bloquer l'USB
" LEVEL
	if [ "$LEVEL" == "1" ]; then
		echo "Réglage du mode de verrouillage USB sur : always"
		echo "usb-protection-level='always'" >> /etc/dconf/db/local.d/00_custom-lock
		echo "/org/gnome/desktop/privacy/usb-protection-level" >> /etc/dconf/db/local.d/locks/00_custom-lock
		if [ ! -f "/etc/modprobe.d/blacklist.conf" ]; then
			touch /etc/modprobe.d/blacklist.conf
		fi
		if [ ! -f "/etc/rc.local" ]; then
			touch /etc/rc.local
			echo "#!/bin/bash" >> /etc/rc.local
		fi
		echo "blacklist usb_storage
blacklist uas" >> /etc/modprobe.d/blacklist.conf
		echo "modprobe -r uas
modprobe -r usb_storage" >> /etc/rc.local
		rmmod usb_storage
	else
		echo "Réglage du mode de verrouillage USB sur : lockscreen"
		echo "usb-protection-level='lockscreen'" >> /etc/dconf/db/local.d/00_custom-lock
		echo "/org/gnome/desktop/privacy/usb-protection-level" >> /etc/dconf/db/local.d/locks/00_custom-lock
	fi
fi

dconf update

# Corrige les permissions de dconf, sinon les verrous d'options ne s'appliquent pas lors des exécutions ultérieures du script
chmod 644 -R /etc/dconf/db/
chmod a+x /etc/dconf/db/local.d/locks
chmod a+x /etc/dconf/db/local.d
chmod a+x /etc/dconf/db

# Désactiver apport (déclaration d'erreur)
sed -ie '/^enabled=1$/ s/1/0/' /etc/default/apport

apt-get install -y dbus-x11
sudo -H -u "$ENDUSER" dbus-launch gsettings set com.ubuntu.update-notifier show-apport-crashes false

# Correction de certaines permissions dans /var qui sont inscriptibles et exécutables par l'utilisateur standard.
echo -e "${HIGHLIGHT}Configuration des autorisations de répertoire supplémentaires...${NC}"
chmod o-w /var/crash
chmod o-w /var/metrics
chmod o-w /var/tmp

# Mise en place d'un pare-feu sans aucune règle.
echo -e "${HIGHLIGHT}Configuration du pare-feu…  ${NC}"
ufw enable	


echo -e "${HIGHLIGHT}Installation terminée.${NC}"

read -p "Redémarrer maintenant ? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
	reboot
fi
