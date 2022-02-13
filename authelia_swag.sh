#!/bin/bash

# ToDo:
#  1.  Configure iptable rules
#  2.  Wireguard
#  3.  OpenVPN
#  4.  Shadowsocks
#  5.  ShadowVPN
#  For these VPN options, see the following - https://github.com/vimagick/dockerfiles

#  Variables
stackname=authelia_swag
swagloc=swag
rootdir=/home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')

#  Generate some of the variables that will be used later but that the user does
#  not need to keep track of
#    https://linuxhint.com/generate-random-string-bash/

jwts=$(openssl rand -hex 25)     # Authelia JWT secret
auths=$(openssl rand -hex 25)    # Authelia secret
authec=$(openssl rand -hex 25)   # Authelia encryption key

#======================================================================================
#  Prep the system

#  Needed if you are going to run pihole
#    Reference - https://www.geeksforgeeks.org/create-your-own-secure-home-network-using-pi-hole-and-docker/
#    Reference - https://www.shellhacks.com/setup-dns-resolution-resolvconf-example/
sudo systemctl stop systemd-resolved.service
sudo systemctl disable systemd-resolved.service
sed -i 's/nameserver 127.0.0.53/nameserver 8.8.8.8''/g' /etc/resolv.conf
#  sudo lsof -i -P -n | grep LISTEN - allows you to find out who is litening on a port
#  sudo apt-get install net-tools
#  sudo netstat -tulpn | grep ":53 " - port 53

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
# output file for further infrormation.  Also adds required domains for subsequent services
# that require a subdomain such as jitsi-meet, libretranslate, and rss-proxy.
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
#  Add a few specific use case subdomains
#  jitsiweb
jwebsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$jwebsubdomain
#  libretranslate
ltsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$ltsubdomain
#  rss-proxy
rpsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$rpsubdomain
#  wireguard gui
wgsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$wgsubdomain
#  synapse
sysubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$sysubdomain


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
Enter your desired pihole webgui password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " pipass
  if [[ -z "${pipass}" ]]; then
    echo "Enter your desired pihole webgui password or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired neko user password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " nupass
  if [[ -z "${nupass}" ]]; then
    echo "Enter your desired neko user password or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired neko admin password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " napass
  if [[ -z "${napass}" ]]; then
    echo "Enter your desired neko admin password or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired shadowsocks password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " sspass
if [[ -z "${sspass}" ]]; then
    echo "Enter your desired shadowsocks password or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired wireguard ui userid - example - 'mynewuser' or (better) 'Fkr5HZH4Rv': " wguid
if [[ -z "${wguid}" ]]; then
    echo "Enter your desired wireguard ui userid or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired wireguard ui password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " wgpass
  if [[ -z "${wgpass}" ]]; then
    echo "Enter your desired wireguard ui password or hit ctrl+C to exit."
    continue
  fi
  break
done

# If using zerossl instead of letsencrypt
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
        [Yy]* ) # Stop the running docker containers
                docker stop $(sudo docker ps | grep $stackname | awk '{ print$1 }');
                #  Remove the docker containers associated with stackname
                docker rm -vf $(sudo docker ps --filter status=exited | grep $stackname | awk '{ print$1 }');
                #  Remove the networks associated with stackname...these are a bit persistent and need
                #  to be removed so they don't cause a conflict with any revised configureations.
                docker network ls | grep authelia_swag | awk '{ print$1 }' | docker network rm;
                #  Purge any dangling items...
                docker system prune;
                rm -r docker;
                #  You must create these directories manually or else the container won't run
                mkdir docker;
                mkdir docker/authelia;
                mkdir docker/firefox;
                mkdir docker/homer;
                mkdir docker/neko;
                mkdir docker/neko/firefox;
                mkdir docker/neko/firefox/home;
                mkdir docker/neko/firefox/home/neko;
                mkdir docker/neko/firefox/usr;
                mkdir docker/neko/firefox/usr/lib;
                mkdir docker/neko/firefox/usr/lib/firefox;
                mkdir docker/neko/tor;
                mkdir docker/neko/tor/home;
                mkdir docker/neko/tor/usr;
                mkdir docker/pihole;
                mkdir docker/pihole/etc-pihole;
                mkdir docker/pihole/etc-dnsmasq.d;
                mkdir docker/swag;
                mkdir docker/synapse/{data};
                mkdir docker/syncthing;
                mkdir docker/syncthing/data1;
                mkdir docker/syncthing/data2;
                mkdir docker/wireguard;
                mkdir docker/wireguard/{config,app,etc}
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
apt-get install -y -qq libcurl4-openssl-dev libssl-dev 
git clone https://github.com/benbusby/whoogle-search.git 

