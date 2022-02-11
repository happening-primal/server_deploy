#!/bin/bash

#  Do your initial server setup which will get you to a root ssh login
#  After that is done, perform the following:
#    nano deploy.sh
#  Copy and paste this text into the new document (deploy.sh) followed by
#    ctrl+X
#    y
#    enter
#  Then, run the script
#    bash deploy.sh
#
#  Follow the prompts / instructions

echo "
 - Run this script as superuser.
"
# Detect Root
if [[ "${EUID}" -ne 0 ]]; then
  echo "This installer needs to be run with superuser privileges." >&2
  exit 1
fi

while true; do
  read -rp "Let's run an update first (hit Enter to continue or ctrl+C t exit...
    (select yes at the two prompts regarding ipv4 and ipv6) " yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter to continue or ctrl+C to exit." ;;
  esac
done

# Update and install some essential apps
apt-get -qq update && apt-get -y -qq upgrade  && apt-get -y -qq dist-upgrade
# Install essential apps
apt-get install -y -qq nano wget unattended-upgrades apt-listchanges libpam-google-authenticator
apt-get install -y -qq tmux bleachbit iptables-persistent fail2ban
#  Whoogle - https://hub.docker.com/r/benbusby/whoogle-search#g-manual-docker
#  Install dependencies
apt-get install -y -qq libcurl4-openssl-dev libssl-dev
# Remove some unused applications that may pose as an attack surface
apt purge -y -qq telnet postfix tcpdump nmap-ncat wpa_supplicant avahi-daemon
# Clean up
apt -y -qq autoremove 
apt -y -qq autoclean

# Add automated cleanup using bleachbit
echo "
Now installing a cron job to clean up the system automatically
using bleachbit.  Runs once a month.  

"
#while true; do
#  read -rp "Hit Enter to continue or ctrl+C to exit..." yn
#  case $yn in
#    "") break ;;
#    *) echo "Please hit Enter to continue or ctrl+C to exit." ;;
#  esac
#done

(crontab -l 2>/dev/null || true; echo "0 0 1 * * bleachbit --list | grep -E \"[a-z0-9_\-]+\.[a-z0-9_\-]+\" | xargs bleachbit --clean") | crontab -

echo "

"

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
Succesfully created new user $USR_NAME.  We will now change the root password and then lock the root account...
"

# Chenge the root password to something secure
  passwd root

# Lock the root account
  sudo passwd -l root

# Delete this script so that the root files system is returned to it's original state
rm deploy.sh

while true; do
  read -rp "
  Let's do an initial clean up using bleachbit before we exit (hit Enter to continue or ctrl+C t exit)..." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter to continue or ctrl+C to exit." ;;
  esac
done

echo "
"

bleachbit --list | grep -E "[a-z0-9_\-]+\.[a-z0-9_\-]+" | xargs  bleachbit --clean

echo "Now exit this shell by typing 'exit' and then re-log on using:

    'ssh $USR_NAME"@""$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"'

After you get logged back in using the above, with the password that you set for the new user,
create and run the setup.sh.
"
exit 5
