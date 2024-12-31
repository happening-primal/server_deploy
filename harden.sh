#!/bin/bash

# How to Make Your Own VPN (And Why You Would Want to) - https://youtu.be/gxpX_mubz2A
# Wolfgang's Channel


# sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config && sudo cp /etc/pam.d/sshd.bak /etc/pam.d/sshd && sudo systemctl restart sshd
# sudo rm install.sh && sudo nano install.sh


echo "
 - Run this script as superuser.
"
# Detect Root
if [[ "${EUID}" -ne 0 ]]; then
  echo "This installer needs to be run with superuser privileges." >&2
  exit 1
fi

while true; do
  read -rp "Let's run an update first (hit enter to continue)..." yn
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
apt-get install -y -qq apt-transport-https ca-certificates curl software-properties-common
apt-get install - -qq apt-utils htop net-utils
#  Whoogle - https://hub.docker.com/r/benbusby/whoogle-search#g-manual-docker
#  Install dependencies
apt-get install -y -qq libcurl4-openssl-dev libssl-dev
# Remove some unused applications that may pose as an attack surface
apt purge -y -qq telnet postfix tcpdump nmap-ncat wpa_supplicant avahi-daemon
# Clean up
apt -y -qq autoremove 
apt -y -qq autoclean

echo "
You need to have an ssh key on your current computer.  If you don't have one, or don't even know what one
is, see this page - https://www.ssh.com/academy/ssh/keygen.  Recommend you use ecdsa for the most up-to-date
security.  The creation command is:

     'ssh-keygen -f <file location/name> -t ecdsa -b 521'
       or for windows using powershell
     'type C:\Users\your_userid\.ssh\linodetest-key.pub | ssh fdgh1567@212.71.252.125 \"cat >> .ssh/authorized_keys\"'
     
     Example:  
     'ssh-keygen -f ~/.ssh/ecdsa-key -t ecdsa -b 521'
       or for windows using powershell
     ''

After you are sure you have a key (don't proceed until you do!), open a new terminal window and type:

    'ssh-copy-id" $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"@"$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"'
"

while true; do
  read -rp "Return to this window when the proccess is complete and then hit Enter or ctrl+C to exit." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

while true; do
  read -rp "
Enter your desired ssh port number (default is 22) or hit Enter to exit this script. " newport
  case $newport in
    "") newport=22 break ;;
    *) break ;;
  esac
done

#Make a copy of sshd_config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i 's/\#Port 22/Port '"$newport"'/g' /etc/ssh/sshd_config
sed -i 's/Port 22/Port '"$newport"'/g' /etc/ssh/sshd_config

sed -i 's/\#PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config

sed -i 's/\#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

sed -i 's/\#PermitEmptyPasswords yes/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -i 's/PermitEmptyPasswords yes/PermitEmptyPasswords no/g' /etc/ssh/sshd_config

systemctl restart sshd

echo "
Now try to log on using in a new terminal using the below:

    'ssh -i ~/.ssh/id_rsa" $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"@"$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)" -p "$newport"'
"


while true; do
  read -rp "Hit Enter when the above step is complete." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

# Do this after installing google authenticator
# Use the command 'google-authenticator'
# Anser yes to all the questions except the one
# about multiple uses of the toekn and the one about 30 second tokens.
# Make a backup of the 'emergancy scratch codes' and then scan the QR
# code or enter the secret key into your authenticator app.

echo "
Next we're going to set up TOTP.  Be sure to scan the QR code or enter the TOTP code
(new secret key) into your authenticator and also store the emergency scratch codes 
in your password manager.  Answer yes to everything except the disalowing multiple 
uses and 30 second token (i.e. y, y, n, n, y).  Save the 'secret key' and the 
'scratch codes'!
"

while true; do
  read -rp "Hit Enter or ctrl+C to exit." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

apt-get install libpam-google-authenticator -y -qq

su $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root') -c google-authenticator #cannot run as root

#Make a copy of sshd
cp /etc/pam.d/sshd /etc/pam.d/sshd.bak

sed -i 's/\@include common-auth/\# \@include common-auth/g' /etc/pam.d/sshd
sed -i 's/\#\# \@include common-auth/\# \@include common-auth/g' /etc/pam.d/sshd
sed -i 's/\#\# \@include common-auth/\# \@include common-auth/g' /etc/pam.d/sshd

sed -i 's/auth required pam_google_authenticator.so//g' /etc/pam.d/sshd
echo 'auth required pam_google_authenticator.so' | tee -a /etc/pam.d/sshd

