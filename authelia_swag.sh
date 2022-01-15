#!/bin/bash

# ToDo:
#  1.  Commit some of these variables to .bashrc for future use
#  2.  Change swag directory to config
#  3.  Add a way to cycle through the swag installers and add enough 
#      subdomains to accomodate all of them and then sed the files with the
#      created subdoimains so that they work 'out of the box'.


stackname=authelia_swag
swagloc=swag
rootdir=/home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')

#======================================================================================
#  Prep the system

#  Needed if you are going to run pihole
#  Reference - https://www.geeksforgeeks.org/create-your-own-secure-home-network-using-pi-hole-and-docker/
#  Reference - https://www.shellhacks.com/setup-dns-resolution-resolvconf-example/
sudo systemctl stop systemd-resolved.service
sudo systemctl disable systemd-resolved.service
sed -i 's/nameserver 127.0.0.53/nameserver 8.8.8.8''/g' /etc/resolv.conf
#  sudo lsof -i -P -n | grep LISTEN - allows you to find out who is litening on a port

echo "
 - Run this script as superuser.
"
# Detect Root
if [[ "${EUID}" -ne 0 ]]; then
  echo "This installer needs to be run with superuser privileges." >&2
  exit 1
fi

while true; do
  read -rp "
Enter your fully qualified domain name (FQDN) from your DNS provider - would look like 'example.com': " fqdn
  if [[ -z "${fqdn}" ]]; then
    echo "Enter your fully qualified domain name (FQDN) from your DNS provider or hit ctrl+C to exit."
    continue
  fi
  break
done

# Because of the limitation on setting wildcard domains using http we have to specify each domain,
# one by one.  The following will automate the process for you by generating the specified
# number of 8 digit random subdomain names.  Adds www by default.  See swag docker-compose.yml
# output file for further infrormation.
while true; do
  read -rp "
How many random subdomains would you like to generate?: " rnddomain
  if [[ -z "${rnddomain}" ]]; then
    echo "Enter the number of random subdomains would you like to generate or hit ctrl+C to exit."
    continue
  fi
  break
done

# Create domain string
subdomains="www"
i=0
while [ $i -ne $rnddomain ]
do
        i=$(($i+1))
        subdomains+=", "
        subdomains+=$(echo $RANDOM | md5sum | head -c 8)
done

# If using duckdns
#while true; do
#  read -rp "
#Enter your duckdns token - would look like '1af7e11a-2342-49c9-abcd-88bf6d91de22': " ducktkn
#  if [[ -z "${ducktkn}" ]]; then
#    echo "Enter your duckdns token or hit ctrl+C to exit."
#    continue
#  fi
#  break
#done

while true; do
  read -rp "Enter your desired JWT secret - example - 'AUVV2tYhu7YD5vbqZMkxDqX3wDEDkYYk8jQwBDq82Y9P3tHsSR': " jwts
  if [[ -z "${jwts}" ]]; then
    echo "Enter your desired JWT secret or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired Authelia secret - example - 'KnCfXrWCRU7of96XqvTxQ9Zm8BFHKUFfnTXSUoiDM9kV8A94Cp': " auths
  if [[ -z "${auths}" ]]; then
    echo "Enter your desired Authelia secret or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired Authelia encryption key - example - 'NER38ZZAswXqnrkDzRAyVnXcxBJa2v9ffZC55r7W': " authec
  if [[ -z "${authec}" ]]; then
    echo "Enter your desired Authelia encryption key or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired Authelia userid - example - 'mynewuser' or (better) 'Fkr5HZH4Rv': " authusr
  if [[ -z "${authusr}" ]]; then
    echo "Enter your desired Authelia userid or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired Authelia password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " authpwd
  if [[ -z "${authpwd}" ]]; then
    echo "Enter your desired Authelia password or hit ctrl+C to exit."
    continue
  fi
  break
done


while true; do
  read -rp "
Enter your desired pihole password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " pipass
  if [[ -z "${pipass}" ]]; then
    echo "Enter your desired pihole password or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired neko user password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " nupass
  if [[ -z "${nupass}" ]]; then
    echo "Enter your desired pihole password or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired neko admin password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " napass
  if [[ -z "${napass}" ]]; then
    echo "Enter your desired pihole password or hit ctrl+C to exit."
    continue
  fi
  break
done

