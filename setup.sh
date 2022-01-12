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
  read -rp "Let's run and update first (hit enter to continue)..." yn
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
apt purge telnet -y
apt purge postfix -y
apt purge tcpdump -y
apt purge nmap-ncat -y
apt purge wpa_supplicant -y
apt purge avahi-daemon -y
# Clean up
apt-get autoremove -y
apt-get autoclean -y

#systemctl reload postfix

echo "
Open a new terminal window and type:

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
uses and 30 second token (i.e. y, y, n, n, y).
"

while true; do
  read -rp "Hit Enter or ctrl+C to exit." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

apt-get install libpam-google-authenticator -y

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

# Set the default policy of the INPUT chain to DROP
#iptables -P INPUT DROP
#iptables -P FORWARD DROP
#iptables -P OUTPUT ACCEPT

##now for the sake add rate limit general (avoid flooding)
 iptables -N udp-flood
 iptables -A udp-flood -m limit --limit 4/second --limit-burst 4 -j RETURN
 iptables -A udp-flood -j DROP
 iptables -A INPUT -i eth0 -p udp -j udp-flood
 iptables -A INPUT -i eth0 -f -j DROP

##these comes from freek's blog post
 iptables -A INPUT -p udp --dport 53 -m string --from 40 --algo bm --hex-string '|0000FF0001|' -m recent --set --name dnsanyquery
 iptables -A INPUT -p udp --dport 53 -m string --from 40 --algo bm --hex-string '|0000FF0001|' -m recent --name dnsanyquery --rcheck --seconds 60 --hitcount 3 -j DROP
 iptables -A INPUT -p tcp --dport 53 -m string --from 52 --algo bm --hex-string '|0000FF0001|' -m recent --set --name dnsanyquery
 iptables -A INPUT -p tcp --dport 53 -m string --from 52 --algo bm --hex-string '|0000FF0001|' -m recent --name dnsanyquery --rcheck --seconds 60 --hitcount 3 -j DROP

#  Block most ports except the ones we will be using
 iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
 iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
 iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
 iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT

# Open ssh port 
 iptables -t filter -A OUTPUT -p tcp --dport $newport -j ACCEPT
 iptables -t filter -A INPUT -p tcp --dport $newport -j ACCEPT
 iptables -t filter -A OUTPUT -p udp --dport $newport -j ACCEPT
 iptables -t filter -A INPUT -p udp --dport $newport -j ACCEPT

# Allow dns requests 
 iptables -A INPUT -p udp --dport 53 -j ACCEPT
 iptables -A INPUT -p tcp --dport 53 -j ACCEPT
 iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
 iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
 iptables -A INPUT -p udp --dport 67 -j ACCEPT
 iptables -A INPUT -p tcp --dport 67 -j ACCEPT
 iptables -A OUTPUT -p udp --dport 67 -j ACCEPT
 iptables -A OUTPUT -p tcp --dport 67 -j ACCEPT

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
 
# Block all other udp
 iptables -A INPUT -p udp -j DROP
 iptables -A OUTPUT -p udp -j DROP
 ip6tables -A INPUT -p udp -j DROP
 ip6tables -A OUTPUT -p udp -j DROP

# Disable incoming pings
 iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

# Block everything else
 iptables -t filter -P INPUT DROP 
 iptables -t filter -P FORWARD DROP 
 iptables -t filter -P OUTPUT DROP 


 # Install docker
 #

 if ! dockerd --help > /dev/null 2>&1; then
   while true; do
     read -rp "Docker is not installed. Would you like to install it? [Y/n]" yn
     case $yn in
       [Yy]*) break ;;
       [Nn]*) exit 0 ;;
       *) echo "Please answer yes or no." ;;
     esac
   done

   apt-get remove containerd docker docker-engine docker.io runc
   apt-get update
   apt-get install -y \
     apt-transport-https \
     ca-certificates \
     curl \
     gnupg \
     lsb-release

   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

   echo \
     "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
         $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

   apt-get update
   apt-get install -y containerd.io docker-ce docker-ce-cli
 fi

 curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

 chmod +x /usr/local/bin/docker-compose

 docker volume create portainer_data

 docker run -d -p 8000:8000 -p 9443:9443 --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    cr.portainer.io/portainer/portainer-ce:2.9.3

 echo "
 Docker with portainer is installed.  Please immediatly log on to your portainer instance set up the
 user.  If you don't, someone else will.  You have been warned!

    https://$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1):9443
    "
    
while true; do
  read -rp "Hit Enter when the above step is complete." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

while true; do
  read -rp "We're now going to perform a final cleanup using bleachbit.  Hit Enter to continue." yn
  case $yn in
    "") break ;;
    *) echo "Please hit Enter or ctrl+C to exit." ;;
  esac
done

bleachbit --list | grep -E '[a-z0-9_\-]+\.[a-z0-9_\-]+' | xargs bleachbit --clean

echo "
We're all set, your new server is configured.
"