# Move the contents from directory whoogle-search to directory whoogle
mv /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/whoogle-search /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/whoogle

#  Jitsi Broadcasting Infrastructure (Jibri) - https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker#advanced-configuration
#  Install dependencies
apt-get install -y -qq linux-image-extra-virtual

rm docker-compose.yml
touch docker-compose.yml

# Create the docker-compose.yml file for the initial base installation
echo "version: \"3.1\"

services:

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

  firefox:  # linuxserver.io firefox browser
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

  homer:
    image: b4bz/homer
    #container_name: homer # Depricated
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    volumes:
      - $rootdir/docker/homer:/www/assets
    networks:
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure

  translate:
    image: libretranslate/libretranslate
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    #build: .
#    Don't expose external ports to prevent access outside swag
#    ports:
#      - 5000:5000
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
    ## Uncomment below command and define your args if necessary
    # command: --ssl --ga-id MY-GA-ID --req-limit 100 --char-limit 500 
    command: --ssl

  neko:  # Neko firefox browser
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
#    volumes:
#       - $rootdir/docker/neko/firefox/usr/lib/firefox:/usr/lib/firefox
#       - $rootdir/docker/neko/firefox/home/neko:/home/neko
    dns:
#      - xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)
#  If you are running pihole in a docker container, point neko to the pihole
#  docker container ip address.  Probably best to set a static ip address for 
#  the pihole in the configuration so that it will never change.
       - 172.20.10.10
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure

  tor:  # Neko tor browser
    image: m1k1o/neko:tor-browser
    shm_size: \"2gb\"
    ports:
      #- 8080:8080
      - 52200-52300:52200-52300/udp
    environment:
      NEKO_SCREEN: 1440x900@60
      NEKO_PASSWORD: $nupass
      NEKO_PASSWORD_ADMIN: $napass
      NEKO_EPR: 52200-52300
      NEKO_ICELITE: 1
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
       - $rootdir/docker/pihole/etc-dnsmasq.d:/etc/dnsmasq.d
    dns:
      - 127.0.0.1
      - 1.1.1.1
    cap_add:
      - NET_ADMIN
    networks:
      #- no-internet  #  I think this one not needed...
      #  Set a static ip address for the pihole - https://www.cloudsavvyit.com/14508/how-to-assign-a-static-ip-to-a-docker-container/
      internet:
          ipv4_address: 172.20.10.10 
    deploy:
      restart_policy:
       condition: on-failure
  rssproxy:
    image: damoeb/rss-proxy:js
    #container_name: heimdall # Depricated
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
#    volumes:
#      - /home/3gNqFD9VFoi9wch2vo/docker/rss-proxy:/opt/rss-proxy
#    ports:
#      - 3000:3000
    networks:
      - internet
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure

  shadowsocks:
    image: shadowsocks/shadowsocks-libev
    ports:
      - 58211:58211/tcp
      - 58211:58211/udp
      #  need to configure to use pihole dns on local machine
      #  default is google servers 8.8.8.8 8.8.4.4 
    environment:
      - METHOD=aes-256-gcm
      - PASSWORD=$sspass
      - DNS_ADDRS=1.1.1.1,9.9.9.9 #comma delimited list

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
      #- EMAIL=$zspwd  # Zerossl password
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
      - $rootdir/docker:/config/Sync
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
 
  wireguard:
    image: ghcr.io/linuxserver/wireguard
    #container_name: wireguard # Depricated
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - SERVERURL=$fqdn
      - SERVERPORT=50220
      - PEERS=3
      - PEERDNS=auto
      - INTERNAL_SUBNET=10.18.18.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - $rootdir/docker/wireguard/config:/config
      - $rootdir/docker/wireguard/modules:/lib/modules
    ports:
      - 50220:50220/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
 
  wgui:
    image: ngoduykhanh/wireguard-ui:latest
    #container_name: wgui # Depricated
    # Port 5000
    #cap_add:
    #  - NET_ADMIN
    environment:
      #- SENDGRID_API_KEY
      #- EMAIL_FROM_ADDRESS
      #- EMAIL_FROM_NAME
      - SESSION_SECRET=$(openssl rand -hex 30)
      - WGUI_USERNAME=$wguid
      - WGUI_PASSWORD=$wgpass
    logging:
      driver: json-file
      options:
        max-size: 50m
    volumes:
      - $rootdir/docker/wireguard/app:/app/db
      - $rootdir/docker/wireguard/etc:/etc/wireguard
    #network_mode: host
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
#    user: '102'
    security_opt:
      - no-new-privileges
    cap_drop:
      - ALL