# If using zerossl
#while true; do
#  read -rp "
#Enter your zerossl account email address: " zspwd
#  if [[ -z "${zspwd}" ]]; then
#    echo "Enter your zerossl account email address or hit ctrl+C to exit."
#    continue
#  fi
#  break
#done

while true; do
    read -p "
Do you want to perform a completely fresh install (y/n)? " yn
    case $yn in
        [Yy]* ) rm -r docker;
                docker stack rm $stackname;
                docker swarm leave --force;
                #docker swarm init;
                #  You must create these directories manually or else the container won't run
                mkdir docker;
                mkdir docker/authelia;
                mkdir docker/firefox;
                mkdir docker/heimdall;
                mkdir docker/neko;
                mkdir docker/neko/firefox;
                mkdir docker/neko/tor;
                mkdir docker/pihole;
                mkdir docker/pihole/etc-pihole;
                mkdir docker/pihole/etc-dnsmasq.d;
                mkdir docker/swag;
                mkdir docker/syncthing;
                mkdir docker/syncthing/data1;
                mkdir docker/syncthing/data2;
                chown $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')":"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root') -R docker;
                break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "
"

#  Whoogle - https://hub.docker.com/r/benbusby/whoogle-search#g-manual-docker
#  Install dependencies
apt-get install -y libcurl4-openssl-dev libssl-dev
git clone https://github.com/benbusby/whoogle-search.git /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker

#Move the contents from directory whoogle-search to directory whoogle
mv /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/whoogle-search /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/whoogle

rm docker-compose.yml
touch docker-compose.yml

echo "version: \"3.1\"