sed -i 's/\#ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config

sed -i 's/\#UsePAM no/UsePAM yes/g' /etc/ssh/sshd_config
sed -i 's/UsePAM no/UsePAM yes/g' /etc/ssh/sshd_config

sed -i 's/AuthenticationMethods publickey,password publickey,keyboard-interactive//g' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM yes\nAuthenticationMethods publickey,password publickey,keyboard-interactive/g' /etc/ssh/sshd_config

systemctl restart sshd

echo "
Now try to log on using in a new terminal using the below:

    'ssh -i ~/.ssh/id_rsa" $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"@"$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1) "-p "$newport"'
"

while true; do
  read -rp "Hit Enter when the above step is complete." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

echo "
Creating firewall rules...
"
#  https://www.cyberciti.biz/tips/linux-iptables-examples.html
#  https://www.perturb.org/display/1186_Linux_Block_DNS_queries_for_specific_zone_with_IPTables.html
#  https://discourse.pi-hole.net/t/amplification-iptables-rules/6777/12
# Some usefull iptables commands
#  List entries:
#  	sudo iptables -L -n -v

#  Delete an entry:
#  	sudo iptables -L INPUT -n --line-numbers
#  	sudo iptables -D INPUT 3

# Now for the sake add rate limit general (avoid flooding)
 iptables -N udp-flood
 iptables -A udp-flood -m limit --limit 4/second --limit-burst 4 -j RETURN
 iptables -A udp-flood -j DROP
 iptables -A INPUT -i eth0 -p udp -j udp-flood
 iptables -A INPUT -i eth0 -f -j DROP

# These comes from freek's blog post
 iptables -A INPUT -p udp --dport 53 -m string --from 40 --algo bm --hex-string '|0000FF0001|' -m recent --set --name dnsanyquery
 iptables -A INPUT -p udp --dport 53 -m string --from 40 --algo bm --hex-string '|0000FF0001|' -m recent --name dnsanyquery --rcheck --seconds 60 --hitcount 3 -j DROP
 iptables -A INPUT -p tcp --dport 53 -m string --from 52 --algo bm --hex-string '|0000FF0001|' -m recent --set --name dnsanyquery
 iptables -A INPUT -p tcp --dport 53 -m string --from 52 --algo bm --hex-string '|0000FF0001|' -m recent --name dnsanyquery --rcheck --seconds 60 --hitcount 3 -j DROP

# Open ports we need for web servers
 iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
 iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
 iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
 iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT

# Open ssh port 
iptables -t filter -A OUTPUT -p tcp --dport $newport -j ACCEPT
iptables -t filter -A INPUT -p tcp --dport $newport -j ACCEPT
iptables -t filter -A OUTPUT -p udp --dport $newport -j ACCEPT
iptables -t filter -A INPUT -p udp --dport $newport -j ACCEPT

# Allow dns requests and other ports for pihole - https://docs.pi-hole.net/main/prerequisites/
iptables -A INPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -p udp --dport 67 -j ACCEPT
iptables -A INPUT -p tcp --dport 67 -j ACCEPT
iptables -A OUTPUT -p udp --dport 67 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 67 -j ACCEPT
iptables -I INPUT 1 -p udp --dport 67:68 --sport 67:68 -j ACCEPT
iptables -I INPUT 1 -p tcp -m tcp --dport 4711 -i lo -j ACCEPT
iptables -I INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

#  Specific requests to block dns requests by name.  The number (02, 08, 09) represents the count of characters
#  before the string.
#  |Type | Code| |------------| |Any | 00ff| |A | 0011| |CNAME | 0005| |MX | 000f| |AAAA | 001c| |NS | 0002| |SOA | 0006|
iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|02|sl|00|" --algo bm -j DROP -m comment --comment 'sl'
iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|09|peacecorp|03|org" --algo bm -j DROP -m comment --comment 'peacecorp.org'
iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|08|pizzaseo|03|com" --algo bm -j DROP -m comment --comment 'pizzaseo.com'
iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|07|version|04|bind|0000ff|" --algo bm -j DROP -m comment --comment 'version.bind'

iptables -A FORWARD -p tcp --dport 53 -m string --algo kmp --string "gateway.fe.apple-dns.net" -j DROP
iptables -A FORWARD -p tcp --dport 53 -m string --algo kmp --string "peacecorp.org" -j DROP
iptables -A FORWARD -p tcp --dport 53 -m string --algo kmp --string "pizzaseo.com" -j DROP
iptables -A FORWARD -p tcp --dport 53 -m string --algo kmp --string "plato.junkemailfilter.com" -j DROP
iptables -A FORWARD -p tcp --dport 53 -m string --algo kmp --string "version.bind" -j DROP