#    tmpfs:
#      - /config/:size=10M,uid=102,gid=102,mode=1700
#      - /var/lib/tor/:size=10M,uid=102,gid=102,mode=1700
#      - /run/tor/:size=1M,uid=102,gid=102,mode=1700
    environment: # Uncomment to configure environment variables
      - PUID=1000
      - PGID=1000
      # Basic auth configuration, uncomment to enable
      #- WHOOGLE_USER=<auth username>
      #- WHOOGLE_PASS=<auth password>
      # Proxy configuration, uncomment to enable
      #- WHOOGLE_PROXY_USER=<proxy username>
      #- WHOOGLE_PROXY_PASS=<proxy password>
      #- WHOOGLE_PROXY_TYPE=<proxy type (http|https|socks4|socks5)
      #- WHOOGLE_PROXY_LOC=<proxy host/ip>
      #  See the subfolder /static/settings folder for .json files with options on country and language
      - WHOOGLE_CONFIG_COUNTRY=US
      - WHOOGLE_CONFIG_LANGUAGE=lang_en
      - WHOOGLE_CONFIG_SEARCH_LANGUAGE=lang_en
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

# For networking setup explaination, see this link:
#   https://stackoverflow.com/questions/39913757/restrict-internet-access-docker-container
# For ways to see how to set up specific networks for docker see:
#   https://www.cloudsavvyit.com/14508/how-to-assign-a-static-ip-to-a-docker-container/
#   Note the requirement to remove existing newtorks using:
#     docker network ls | grep authelia_swag | awk '{ print\$1 }' | docker network rm;
networks:
    no-internet:
      driver: bridge
      internal: true
    internet:
      driver: bridge
      ipam:
        driver: default
        config:
          - subnet: 172.20.10.0/24
            gateway: 172.20.10.1" >> docker-compose.yml

# Take the opportunity to clean up any old junk before running the stack and then run it
docker system prune && docker-compose -f docker-compose.yml -p $stackname up -d 

# Wait a bit for the stack to deploy
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml ]
    do
      sleep 5;
    done
    
echo "
The stack started successfully..."

# Make a backup of the clean authelia configuration file if needed
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml.bak ]
    do
      cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml \
         /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml.bak;
    done

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
sed -i 's/\#  \# file:/  file:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#   path: \/config\/users_database.yml/    path: \/config\/users_database.yml''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i ':a;N;$!ba;s/\#  \#   password:/    password:''/1' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#     algorithm: argon2id/      algorithm: argon2id''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#     iterations: 1/      iterations: 1''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#     key_length: 32/      key_length: 32''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#     salt_length: 16/      salt_length: 16''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#     memory: 1024/      memory: 1024''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#     parallelism: 8/      parallelism: 8''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#access_control:/access_control:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  default_policy: deny/  default_policy: deny''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  rules:/  rules:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i ':a;N;$!ba;s/\#    - domain:/    - domain:''/3' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#        - secure.example.com/      - '"$fqdn"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#        - private.example.com/      - \"*.'"$fqdn"'\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
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
sed -i 's/\#  \# encryption_key: you_must_generate_a_random_string_of_more_than_twenty_chars_and_configure_this/  encryption_key: '"$authec"'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \# local:/  local:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#   path: \/config\/db.sqlite3/    path: \/config\/db.sqlite3''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#notifier:/notifier:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i ':a;N;$!ba;s/\#  disable_startup_check: false/  disable_startup_check: false''/2' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \# filesystem:/  filesystem:''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  \#   filename: \/config\/notification.txt/    filename: \/config\/notification.txt''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml

# Yeah, that was exhausting...

echo "
Cleaning up and restarting the stack...
"

# You have to go through the startup twice because authelia starts, prints the configuration.yml file, then exits.
docker restart $(sudo docker ps | grep $stackname | awk '{ print$1 }')
docker stop $(sudo docker ps | grep $stackname | awk '{ print$1 }')
docker system prune
docker-compose -f docker-compose.yml -p $stackname up -d 

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $stackname)" ];
do
 sleep 5
 done
 
# Make sure the stack started properly by checking for the existence of users_database.yml
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml ]
    do
      sleep 5
    done

# Make a backup of the clean authelia configuration file if needed
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml.bak ]
    do
       cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml \
          /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml.bak;
    done

#  Comment out all the lines in the ~/docker/authelia/users_database.yml configuration file
sed -e 's/^\([^#]\)/#\1/g' -i /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml

# Generate the hashed password line to be added to users_database.yml.
pwdhash=$(docker run --rm authelia/authelia:latest authelia hash-password $authpwd | awk '{print $3}')
    
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

