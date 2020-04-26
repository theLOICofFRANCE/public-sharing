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
EXISTS=$(grep "APT::Periodic::Update-Package-Lists \"1\"" /etc/apt/apt.conf.d/20auto-upgrades)
if [ -z "$EXISTS" ]; then
	echo "APT::Periodic::Update-Package-Lists \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
fi

EXISTS=$(grep "APT::Periodic::Unattended-Upgrade \"1\"" /etc/apt/apt.conf.d/20auto-upgrades)
if [ -z "$EXISTS" ]; then
	echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
fi

EXISTS=$(grep "APT::Periodic::AutocleanInterval \"7\"" /etc/apt/apt.conf.d/10periodic)
if [ -z "$EXISTS" ]; then
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

# Désactivez l'accès au shell pour les nouveaux utilisateurs (sans affecter l'utilisateur admin existant).
sed -ie '/^SHELL=/ s/=.*\+/=\/usr\/sbin\/nologin/' /etc/default/useradd
sed -ie '/^DSHELL=/ s/=.*\+/=\/usr\/sbin\/nologin/' /etc/adduser.conf

# Rendre les utilisateurs sans shell visible dans lightdm
# sed -i '/hidden-shells/d' /etc/lightdm/users.conf
# ne marche pas: https://bugs.launchpad.net/ubuntu/+source/lightdm/+bug/833762
# Contournement en forçant la saisi de l'identifiant.
echo "[Seat:*]
#autologin-guest=false
#autologin-user=sysadmin
#autologin-user-timeout=0
greeter-hide-users=true" > /etc/lightdm/lightdm.conf

# Installation de libpam-pwquality 
echo -e "${HIGHLIGHT}Configuration des exigences minimales en matière de mot de passe...${NC}"
apt-get install -f libpam-pwquality

# Créer l'utilisateur standard sans accès (simple) au shell
# Si besoin, faire un "sudo chsh -s /bin/bash USERNAME"
adduser "$ENDUSER"

# Définir quelques profils AppArmor en mode renforcé.
echo -e "${HIGHLIGHT}Configuration de apparmor...${NC}"
aa-enforce /etc/apparmor.d/usr.bin.firefox
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
mkdir -p "/home/$ENDUSER/.config/ubuntu-mate/welcome/"
echo '{"autostart": false, "hide_non_free": false}' > "/home/$ENDUSER/.config/ubuntu-mate/welcome/preferences.json"
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

# Paramètres de verrouillage de l'économiseur d'écran Gnome
echo -e "${HIGHLIGHT}Configuration des paramètres de verrouillage de l'économiseur d'écran Mate...${NC}"
mkdir -p /etc/dconf/db/local.d/locks
echo "[org/mate/desktop/session]
idle-delay=600

[org/mate/screensaver]
lock-enabled=1
lock-delay=0" > /etc/dconf/db/local.d/00_screensaver-lock

echo "/org/mate/desktop/session/idle-delay
/org/mate/screensaver/lock-enabled
/org/mate/screensaver/lock-delay" > /etc/dconf/db/local.d/locks/00_screensaver-lock

dconf update

# Désactiver apport (déclaration d'erreur)
sed -ie '/^enabled=1$/ s/1/0/' /etc/default/apport

sudo -H -u "$ENDUSER" dbus-launch gsettings set com.ubuntu.update-notifier show-apport-crashes false > /dev/null 2>&1

# Correction de certaines permissions dans /var qui sont inscriptibles et exécutables par l'utilisateur standard.
echo -e "${HIGHLIGHT}Configuration des autorisations de répertoire supplémentaires...${NC}"
chmod o-w /var/crash
chmod o-w /var/metrics
chmod o-w /var/tmp

# Mise en place d'un pare-feu sans aucune règle.
echo -e "${HIGHLIGHT}Configuration du pare-feu...${NC}"
ufw enable

echo
echo -e "${HIGHLIGHT}Installation terminée.${NC}"

read -p "Redémarrer maintenant ? [o/n]: " CONFIRM
if [ "$CONFIRM" == "o" ]; then
	reboot
fi
