#!/bin/bash

echo "
 - Run this script as superuser.
"
# Detect Root
if [[ "${EUID}" -ne 0 ]]; then
  echo "This installer needs to be run with superuser privileges." >&2
  exit 1
fi

while true; do
  read -rp "Let's run and update first (hit Enter to continue or ctrl+C t exit)..." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter to continue or ctrl+C to exit." ;;
  esac
done

echo "
"

#Update and install some essential apps
apt-get update && apt-get upgrade -y  && apt-get dist-upgrade -y
# Install essential apps
apt-get install nano -y
apt-get install wget -y
apt-get install unattended-upgrades apt-listchanges -y
apt-get install libpam-google-authenticator -y
apt-get install tmux -y
apt-get install bleachbit -y
apt-get install iptables-persistent -y
apt-get install fail2ban -y
# Remove some unused applications that may pose as an attack surface
apt purge postfix -y
apt purge telnet -y
apt purge tcpdump -y
apt purge nmap-ncat -y
apt purge wpa_supplicant -y
apt purge avahi-daemon -y
# Clean up
apt-get autoremove -y
apt-get autoclean -y

#systemctl reload postfix

# Add automated cleanup using bleachbit
echo "
Let's install a cron job to clean up the system automatically
using bleachbit.  Copy this text (without the '):

  '0 0 1 * * bleachbit --list | grep -E \"[a-z0-9_\-]+\.[a-z0-9_\-]+\" | xargs  bleachbit --clean'
"
while true; do
  read -rp "and then hit Enter to continue or ctrl+C to exit..." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter to continue or ctrl+C to exit." ;;
  esac
done

crontab -e

#  Add firewall rules

#  Create a new user
  while true; do
    read -rp "Enter your new user name: " USR_NAME
    if [[ -z "${USR_NAME}" ]]; then
      echo "Please enter your new user name."
      continue
    fi
    break
  done

  useradd -G sudo -m $USR_NAME -s /bin/bash
  passwd $USR_NAME

#  Lock the root account
echo "

Change the root password and then lock the root account...
"

# Chenge the root password to something secure
  passwd root

# Lock the root account
  sudo passwd -l root

rm deploy.sh


echo "

"

while true; do
  read -rp "Let's do an initial clean up using bleachbit before we exit (hit Enter to continue or ctrl+C t exit)..." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter to continue or ctrl+C to exit." ;;
  esac
done

bleachbit --list | grep -E "[a-z0-9_\-]+\.[a-z0-9_\-]+" | xargs  bleachbit --clean


echo "

Now re-log on using:

    'ssh $USR_NAME"@""$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"'
"
exit 5