# Mind the $ signs and forward slashes / :(

##################################################################################################################################
#  Configure the swag proxy-confs files for specific services

# Update the swag nginx default landing page to redirect to Authelia authentication and allow heimdall to work
sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default
sed -i 's/\    location \/ {/#    location \/ {''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default
sed -i 's/\        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;/#        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default
sed -i ':a;N;$!ba;s/\    }/#    }''/1' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/site-confs/default

##################################################################################################################################
# Firefox - linuxserver.io

#  Prepare the firefox container - copy the calibre.subfolder.conf use it as a template.
#  Be mindful of the line that says to add 'SUBFOLDER=/firefox/' to your docker compose
#  file or you will get a an error that says 'Cannot GET /firefox/' displayed when you 
#  navigate to the specified url (e.g. https://your-fqdn/firefox)
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/calibre.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf

sed -i 's/calibre/firefox''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf
sed -i 's/    set $upstream_port 8080;/    set $upstream_port 3000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/firefox.subfolder.conf

##################################################################################################################################
# Homer - https://github.com/bastienwirtz/homer
#         https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md

cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml.bak

sed -i 's/title: \"Demo dashboard\"/title: \"Dashboard - '"$fqdn"'\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml
sed -i 's/subtitle: \"Homer\"/subtitle: \"IP: '"$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)"'\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml
sed -i 's/  - name: \"another page!\"/\#  - name: \"another page!\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml
sed -i 's/      icon: \"fas fa-file-alt\"/#      icon: \"fas fa-file-alt\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml
sed -i 's/          url: \"\#additionnal-page\"/#          url: \"\#additionnal-page\"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml
sed -i 's/    icon: "fas fa-file-alt"/#    icon: "fas fa-file-alt"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml
sed -i 's/    url: "#additionnal-page"/#    url: "#additionnal-page"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml

# Throw everything over line 73
sed -i '73,$ d' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml

#  Add the links to other services installed above
echo "    items:
      - name: \"Firefox (N.eko)\"
        logo: \"assets/tools/sample.png\"
        # subtitle: \"Network-wide Ad Blocking\" # optional, if no subtitle is defined, PiHole statistics will be shown
        tag: \"other\"
        url: \"http://$fqdn/neko\"
        type: \"PiHole\" # optional, loads a specific component that provides extra features. MUST MATCH a file name (without file extension) available in \"src/components/services\"
        target: \"_blank\" # optional html a tag target attribute
        # class: \"green\" # optional custom CSS class for card, useful with custom stylesheet
        # background: red # optional color for card to set color directly without custom stylesheet
      - name: \"Firefox (Guacamole)\"
        logo: \"assets/tools/sample.png\"
        # subtitle: \"Network-wide Ad Blocking\" # optional, if no subtitle is defined, PiHole statistics will be shown
        tag: \"other\"
        url: \"http://$fqdn/firefox\"
        type: \"PiHole\" # optional, loads a specific component that provides extra features. MUST MATCH a file name (without file extension) available in \"src/components/services\"
        target: \"_blank\" # optional html a tag target attribute
        # class: \"green\" # optional custom CSS class for card, useful with custom stylesheet
        # background: red # optional color for card to set color directly without custom stylesheet
      - name: \"Pi-hole\"
        logo: \"assets/tools/sample.png\"
        # subtitle: \"Network-wide Ad Blocking\" # optional, if no subtitle is defined, PiHole statistics will be shown
        tag: \"other\"
        url: \"http://$fqdn/pihole/admin\"
        type: \"PiHole\" # optional, loads a specific component that provides extra features. MUST MATCH a file name (without file extension) available in \"src/components/services\"
        target: \"_blank\" # optional html a tag target attribute
        # class: \"green\" # optional custom CSS class for card, useful with custom stylesheet
        # background: red # optional color for card to set color directly without custom stylesheet
      - name: \"Syncthing\"
        logo: \"assets/tools/sample.png\"
        # subtitle: \"Network-wide Ad Blocking\" # optional, if no subtitle is defined, PiHole statistics will be shown
        tag: \"other\"
        url: \"http://$fqdn/syncthing\"
        type: \"PiHole\" # optional, loads a specific component that provides extra features. MUST MATCH a file name (without file extension) available in \"src/components/services\"
        target: \"_blank\" # optional html a tag target attribute
        # class: \"green\" # optional custom CSS class for card, useful with custom stylesheet
        # background: red # optional color for card to set color directly without custom stylesheet
      - name: \"Tor\"
        logo: \"assets/tools/sample.png\"
        # subtitle: \"Network-wide Ad Blocking\" # optional, if no subtitle is defined, PiHole statistics will be shown
        tag: \"other\"
        url: \"http://$fqdn/tor\"
        type: \"PiHole\" # optional, loads a specific component that provides extra features. MUST MATCH a file name (without file extension) available in \"src/components/services\"
        target: \"_blank\" # optional html a tag target attribute
        # class: \"green\" # optional custom CSS class for card, useful with custom stylesheet
        # background: red # optional color for card to set color directly without custom stylesheet
      - name: \"Whoogle\"
        logo: \"assets/tools/sample.png\"
        # subtitle: \"Network-wide Ad Blocking\" # optional, if no subtitle is defined, PiHole statistics will be shown
        tag: \"other\"
        url: \"http://$fqdn/whoogle\"
        type: \"PiHole\" # optional, loads a specific component that provides extra features. MUST MATCH a file name (without file extension) available in \"src/components/services\"
        target: \"_blank\" # optional html a tag target attribute
        # class: \"green\" # optional custom CSS class for card, useful with custom stylesheet
        # background: red # optional color for card to set color directly without custom stylesheet" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/homer/config.yml