# Allow portainer
iptables -A INPUT -p udp --dport 9443 -j ACCEPT
iptables -A INPUT -p tcp --dport 9443 -j ACCEPT
iptables -A OUTPUT -p udp --dport 9443 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 9443 -j ACCEPT
 
# Allow syncthing
iptables -A INPUT -p udp --dport 21027 -j ACCEPT
iptables -A INPUT -p tcp --dport 21027 -j ACCEPT
iptables -A OUTPUT -p udp --dport 21027 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 21027 -j ACCEPT
iptables -A INPUT -p udp --dport 22000 -j ACCEPT
iptables -A INPUT -p tcp --dport 22000 -j ACCEPT
iptables -A OUTPUT -p udp --dport 22000 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22000 -j ACCEPT

# Allow loopback connections - required in some cases
iptables -t filter -A INPUT -i lo -j ACCEPT 
iptables -t filter -A OUTPUT -o lo -j ACCEPT

# Maintain establish connetions
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

#  Open ports for neko firefox
iptables -A INPUT -p udp --dport 52000:52100 -j ACCEPT

# Open ports for neko tor
iptables -A INPUT -p udp --dport 52200:52300 -j ACCEPT

iptables -A INPUT -m string --algo bm --string "m194-158-73-136.andorpac.ad" -j DROP
iptables -A INPUT -m string --algo bm --string "m194-158-73-136.andorpac.ad" -j DROP
iptables -A INPUT -m string --algo bm --string "m194-158-72-169.andorpac.ad" -j DROP
iptables -A INPUT -m string --algo bm --string "m194-158-75-213.andorpac.ad" -j DROP
iptables -A INPUT -m string --algo bm --string "m194-158-72-158.andorpac.ad" -j DROP
iptables -A INPUT -m string --algo bm --string "m194-158-73-141.andorpac.ad" -j DROP
iptables -A INPUT -m string --algo bm --string "m194-158-72-198.andorpac.ad" -j DROP

# Block ipv6
ip6tables -A INPUT -p tcp -j DROP
ip6tables -A OUTPUT -p tcp -j DROP
ip6tables -A INPUT -p udp -j DROP
ip6tables -A OUTPUT -p udp -j DROP
 
# Disable incoming pings
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Block everything else
 #iptables -t filter -P INPUT DROP 
 #iptables -t filter -P FORWARD DROP 
 #iptables -t filter -P OUTPUT DROP 

# Save your changes
iptables-save

 # Install docker (below for x86 Ubuntu 20.04)
 # Instruction for ARM64 (RaspberryPi) - https://omar2cloud.github.io/rasp/rpidock/
 if ! dockerd --help > /dev/null 2>&1; then
   while true; do
     read -rp "
Docker is not installed. Would you like to install it? [Y/n]" yn
     case $yn in
       [Yy]*) break ;;
       [Nn]*) exit 0 ;;
       *) echo "Please answer yes or no." ;;
     esac
   done

echo "
"

 apt install docker docker-compose

 docker volume create portainer_data

 docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    cr.portainer.io/portainer/portainer-ce:latest

# Install docker-compose
# https://www.jfrog.com/connect/post/install-docker-compose-on-raspberry-pi/
 #docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data cr.portainer.io/portainer/portainer-ce:2.9.3

 echo "
 Docker with portainer is installed.  Please immediatly log on to your portainer instance set up the
 user.  If you don't, someone else will.  You have been warned!

    'https://$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1):9443'
    "
    
while true; do
  read -rp "Hit Enter when the above step is complete." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

# Add automated cleanup using bleachbit
echo "
Installing a cron job to clean up the system automatically
using bleachbit...
"

su $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root') -c '(crontab -l 2>/dev/null || true; echo "0 1 1 * * bleachbit --list | grep -E \"[a-z0-9_\-]+\.[a-z0-9_\-]+\" | xargs bleachbit --clean") | crontab -'

while true; do
  read -rp "
  We're now going to perform a final cleanup using bleachbit.  Hit Enter to continue." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

echo "
"
rm setup.sh

bleachbit --list | grep -E '[a-z0-9_\-]+\.[a-z0-9_\-]+' | xargs bleachbit --clean

echo "We're all set, your new server is configured. :)
"