services:
  swag:
    image: linuxserver/swag
    #container_name: swag # Depricated
    cap_add:
      - NET_ADMIN
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - URL=$fqdn
      #
      # Use of wildcard domains is no longer possible using http authentication for letsencrypt or zerossl
      # Linuxserver.io version:- 1.22.0-ls105 Build-date:- 2021-12-30T06:20:11+01:00      
      # 'Client with the currently selected authenticator does not support 
      # any combination of challenges that will satisfy the CA. 
      # You may need to use an authenticator plugin that can do challenges over DNS.'
      #- SUBDOMAINS=wildcard
      - SUBDOMAINS=$subdomains
      #
      # If CERTPROVIDER is left blank, letsencrypt will be used
      #- CERTPROVIDER=zerossl
      #
      #- VALIDATION=duckdns
      #- DNSPLUGIN=cloudfare #optional
      #- PROPAGATION= #optional
      #- DUCKDNSTOKEN=$ducktkn
      #- EMAIL=$zspwd
      - ONLY_SUBDOMAINS=false #optional
      #- EXTRA_DOMAINS= #optional
      - STAGING=false #optional
    volumes:
      - $rootdir/docker/swag:/config
    ports:
      - 443:443
      - 80:80 
      # You must leave port 80 open or you won't be able to get your ssl certificate via http
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure

  authelia:
    image: authelia/authelia:latest #4.32.0
    #container_name: authelia # Depricated
    environment:
      - TZ=America/New_York
    volumes:
      - $rootdir/docker/authelia:/config
    networks:
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure
       
  heimdall:
    image: ghcr.io/linuxserver/heimdall
    #container_name: heimdall # Depricated
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    volumes:
      - $rootdir/docker/heimdall:/config
    networks:
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure
  
  syncthing:
    image: lscr.io/linuxserver/syncthing
    #container_name: syncthing # Depricated
    hostname: syncthing # Optional
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    volumes:
      - $rootdir/docker/syncthing:/config
      - $rootdir/docker/syncthing/data1:/data1
      - $rootdir/docker/syncthing/data2:/data2
    ports:
      #- 8384:8384 # WebApp port, don't publish this to the outside world - only proxy through swag/authelia
      - 22000:22000/tcp
      - 22000:22000/udp
      - 21027:21027/udp
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
       
  pihole:  # See this link for some help getting the host configured properly or else there will be a port 53 conflict
           #      https://www.geeksforgeeks.org/create-your-own-secure-home-network-using-pi-hole-and-docker/
    #container_name: pihole # Depricated
    image: pihole/pihole:latest
    ports:
      - 53:53/udp
      - 53:53/tcp
      - 67:67/tcp
      #- 8080:80/tcp # WebApp port, don't publish this to the outside world - only proxy through swag/authelia
      #- 8443:443/tcp # WebApp port, don't publish this to the outside world - only proxy through swag/authelia
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - WEBPASSWORD=$pipass
      - SERVERIP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1) 
    volumes:
       - $rootdir/docker/pihole/etc-pihole:/etc/pihole
       - $rootdir/docker/pihole/etc-dnsmasq.d/:/etc/dnsmasq.d
    dns:
      - 127.0.0.1
      - 1.1.1.1
    cap_add:
      - NET_ADMIN
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
       
  firefox:
    image: lscr.io/linuxserver/firefox
    #container_name: firefox # Depricated
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - SUBFOLDER=/firefox/ # Required if using authelia to authenticate
    volumes:
      - $rootdir/docker/firefox:/config
    #ports:
      #- 3000:3000 # WebApp port, don't publish this to the outside world - only proxy through swag/authelia
    shm_size: \"1gb\"
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure

  whoogle:
    image: benbusby/whoogle-search
    pids_limit: 50
    mem_limit: 256mb
    memswap_limit: 256mb
    # user debian-tor from tor package
    user: '102'
    security_opt:
      - no-new-privileges
    cap_drop:
      - ALL
    tmpfs:
      - /config/:size=10M,uid=102,gid=102,mode=1700
      - /var/lib/tor/:size=10M,uid=102,gid=102,mode=1700
      - /run/tor/:size=1M,uid=102,gid=102,mode=1700
    environment: # Uncomment to configure environment variables
      # Basic auth configuration, uncomment to enable
      #- WHOOGLE_USER=<auth username>
      #- WHOOGLE_PASS=<auth password>
      # Proxy configuration, uncomment to enable
      #- WHOOGLE_PROXY_USER=<proxy username>
      #- WHOOGLE_PROXY_PASS=<proxy password>
      #- WHOOGLE_PROXY_TYPE=<proxy type (http|https|socks4|socks5)
      #- WHOOGLE_PROXY_LOC=<proxy host/ip>
      - EXPOSE_PORT=5000
      # Site alternative configurations, uncomment to enable
      # Note: If not set, the feature will still be available
      # with default values.
      - WHOOGLE_ALT_TW=farside.link/nitter
      - WHOOGLE_ALT_YT=farside.link/invidious
      - WHOOGLE_ALT_IG=farside.link/bibliogram/u
      - WHOOGLE_ALT_RD=farside.link/libreddit
      - WHOOGLE_ALT_MD=farside.link/scribe
      - WHOOGLE_ALT_TL=lingva.ml
    #env_file: # Alternatively, load variables from whoogle.env
      #- whoogle.env
    #ports:
      #- 5000:5000
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure

  neko:
    image: m1k1o/neko:firefox
    shm_size: \"2gb\"
    ports:
      #- 8080:8080
      - 52000-52100:52000-52100/udp
    environment:
      NEKO_SCREEN: 1440x900@60
      NEKO_PASSWORD: $nupass
      NEKO_PASSWORD_ADMIN: $napass
      NEKO_EPR: 52000-52100
      NEKO_ICELITE: 1
    networks:
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure

# For networking setup explaination, see this link:
# https://stackoverflow.com/questions/39913757/restrict-internet-access-docker-container
networks:
    no-internet:
      driver: bridge
      internal: true
    internet:
      driver: bridge" >> docker-compose.yml

nano docker-compose.yml

# Take the opportunity to clean up any old junk before running the stack
#  Run the stack
docker system prune && docker-compose -f docker-compose.yml -p $stackname up -d 

#docker-compose up -d --compose-file docker-compose.yml
#docker stack deploy --compose-file docker-compose.yml "$stackname"

# Wait a bit for the stack to deploy
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml ]
    do
      sleep 5
    done
    
echo "
The stack started successfully...
"
# Make a backup of the clean authelia configuration file 
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml.bak

#  Comment out all the lines in the ~/docker/authelia/configuration.yml.bak configuration file
sed -e 's/^\([^#]\)/#\1/g' -i /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml

#  Uncomment/modify the required lines in the /docker/authelia/configuration.yml.bak file
sed -i 's/\#---/---''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#theme: light/theme: light''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#jwt_secret: a_very_important_secret/jwt_secret: '"$jwts"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#default_redirection_url: https:\/\/home.example.com\/default_redirection_url: https:\/\/"$fqdn"\//''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#server:/server:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  host: 0.0.0.0/  host: 0.0.0.0''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  port: 9091/  port: 9091''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  path: ""/  path: \"authelia\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  read_buffer_size: 4096/  read_buffer_size: 4096''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  write_buffer_size: 4096/  write_buffer_size: 4096''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#log:/log:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  level: debug/  level: debug''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#totp:/totp:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  algorithm: sha1/  algorithm: sha1''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  digits: 6/  digits: 6''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  period: 30/  period: 30''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  skew: 1/  skew: 1''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#authentication_backend:/authentication_backend:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  disable_reset_password: false/  disable_reset_password: false''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  # file:/  file:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #   path: \/config\/users_database.yml/     path: \/config\/users_database.yml''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #   password:/     password:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #     algorithm: argon2id/       algorithm: argon2id''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #     iterations: 1/       iterations: 1''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #     key_length: 32/       key_length: 32''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #     salt_length: 16/       salt_length: 16''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #     memory: 1024/       memory: 1024''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #     parallelism: 8/       parallelism: 8''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#access_control:/access_control:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  default_policy: deny/  default_policy: deny''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  rules:/  rules:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i ':a;N;$!ba;s/\#    - domain:/    - domain:''/3' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#        - secure.example.com/        - '"$fqdn"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#        - private.example.com/        - \"*.'"$fqdn"'\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i ':a;N;$!ba;s/\#      policy: two_factor/      policy: two_factor''/1' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#session:/session:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  name: authelia_session/  name: authelia_session''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  domain: example.com/  domain: '"$fqdn"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  secret: insecure_session_secret/  secret: '"$auths"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  expiration: 1h/  expiration: 12h''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  inactivity: 5m/  inactivity: 1h''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  remember_me_duration: 1M/  remember_me_duration: 1M''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#regulation:/regulation:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  max_retries: 3/  max_retries: 3''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  find_time: 2m/  find_time: 2m''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  ban_time: 5m/  ban_time: 5m''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#storage:/storage:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  # local:/   local:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #   path: \/config\/db.sqlite3/     path: \/config\/db.sqlite3''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\     password: mypassword/#     password: mypassword''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  # encryption_key: you_must_generate_a_random_string_of_more_than_twenty_chars_and_configure_this/   encryption_key: '"$authec"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#notifier:/notifier:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i ':a;N;$!ba;s/\#  disable_startup_check: false/  disable_startup_check: false''/2' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  # filesystem:/  filesystem:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  #   filename: \/config\/notification.txt/     filename: \/config\/notification.txt''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml

# Yeah, that was exhausting...
#sed -i 's/\#---/---''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml

# You have to go through the startup twice because authelia starts, prints the *.yml file, then exits.
docker restart $(sudo docker ps | grep $stackname | awk '{ print$1 }')
docker system prune
docker stop $(sudo docker ps | grep $stackname | awk '{ print$1 }')
docker system prune
docker-compose -f docker-compose.yml -p $stackname up -d 

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep authelia_swag)" ];
do
 sleep 5
 done
 
echo "
Cleaning up and restarting the stack...
"
# Make sure the stack started properly by checking for the existence of users_database.yml
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml ]
    do
      sleep 5
    done

# Make a backup of the clean authelia configuration file 
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml.bak

#  Comment out all the lines in the ~/docker/authelia/users_database.yml configuration file
sed -e 's/^\([^#]\)/#\1/g' -i /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml

# Generate the hashed password line to be added to users_database.yml.
pwdhash=$(docker run --rm authelia/authelia:latest authelia hash-password $authpwd | awk '{print $3}')
    
#sed -i 's/\#---/---''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml

# Update the users database file with your username and hashed password.
echo "
users:
  $authusr:
    displayname: \"$authusr\"
    password: \"$pwdhash\"
    email: authelia@authelia.com
    groups: []
..." >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml

sed -i 's/\#---/---''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml
# Mind the $ signs and forward slashes :(

# Update the swag nginx default landing page to redirect to Authelia authentication and allow heimdall to work
sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default
sed -i 's/\    location \/ {/#    location \/ {''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default
sed -i 's/\        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;/#        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default
sed -i ':a;N;$!ba;s/\    }/#    }''/1' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default

#  Activate the heimdall folder.conf to serve as the root URL landing page proxied through authelia
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/heimdall.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/heimdall.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/heimdall.subfolder.conf

#  Prepare the firefox container - copy the calibre.subfolder.conf use it as a template.
#  Be mindful of the line that says to add 'SUBFOLDER=/firefox/' to your docker compose
#  file or you will get a an error that says 'Cannot GET /firefox/' displayed when you 
#  navigate to the specified url (e.g. https://your-fqdn/firefox)
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/calibre.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf

sed -i 's/calibre/firefox''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf
sed -i 's/    set $upstream_port 8080;/    set $upstream_port 3000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf

#  Prepare the pihole container
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf

#  Prepare the syncthing proxy-conf file
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf

#docker-compose -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/whoogle/docker-compose.yml -p $stackname up -d 

#  Prepare the whoogle proxy-conf file using syncthing.subfolder.conf as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf
sed -i 's/syncthing/whoogle''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf

#  There is some non-fatal error thrown by whoogle docker.  This may be the answer - https://bbs.archlinux.org/viewtopic.php?id=228053

#  Prepare the neko proxy-conf file using syncthing.subfolder.conf as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/neko.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/neko.subfolder.conf
sed -i 's/syncthing/neko''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/neko.subfolder.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/neko.subfolder.conf

#  Unlock neko policies in /usr/lib/firefox/distribution/policies.json
#docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
#sed -i 's/    \"BlockAboutConfig\": true/    \"BlockAboutConfig\": false''/g' /usr/lib/firefox/distribution/policies.json
#EOF

#  Pihole may block this domain which will prevent n.eko from running - checkip.amazonaws.com

#  Remove the policy restrictions all together :)
docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
mv /usr/lib/firefox/distribution/policies.json /usr/lib/firefox/distribution/policies.json.bak
EOF

# Change some of the parameters in mozilla.cfg (about:config) - /usr/lib/firefox/mozilla.cfg
docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
sed -i 's/lockPref(\"xpinstall.enabled\", false);/''/g' /usr/lib/firefox/mozilla.cfg
EOF

docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
sed -i 's/lockPref(\"xpinstall.whitelist.required\", true);/''/g' /usr/lib/firefox/mozilla.cfg
EOF

#  Add custom search engine
#    You must install the add-on 'Add custom search engine' in firefox.
#  After you add the custom search enigine, you can disable it
#  Whoogle
#  https://farside.link/whoogle/search?q=%s

#  /home/neko/.mozilla/firefox/profile.default - prefs.js

#  https://stackoverflow.com/questions/39236537/exec-sed-command-to-a-docker-container
#  Run commands inside the docker
#docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
#sed -ire '/URL_BASE = /c\api.myapiurl' /tmp/config.ini
#grep URL_BASE /tmp/config.ini
# any other command you like
#EOF

#  Move your firefox cointainers
#  about:support
#  Follow the link to 'Profile Folder'


#  Perform some SWAG hardening
#    https://virtualize.link/secure/
echo "
\#  Additional SWAG hardening - https:\/\/virtualize.link\/secure\/" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf
#  No more Google FLoC
echo "add_header Permissions-Policy \"interest-cohort=()\";" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf
#  X-Robots-Tag - prevent applications from appearing in results of search engines and web crawlers
echo "add_header X-Robots-Tag \"noindex, nofollow, nosnippet, noarchive\";" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf
#  Enable HTTP Strict Transport Security (HSTS) 
echo "add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf

echo "
Cleaning up and restarting the stack for the final time...
"
#  Need to restart the stack
docker stop $(sudo docker ps | grep $stackname | awk '{ print$1 }')
docker system prune
docker-compose -f docker-compose.yml -p $stackname up -d 
docker restart $(sudo docker ps | grep $stackname | awk '{ print$1 }')

#  Store non-persistent variables in .bashrc for later use across reboots
echo "
" >> ~/.bashrc
echo "export stackname=$stackname" >> ~/.bashrc
echo "export authusr=$authusr" >> ~/.bashrc
echo "export authpwd=$authpwd" >> ~/.bashrc
echo "export swagloc=$swagloc" >> ~/.bashrc
# Commit the .bashrc changes
source ~/.bashrc

echo "
Now you may want to restart the box and then navigate to your fqdn, 

     'https://$fqdn'

Tell Authelia the secondary authentication you want, like TOTP and then
after your first login attempt, use your ssh terminal to get the 
authentication url using these commands:

      'ssh "$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"@"$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)" -p "$(cat /etc/ssh/sshd_config | grep Port | head -1 | awk '{print $2}')"'

      'sudo cat /home/"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++')"/docker/authelia/notification.txt | grep http'
 "

#  This last part about cat'ing out the url is there beacuase I was unable to get email authentication working