##################################################################################################################################
#  libretranslate - will not run on a subfolder!

#  Prepare the libretranslate proxy-conf file using syncthing.subdomain.conf.sample as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/translate.subdomain.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/translate.subdomain.conf
sed -i 's/syncthing/translate''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf
sed -i 's/    server_name syncthing./    server_name '$ltsubdomain'.''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/translate.subdomain.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/translate.subdomain.conf

##################################################################################################################################
#  Prepare the neko proxy-conf file using syncthing.subfolder.conf as a template

cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf

sed -i 's/syncthing/homer''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf

sed -i '3 i  
' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf
sed -i '4 i location / {' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf
sed -i '5 i    return 301 $scheme://$host/homer/;' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf
sed -i '6 i }' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf
sed -i '7 i 
' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/homer.subfolder.conf

##################################################################################################################################
# Neko firefox browser

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

docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
echo "lockPref(\"identity.sync.tokenserver.uri\", \"https://aqj9z.mine.nu/f4c4hm/token/1.0/sync/1.5\");" >> /usr/lib/firefox/mozilla.cfg
EOF

docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
sed -i 's/lockPref(/pref(''/g' /usr/lib/firefox/mozilla.cfg
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

##################################################################################################################################
# Neko Tor browser

#  Prepare the neko proxy-conf file using syncthing.subfolder.conf as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/tor.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/tor.subfolder.conf
sed -i 's/syncthing/tor''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/tor.subfolder.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/tor.subfolder.conf

##################################################################################################################################
# Pihole

#  Prepare the pihole container
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf

# Ensure ownership of the 'etc-pihole' folder is set properly.
chown systemd-coredump:systemd-coredump /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/pihole/etc-pihole
#  This below step may not be needed.  Need to deploy to a server and check
#  Allow syncthing to write to the 'etc-pihole' directory so it can sync properly
#chmod 777 /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/pihole/etc-pihole

#  Route all traffic including localhost traffci through the pihole
#  https://www.tecmint.com/find-my-dns-server-ip-address-in-linux/
sed -i 's/nameserver 8.8.8.8/nameserver '$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)'/g' /etc/resolv.conf

##################################################################################################################################
#  rss-proxy - will not run on a subfolder!

#  Prepare the rss-proxy proxy-conf file using syncthing.subdomain.conf.sample as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/rssproxy.subdomain.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/rssproxy.subdomain.conf
sed -i 's/syncthing/rssproxy''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf
sed -i 's/    server_name syncthing./    server_name '$rpsubdomain'.''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/rssproxy.subdomain.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 3000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/rssproxy.subdomain.conf

##################################################################################################################################
# Syncthing

#  Prepare the syncthing proxy-conf file
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf

#  Add a cron job to reset the permissions of the pihole directory if any changes are made - checks once per minute
#  Don't put ' around the commmand!  And, it must be run as root!
(crontab -l 2>/dev/null || true; echo "* * * * * chmod 777 -R /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/pihole/etc-pihole") | crontab -

#  When you set up the syncs for pihole, ensure you check 'Ignore Permissions' under the 'Advanced' tab during folder setup.

##################################################################################################################################
#  Wireguard gui - will not run on a subfolder!

#  Prepare the wireguard gui (wgui) proxy-conf file using syncthing.subdomain.conf.sample as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf
sed -i 's/syncthing/wgui''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf
sed -i 's/    server_name syncthing./    server_name '$wgsubdomain'.''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/wgui.subdomain.conf

##################################################################################################################################
#  Whoogle

#  Prepare the whoogle proxy-conf file using syncthing.subfolder.conf as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf
sed -i 's/syncthing/whoogle''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf

##################################################################################################################################
#  Perform some SWAG hardening:
#    https://virtualize.link/secure/

echo "
#  Additional SWAG hardening - https://virtualize.link/secure/" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf
#  No more Google FLoC
echo "add_header Permissions-Policy \"interest-cohort=()\";" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf
#  X-Robots-Tag - prevent applications from appearing in results of search engines and web crawlers
echo "add_header X-Robots-Tag \"noindex, nofollow, nosnippet, noarchive\";" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf
#  Enable HTTP Strict Transport Security (HSTS) 
echo "add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/ssl.conf

##################################################################################################################################
#  Seal a recently (Jan-2022) revealead vulnerabilty - https://arstechnica.com/information-technology/2022/01/a-bug-lurking-for-12-years-gives-attackers-root-on-every-major-linux-distro/

chmod 0755 /usr/bin/pkexec

##################################################################################################################################

echo "
Cleaning up and restarting the stack for the final time...
"

#  Need to restart the stack
docker stop $(sudo docker ps | grep $stackname | awk '{ print$1 }')
docker system prune
docker-compose -f docker-compose.yml -p $stackname up -d 
docker restart $(sudo docker ps | grep $stackname | awk '{ print$1 }')

##################################################################################################################################
#  Store non-persistent variables in .bashrc for later use across reboots
echo "
" >> ~/.bashrc
echo "export authusr=$authusr" >> ~/.bashrc
echo "export authpwd=$authpwd" >> ~/.bashrc
echo "export rootdir=$rootdir" >> ~/.bashrc
echo "export stackname=$stackname" >> ~/.bashrc
echo "export swagloc=$swagloc" >> ~/.bashrc

# Commit the .bashrc changes
source ~/.bashrc

echo "
Keeps these in a safe place for future reference:

===============================================================================
Fully qualified domain name (FQDN): $fqdn
Subdomains:                         $subdomains
Authelia userid:                    $authusr
Authelia password:                  $authpwd
Neko user password:                 $nupass
Neko admin password:                $napass
Pihole admin password:              $pipass
Wireguard userid:                   $wguid
Wireguard password:                 $wgpass
Jitsi-meet web:                     $jwebsubdomain.$fqdn
Libretranslate:                     $ltsubdomain.$fqdn
RSS-Proxy:                          $rpsubdomain.$fqdn
Shadowsocks password:               $sspass
Synapse (Matrix Server):            
E-Mail Server:                      
===============================================================================

Now you may want to restart the box.  Either way navigate to your fqdn: 

     'https://$fqdn'

Tell Authelia the secondary authentication you want, like TOTP and then
after your first login attempt, use your ssh terminal to get the 
authentication url using these commands:

      'ssh "$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"@"$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)" -p "$(cat /etc/ssh/sshd_config | grep Port | head -1 | awk '{print $2}')"'

      'sudo cat /home/"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"/docker/authelia/notification.txt | grep http'
 "
#  This last part about cat'ing out the url is there beacuase I was unable to get email authentication working

##################################################################################################################################
#  Jitsi meet server
#  https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker
#  https://github.com/jitsi/jitsi-meet-electron/releases
#  https://scribe.rip/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71

#!/bin/bash

jitsilatest=stable-6826
extractdir=docker-jitsi-meet-$jitsilatest
stackname=authelia_swag # Can remove later
fqdn=      # Can remove later
jcontdir=jitsi-meet
jwebsubdomain=
swagloc=swag

echo /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir
echo /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$jcontdir

rm stable-6826.tar.gz
rm -r /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir
rm -r /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$jcontdir

wget https://github.com/jitsi/docker-jitsi-meet/archive/refs/tags/$jitsilatest.tar.gz
tar -xzsf $jitsilatest.tar.gz

cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/env.example /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

/home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/gen-passwords.sh

mkdir -p /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$jcontdir/{web/crontabs,web/letsencrypt,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

mypath="/home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"
mypath=${mypath//\//\\/}

sed -i 's/CONFIG=~\/.jitsi-meet-cfg/CONFIG='$mypath'\/docker\/'$jcontdir'/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

sed -i 's/HTTP_PORT=8000/HTTP_PORT=8181/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#PUBLIC_URL=https:\/\/meet.example.com/PUBLIC_URL=https:\/\/'$jwebsubdomain'.'$fqdn'/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_LOBBY=1/ENABLE_LOBBY=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_AV_MODERATION=1/ENABLE_AV_MODERATION=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_PREJOIN_PAGE=0/ENABLE_PREJOIN_PAGE=0/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_WELCOME_PAGE=1/ENABLE_WELCOME_PAGE=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_CLOSE_PAGE=0/ENABLE_CLOSE_PAGE=0/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_NOISY_MIC_DETECTION=1/ENABLE_NOISY_MIC_DETECTION=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

#  If having any issues with nginx not picking up the letsencrypt certificate see:
#  https://github.com/jitsi/docker-jitsi-meet/issues/92
sed -i 's/\#ENABLE_LETSENCRYPT=1/\#ENABLE_LETSENCRYPT=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#LETSENCRYPT_DOMAIN=meet.example.com/LETSENCRYPT_DOMAIN='$jwebsubdomain'.'$fqdn'/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#LETSENCRYPT_EMAIL=alice@atlanta.net/LETSENCRYPT_EMAIL='$(openssl rand -hex 25)'@'$(openssl rand -hex 25)'.net/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#LETSENCRYPT_USE_STAGING=1/\#LETSENCRYPT_USE_STAGING=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

# Use the staging server (for avoiding rate limits while testing)
#LETSENCRYPT_USE_STAGING=1

sed -i 's/\#ENABLE_AUTH=1/ENABLE_AUTH=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#ENABLE_GUESTS=1/ENABLE_GUESTS=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's/\#AUTH_TYPE=internal/AUTH_TYPE=internal/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

# Enabling these will stop swag from picking up the container on port 80
#sed -i 's/\#ENABLE_HTTP_REDIRECT=1/ENABLE_HTTP_REDIRECT=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
#sed -i 's/\# ENABLE_HSTS=1/ENABLE_HSTS=1/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

sed -i 's///g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's///g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's///g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's///g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's///g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env
sed -i 's///g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

# https://community.jitsi.org/t/you-have-been-disconnected-on-fresh-docker-installation/89121/10
# Solution below:
echo "

# Added based on this - https://community.jitsi.org/t/you-have-been-disconnected-on-fresh-docker-installation/89121/10
ENABLE_XMPP_WEBSOCKET=0" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/.env

cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml.bak

# Rename the web gui docker container
sed -i 's/    web:/    jitsiweb:/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml

# Prevent guests from creating rooms or joining until a moderator has joined
sed -i 's/            - ENABLE_AUTO_LOGIN/            #- ENABLE_AUTO_LOGIN/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml

# Add the required netowrks for compatability with other containers
sed -i ':a;N;$!ba;s/        networks:\n            meet.jitsi:\n/        networks:\n            no-internet:\n            meet.jitsi:\n/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml
sed -i ':a;N;$!ba;s/networks:\n    meet.jitsi:\n//g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml
echo "networks:
    no-internet:
      driver: bridge
      internal: true
    internet:
      driver: bridge
      ipam:
        driver: default
        config:
          - subnet: 172.20.10.0/24
            gateway: 172.20.10.1
    meet.jitsi:
      driver: bridge
      internal: true" >> /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml

#  Jitsi video bridge (jvb) container needs access to the internet for video and audio to work (4th instance)
sed -i ':a;N;$!ba;s/        networks:\n            no-internet:\n            meet.jitsi:\n/        networks:\n            no-internet:\n            internet:\n            meet.jitsi:\n/4' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml

#  Prepare the jitsi-meet proxy-conf file using syncthing.subdomain.conf as a template
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf

# If you enable authelia, users will need additional credentials to log on, so, maybe don't do that :)
#sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf
sed -i 's/syncthing/jitsiweb''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf
sed -i 's/server_name jitsiweb./server_name '$jwebsubdomain'.''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 80;''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf

#  Up the docker containers
docker-compose -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/$extractdir/docker-compose.yml -p $stackname up -d 

# Add a moderator user.  Change 'userid' and 'password' to something secure like 'UjcvJ4jb' and 'QBo3fMdLFpShtkg2jvg2XPCpZ4NkDf3zp6Xn6Ndf'
docker exec -i $(sudo docker ps | grep prosody | awk '{print $NF}') bash <<EOF
prosodyctl --config /config/prosody.cfg.lua register userid meet.jitsi password
EOF

##################################################################################################################################
#  rss-proxy - Will not run on a subfolder, need to use a subdomain

version: "3.5"
services:
  rss-proxy:
    image: damoeb/rss-proxy:js
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
#    volumes:
#      - /home/folder/docker/rss-proxy:/opt/rss-proxy
#    Don't expose external ports to prevent access outside swag
#    ports:
#      - 3000:3000
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
# For networking setup explaination, see this link:
#   https://stackoverflow.com/questions/39913757/restrict-internet-access-docker-container
networks:
   no-internet:
     driver: bridge
     internal: true
   internet:
     driver: bridge
     ipam:
       driver: default
       config:
         - subnet: "172.20.10.0/24"
           gateway: 172.20.10.1

##################################################################################################################################
#  libretranslate - Will not run on a subfolder, need to use a subdomain

version: "3.5"
services:
  translate:
    image: libretranslate/libretranslate
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    #build: .
#    Don't expose external ports to prevent access outside swag
#    ports:
#      - 5000:5000
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
    ## Uncomment below command and define your args if necessary
    # command: --ssl --ga-id MY-GA-ID --req-limit 100 --char-limit 500 
    command: --ssl
# For networking setup explaination, see this link:
#   https://stackoverflow.com/questions/39913757/restrict-internet-access-docker-container
networks:
   no-internet:
     driver: bridge
     internal: true
   internet:
     driver: bridge
     ipam:
       driver: default
       config:
         - subnet: "172.20.10.0/24"
           gateway: 172.20.10.1

##################################################################################################################################
#  Synapse matrix server
#  https://github.com/mfallone/docker-compose-matrix-synapse/blob/master/docker-compose.yaml
version: '3'
services:
  synapse:
    container_name: synapse
    hostname: ${MATRIX_HOSTNAME}
    build:
        context: ../..
        dockerfile: docker/Dockerfile
    image: docker.io/matrixdotorg/synapse:latest
    restart: unless-stopped
    environment:
      - SYNAPSE_SERVER_NAME=${MATRIX_HOSTNAME}
      - SYNAPSE_REPORT_STATS=yes
      - SYNAPSE_NO_TLS=1
      #- SYNAPSE_ENABLE_REGISTRATION=no
      #- SYNAPSE_CONFIG_PATH=/config
      # - SYNAPSE_LOG_LEVEL=DEBUG
      - SYNAPSE_REGISTRATION_SHARED_SECRET=${REG_SHARED_SECRET}
      - POSTGRES_DB=synapse
      - POSTGRES_HOST=synapsedb
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - synapse-data:/data
    depends_on:
      - synapsedb
    # In order to expose Synapse, remove one of the following, you might for
    # instance expose the TLS port directly:
    # ports:
    #   - 8448:8448/tcp
    networks:
      no-internet:
      internet:

  synapsedb:
    container_name: postgres
    image: docker.io/postgres:10-alpine
    environment:
      - POSTGRES_DB=synapse
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      no-internet:
networks:
   no-internet:
     driver: bridge
     internal: true
   internet:
     driver: bridge
     ipam:
       driver: default
       config:
         - subnet: "172.20.10.0/24"
           gateway: 172.20.10.1
           
#https://hub.docker.com/r/hwdsl2/ipsec-vpn-server
#https://hub.docker.com/r/adrum/wireguard-ui
#https://github.com/EmbarkStudios/wg-ui
#https://hub.docker.com/r/dockage/shadowsocks-server
#openvpn
#ptpp
#onionshare

#  https://adfinis.com/en/blog/how-to-set-up-your-own-matrix-org-homeserver-with-federation/
#  Run first to generate the homeserver.yaml file
docker run -it --rm -v /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/synapse/data:/data -e SYNAPSE_SERVER_NAME=subdomain.domain.name -e SYNAPSE_REPORT_STATS=no -e SYNAPSE_HTTP_PORT=desiredportnumber -e PUID=1000 -e PGID=1000 matrixdotorg/synapse:latest generate
docker exec -it synapse register_new_matrix_user -u myuser -p mypw -a -c /data/homeserver.yaml

#  https://github.com/matrix-org/synapse/issues/6783
docker exec -it $(sudo docker ps | grep synapse | awk '{ print$NF }') register_new_matrix_user http://localhost:8008 -u myuser -p mypw -a -c /data/homeserver.yaml
sudo docker ps | grep synapse | awk '{ print$NF }'

cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/synapse.subdomain.conf.sample \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/synapse.subdomain.conf

sed -i 's/matrix/'$sysubdomain'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/$swagloc/nginx/proxy-confs/synapse.subdomain.conf






#  farside - https://github.com/benbusby/farside
#  Download the latest copy of radis - https://redis.io/
#  wget https://download.redis.io/releases/redis-6.2.6.tar.gz
#  Unpack the tarball
#  tar -xzsf redis-6.2.6.tar.gz
#  Install elixer - https://elixir-lang.org/install.html
#  sudo apt install redis-server
#  wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && sudo dpkg -i erlang-solutions_2.0_all.deb
#  sudo apt-get update
#  sudo apt-get install esl-erlang
#  sudo apt-get install elixir









