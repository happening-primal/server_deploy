#!/bin/bash

# ToDo:
#  1.  Configure iptable rules
#  2.  Wireguard
#  3.  OpenVPN
#  4.  Shadowsocks
#  5.  ShadowVPN
#  For these VPN options, see the following - https://github.com/vimagick/dockerfiles
#https://hub.docker.com/r/hwdsl2/ipsec-vpn-server
#https://hub.docker.com/r/adrum/wireguard-ui
#https://github.com/EmbarkStudios/wg-ui
#https://hub.docker.com/r/dockage/shadowsocks-server
#openvpn
#ptpp
#onionshare

echo "
 - Run this script as superuser.
"

# Detect Root
if [[ "${EUID}" -ne 0 ]]; then
  echo "This installer needs to be run with superuser privileges." >&2
  exit 1
fi

##################################################################################################################################
#  Global Variables
stackname=authelia_swag  # Docker stack name
swagloc=swag # Directory for Secure Web Access Gateway (SWAG)
rootdir=/home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')

#  External IP address
myip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

#  Wireguard port
wgport=50220

#  Header for docker-compose .yml files
ymlhdr="version: \"3.1\"
services:"

#  Footer for docker-compose .yml files
ymlftr="networks:
# For networking setup explaination, see this link:
#   https://stackoverflow.com/questions/39913757/restrict-internet-access-docker-container
# For ways to see how to set up specific networks for docker see:
#   https://www.cloudsavvyit.com/14508/how-to-assign-a-static-ip-to-a-docker-container/
#   Note the requirement to remove existing newtorks using:
#     docker network ls | grep authelia_swag | awk '{ print\$1 }' | docker network rm;
    no-internet:
      driver: bridge
      internal: true
    internet:
      driver: bridge
      ipam:
        driver: default
        config:
          - subnet: 172.20.10.0/24
            gateway: 172.20.10.1"

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
                docker network ls | grep $stackname | awk '{ print$1 }' | docker network rm;
                #  Purge any dangling items...
                docker system prune;
                #  Remove the docker directory
                rm -r docker;
                #  Make a new, fresh docker directory
                mkdir docker;
                #chown $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')":"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root') -R docker;
                break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "
"

##################################################################################################################################

#  Installation section

##################################################################################################################################
#  Secure Web Access Gateway (SWAG).  Set this one up first because all the other web services
#  created later use it and it's configuration files.

# Because of the limitation on setting wildcard domains using http we have to specify each domain,
# one by one.  The following will automate the process for you by generating the specified
# number of 8 digit random subdomain names.  Adds www by default.  See swag docker-compose.yml
# output file for further infrormation.  Also adds required domains for subsequent services
# that require a subdomain such as jitsi-meet, libretranslate, and rss-proxy.

while true; do
  read -rp "
Enter your fully qualified domain name (FQDN) from your DNS provider - would look like 'example.com': " fqdn
  if [[ -z "${fqdn}" ]]; then
    echo "Enter your fully qualified domain name (FQDN) from your DNS provider or hit ctrl+C to exit."
    continue
  fi
  break
done

# Create domain string
subdomains="www"
#  Add a few specific use case subdomains
#  farside
fssubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$fssubdomain
#  libretranslate
ltsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$ltsubdomain
#  jitsiweb
jwebsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$jwebsubdomain
#  rss-proxy
rpsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$rpsubdomain
#  synapse
sysubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$sysubdomain
#  wireguard gui
wgsubdomain=$(echo $RANDOM | md5sum | head -c 8)
subdomains+=", "
subdomains+=$wgsubdomain

while true; do
  read -rp "
How many random subdomains would you like to generate?: " rnddomain
  if [[ -z "${rnddomain}" ]]; then
    echo "Enter the number of random subdomains would you like to generate or hit ctrl+C to exit."
    continue
  fi
  break
done

# Domain and DNS setup section
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

#  Create the docker-compose file
containername=swag
ymlname=$rootdir/$containername-compose.yml
mkdir -p docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  swag:
    image: linuxserver/swag
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
      #- SUBDOMAINS=wildcard  #  Won't work with current letsencrypt policies as per the above
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
      # You must leave port 80 open or you won't be able to get your ssl certificates via http
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

# Make sure the stack started properly by checking for the existence of ssl.conf
while [ ! -f $rootdir/docker/$swagloc/nginx/ssl.conf ]
    do
      sleep 5
    done

#  Perform some SWAG hardening:
#    https://virtualize.link/secure/
echo "
#  Additional SWAG hardening - https://virtualize.link/secure/" >> $rootdir/docker/$swagloc/nginx/ssl.conf
#  No more Google FLoC
echo "add_header Permissions-Policy \"interest-cohort=()\";" >> $rootdir/docker/$swagloc/nginx/ssl.conf
#  X-Robots-Tag - prevent applications from appearing in results of search engines and web crawlers
echo "add_header X-Robots-Tag \"noindex, nofollow, nosnippet, noarchive\";" >> $rootdir/docker/$swagloc/nginx/ssl.conf
#  Enable HTTP Strict Transport Security (HSTS)
echo "add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;" >> $rootdir/docker/$swagloc/nginx/ssl.conf

##################################################################################################################################
#  Authelia setup

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

#  Generate some of the variables that will be used later but that the user does
#  not need to keep track of
#    https://linuxhint.com/generate-random-string-bash/
jwts=$(openssl rand -hex 40)     # Authelia JWT secret
auths=$(openssl rand -hex 40)    # Authelia secret
authec=$(openssl rand -hex 40)   # Authelia encryption key

#  Create the docker-compose file
swagyml=$ymlname
containername=authelia
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    image: authelia/authelia:latest #4.32.0
    environment:
      - TZ=America/New_York
    volumes:
      - $rootdir/docker/$containername:/config
    networks:
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
 done

# Make sure the stack started properly by checking for the existence of users_database.yml
while [ ! -f $rootdir/docker/$containername/configuration.yml ]
    do
      sleep 5
    done

#  Comment out all the lines in the ~/docker/authelia/configuration.yml.bak configuration file
sed -e 's/^\([^#]\)/#\1/g' -i $rootdir/docker/$containername/configuration.yml

#  Uncomment/modify the required lines in the /docker/authelia/configuration.yml.bak file
sed -i 's/\#---/---''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#theme: light/theme: light''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#jwt_secret: a_very_important_secret/jwt_secret: '"$jwts"'''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#default_redirection_url: https:\/\/home.example.com\/default_redirection_url: https:\/\/"$fqdn"\//''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#server:/server:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  host: 0.0.0.0/  host: 0.0.0.0''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  port: 9091/  port: 9091''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  path: ""/  path: \"authelia\"''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  read_buffer_size: 4096/  read_buffer_size: 4096''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  write_buffer_size: 4096/  write_buffer_size: 4096''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#log:/log:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  level: debug/  level: debug''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#totp:/totp:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  algorithm: sha1/  algorithm: sha1''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  digits: 6/  digits: 6''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  period: 30/  period: 30''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  skew: 1/  skew: 1''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#authentication_backend:/authentication_backend:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  disable_reset_password: false/  disable_reset_password: false''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \# file:/  file:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#   path: \/config\/users_database.yml/    path: \/config\/users_database.yml''/g' $rootdir/docker/$containername/configuration.yml
sed -i ':a;N;$!ba;s/\#  \#   password:/    password:''/1' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#     algorithm: argon2id/      algorithm: argon2id''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#     iterations: 1/      iterations: 1''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#     key_length: 32/      key_length: 32''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#     salt_length: 16/      salt_length: 16''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#     memory: 1024/      memory: 1024''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#     parallelism: 8/      parallelism: 8''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#access_control:/access_control:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  default_policy: deny/  default_policy: deny''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  rules:/  rules:''/g' $rootdir/docker/$containername/configuration.yml
sed -i ':a;N;$!ba;s/\#    - domain:/    - domain:''/3' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#        - secure.example.com/      - '"$fqdn"'''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#        - private.example.com/      - \"*.'"$fqdn"'\"''/g' $rootdir/docker/$containername/configuration.yml
sed -i ':a;N;$!ba;s/\#      policy: two_factor/      policy: two_factor''/1' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#session:/session:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  name: authelia_session/  name: authelia_session''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  domain: example.com/  domain: '"$fqdn"'''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  secret: insecure_session_secret/  secret: '"$auths"'''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  expiration: 1h/  expiration: 12h''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  inactivity: 5m/  inactivity: 1h''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  remember_me_duration: 1M/  remember_me_duration: 1M''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#regulation:/regulation:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  max_retries: 3/  max_retries: 3''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  find_time: 2m/  find_time: 2m''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  ban_time: 5m/  ban_time: 5m''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#storage:/storage:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \# encryption_key: you_must_generate_a_random_string_of_more_than_twenty_chars_and_configure_this/  encryption_key: '"$authec"'''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \# local:/  local:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#   path: \/config\/db.sqlite3/    path: \/config\/db.sqlite3''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#notifier:/notifier:''/g' $rootdir/docker/$containername/configuration.yml
sed -i ':a;N;$!ba;s/\#  disable_startup_check: false/  disable_startup_check: false''/2' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \# filesystem:/  filesystem:''/g' $rootdir/docker/$containername/configuration.yml
sed -i 's/\#  \#   filename: \/config\/notification.txt/    filename: \/config\/notification.txt''/g' $rootdir/docker/$containername/configuration.yml
# Yeah, that was exhausting...

#  Restart Authelia so that it will generate the users_database.yml file
docker-compose -f $ymlname -p $stackname down
docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
 done

# Make sure the stack started properly by checking for the existence of users_database.yml
while [ ! -f $rootdir/docker/$containername/users_database.yml ]
    do
      sleep 5
    done

# Make a backup of the clean authelia configuration file if needed
while [ ! -f $rootdir/docker/$containername/users_database.yml.bak ]
    do
      cp $rootdir/docker/$containername/users_database.yml \
         $rootdir/docker/$containername/users_database.yml.bak;
    done

#  Comment out all the lines in the ~/docker/authelia/users_database.yml configuration file
sed -e 's/^\([^#]\)/#\1/g' -i $rootdir/docker/$containername/users_database.yml

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
..." >> $rootdir/docker/$containername/users_database.yml

sed -i 's/\#---/---''/g' $rootdir/docker/$containername/users_database.yml

# Mind the $ signs and forward slashes / :(

#  Configure the swag proxy-confs files
# Update the swag nginx default landing page to redirect to Authelia authentication
sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;''/g' $rootdir/docker/$swagloc/nginx/site-confs/default
sed -i 's/\    location \/ {/#    location \/ {''/g' $rootdir/docker/$swagloc/nginx/site-confs/default
sed -i 's/\        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;/#        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;''/g' $rootdir/docker/$swagloc/nginx/site-confs/default
sed -i ':a;N;$!ba;s/\    }/#    }''/1' $rootdir/docker/$swagloc/nginx/site-confs/default

#  Restart the stack to get the configuration changes committed
#docker-compose -f $ymlname -p $stackname down
#docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

##################################################################################################################################
#  Farside rotating redirector written in elixer by ben busby
#    https://github.com/benbusby/farside

#  Download the latest copy of radis - https://redis.io/
#  wget https://download.redis.io/releases/redis-6.2.6.tar.gz
#  Unpack the tarball
#  tar -xzsf redis-6.2.6.tar.gz
#  Install elixer - https://elixir-lang.org/install.html
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && sudo dpkg -i erlang-solutions_2.0_all.deb
rm erlang-solutions_2.0_all.deb
apt-get -qq update
#  Install redis server
apt install -y -qq redis-server
apt-get install -y -qq esl-erlang
apt-get install -y -qq elixir
#  Download farside
wget https://github.com/benbusby/farside/archive/refs/tags/v0.1.0.tar.gz
tar -xzsf v0.1.0.tar.gz
cd $rootdir/farside-0.1.0
#  Run the below from within the unpacked farside folder (farside-0.1.0)
#  redis-server
mix.exs mix deps.get
mix run -e Farside.Instances.sync
elixir --erl "-detached" -S mix run --no-halt
#  Uses localhost:4001
#  edit farside-0.1.0/services.json if you desire to control the instances of redirects
#  such as if you want to create your own federated list of servers to choose from
#  in a less trusted model (e.g. yourserver.1, yourserver.2, yourserver.3...) ;)
cd $rootdir
rm -f v0.1.0.tar.gz

#  Enable swag capture of farside
#  Prepare the farside proxy-conf file using using syncthing.subdomain.conf.sample as a template
containername=farside

destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

#  Enabling authelia capture will greatly reduce the effectiveness of farside but opens you up to
#  access to anyone on the internet.  Tradeoff...
#sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;''/g' $destconf
#sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/'$containername'''/g' $destconf
#  Set the $upstream_app parameter to the ethernet IP address so it can be accessed from docker (swag)
sed -i 's/        set $upstream_app farside;/        set $upstream_app '$myip';''/g' $destconf
sed -i 's/    server_name '$containername'./    server_name '$fssubdomain'.''/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 4001;''/g' $destconf

##################################################################################################################################
# Firefox - linuxserver.io
#  Create the docker-compose file
containername=firefox
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:  # linuxserver.io firefox browser
    image: lscr.io/linuxserver/firefox
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
      - SUBFOLDER=/firefox/ # Required if using authelia to authenticate
    volumes:
      - $rootdir/docker/$containername:/config
    #ports:
      #- 3000:3000 # WebApp port, don't publish this to the outside world - only proxy through swag/authelia
    shm_size: \"1gb\"
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the homer proxy-conf file using syncthing.subfolder.conf as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/calibre.subfolder.conf.sample $destconf

sed -i 's/calibre/firefox''/g' $destconf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/    set $upstream_port 8080;/    set $upstream_port 3000;''/g' $destconf

##################################################################################################################################
# Homer - https://github.com/bastienwirtz/homer
#         https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md
#  Create the docker-compose file
containername=homer
ymlname=$rootdir/$containername-compose.yml
mkdir -p docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    image: b4bz/homer
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

# Make sure the stack started properly by checking for the existence of config.yml
while [ ! -f $rootdir/docker/$containername/config.yml ]
    do
      sleep 5
    done

#  Create a backup of the config.yml file if needed
while [ ! -f $rootdir/docker/$containername/config.yml.bak ]
    do
      cp $rootdir/docker/$containername/config.yml \
         $rootdir/docker/$containername/config.yml.bak;
    done

sed -i 's/title: \"Demo dashboard\"/title: \"Dashboard - '"$fqdn"'\"''/g' $rootdir/docker/$containername/config.yml
sed -i 's/subtitle: \"Homer\"/subtitle: \"IP: '"$myip"'\"''/g' $rootdir/docker/$containername/config.yml
sed -i 's/  - name: \"another page!\"/\#  - name: \"another page!\"''/g' $rootdir/docker/$containername/config.yml
sed -i 's/      icon: \"fas fa-file-alt\"/#      icon: \"fas fa-file-alt\"''/g' $rootdir/docker/$containername/config.yml
sed -i 's/          url: \"\#additionnal-page\"/#          url: \"\#additionnal-page\"''/g' $rootdir/docker/$containername/config.yml
sed -i 's/    icon: "fas fa-file-alt"/#    icon: "fas fa-file-alt"''/g' $rootdir/docker/$containername/config.yml
sed -i 's/    url: "#additionnal-page"/#    url: "#additionnal-page"''/g' $rootdir/docker/$containername/config.yml

# Throw everything over line 73
sed -i '73,$ d' $rootdir/docker/$containername/config.yml

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
        # background: red # optional color for card to set color directly without custom stylesheet" >> $rootdir/docker/homer/config.yml

#  Prepare the homer proxy-conf file using syncthing.subfolder.conf as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

sed -i 's/syncthing/'$containername'''/g' $destconf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;''/g' $destconf

sed -i '3 i  
' $destconf
sed -i '4 i location / {' $destconf
sed -i '5 i    return 301 $scheme://$host/'$containername'/;' $destconf
sed -i '6 i }' $destconf
sed -i '7 i 
' $destconf

##################################################################################################################################
#  Jitsi meet server
#  https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker
#  https://github.com/jitsi/jitsi-meet-electron/releases
#  https://scribe.rip/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71

#  Jitsi Broadcasting Infrastructure (Jibri) - https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker#advanced-configuration
#  Install dependencies
apt-get install -y -qq linux-image-extra-virtual

jitsilatest=stable-6826
extractdir=docker-jitsi-meet-$jitsilatest
jcontdir=jitsi-meet
containername=jitsi-meet
jmoduser=userid
jmodpass=password

rm stable-6826.tar.gz
rm -r $rootdir/$extractdir
rm -r $rootdir/docker/$containername

mkdir -p $rootdir/docker/$containername/{web/crontabs,web/letsencrypt,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

wget https://github.com/jitsi/docker-jitsi-meet/archive/refs/tags/$jitsilatest.tar.gz

tar -xzsf $jitsilatest.tar.gz
rm stable-6826.tar.gz

#  Copy env.example file to production (.env) if needed
while [ ! -f $rootdir/$extractdir/.env ]
    do
      cp $rootdir/$extractdir/env.example \
         $rootdir/$extractdir/.env;
    done

#  Generate some strong passwords in the .env file
$rootdir/$extractdir/gen-passwords.sh

mypath="$rootdir"
#  Fix it up for substitutions using sed by adding backslashes to escaped charaters
mypath=${mypath//\//\\/}

sed -i 's/CONFIG=~\/.jitsi-meet-cfg/CONFIG='$mypath'\/docker\/'$jcontdir'/g' $rootdir/$extractdir/.env

sed -i 's/HTTP_PORT=8000/HTTP_PORT=8181/g' $rootdir/$extractdir/.env
sed -i 's/\#PUBLIC_URL=https:\/\/meet.example.com/PUBLIC_URL=https:\/\/'$jwebsubdomain'.'$fqdn'/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_LOBBY=1/ENABLE_LOBBY=1/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_AV_MODERATION=1/ENABLE_AV_MODERATION=1/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_PREJOIN_PAGE=0/ENABLE_PREJOIN_PAGE=0/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_WELCOME_PAGE=1/ENABLE_WELCOME_PAGE=1/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_CLOSE_PAGE=0/ENABLE_CLOSE_PAGE=0/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_NOISY_MIC_DETECTION=1/ENABLE_NOISY_MIC_DETECTION=1/g' $rootdir/$extractdir/.env

#  If having any issues with nginx not picking up the letsencrypt certificate see:
#  https://github.com/jitsi/docker-jitsi-meet/issues/92
sed -i 's/\#ENABLE_LETSENCRYPT=1/\#ENABLE_LETSENCRYPT=1/g' $rootdir/$extractdir/.env
sed -i 's/\#LETSENCRYPT_DOMAIN=meet.example.com/LETSENCRYPT_DOMAIN='$jwebsubdomain'.'$fqdn'/g' $rootdir/$extractdir/.env
sed -i 's/\#LETSENCRYPT_EMAIL=alice@atlanta.net/LETSENCRYPT_EMAIL='$(openssl rand -hex 25)'@'$(openssl rand -hex 25)'.net/g' $rootdir/$extractdir/.env
sed -i 's/\#LETSENCRYPT_USE_STAGING=1/\#LETSENCRYPT_USE_STAGING=1/g' $rootdir/$extractdir/.env

# Use the staging server (for avoiding rate limits while testing) - not for production environment
#LETSENCRYPT_USE_STAGING=1

sed -i 's/\#ENABLE_AUTH=1/ENABLE_AUTH=1/g' $rootdir/$extractdir/.env
sed -i 's/\#ENABLE_GUESTS=1/ENABLE_GUESTS=1/g' $rootdir/$extractdir/.env
sed -i 's/\#AUTH_TYPE=internal/AUTH_TYPE=internal/g' $rootdir/$extractdir/.env

# Enabling these will stop swag from picking up the container on port 80
#sed -i 's/\#ENABLE_HTTP_REDIRECT=1/ENABLE_HTTP_REDIRECT=1/g' $rootdir/$extractdir/.env
#sed -i 's/\# ENABLE_HSTS=1/ENABLE_HSTS=1/g' $rootdir/$extractdir/.env

# https://community.jitsi.org/t/you-have-been-disconnected-on-fresh-docker-installation/89121/10
# Solution below:
echo "

# Added based on this - https://community.jitsi.org/t/you-have-been-disconnected-on-fresh-docker-installation/89121/10
ENABLE_XMPP_WEBSOCKET=0" >> $rootdir/$extractdir/.env

cp $rootdir/$extractdir/docker-compose.yml $rootdir/$extractdir/docker-compose.yml.bak

# Rename the web gui docker container
sed -i 's/    web:/    jitsiweb:/g' $rootdir/$extractdir/docker-compose.yml

# Prevent guests from creating rooms or joining until a moderator has joined
sed -i 's/            - ENABLE_AUTO_LOGIN/            #- ENABLE_AUTO_LOGIN/g' $rootdir/$extractdir/docker-compose.yml

# Add the required netowrks for compatability with other containers
sed -i ':a;N;$!ba;s/        networks:\n            meet.jitsi:\n/        networks:\n            no-internet:\n            meet.jitsi:\n/g' $rootdir/$extractdir/docker-compose.yml
sed -i ':a;N;$!ba;s/networks:\n    meet.jitsi:\n//g' $rootdir/$extractdir/docker-compose.yml
echo "$ymlftr
    meet.jitsi:
      driver: bridge
      internal: true" >> $rootdir/$extractdir/docker-compose.yml

#  Jitsi video bridge (jvb) container needs access to the internet for video and audio to work (4th instance)
sed -i ':a;N;$!ba;s/        networks:\n            no-internet:\n            meet.jitsi:\n/        networks:\n            no-internet:\n            internet:\n            meet.jitsi:\n/4' $rootdir/$extractdir/docker-compose.yml

#  Prepare the jitsi-meet proxy-conf file using syncthing.subdomain.conf as a template
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample \
   $rootdir/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf

# If you enable authelia, users will need additional credentials to log on, so, maybe don't do that :)
#sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $rootdir/docker/$swagloc/nginx/proxy-confs/whoogle.subfolder.conf
sed -i 's/syncthing/jitsiweb''/g' $rootdir/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf
sed -i 's/server_name jitsiweb./server_name '$jwebsubdomain'.''/g' $rootdir/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 80;''/g' $rootdir/docker/$swagloc/nginx/proxy-confs/jitsiweb.subdomain.conf

#  Bring up the docker containers
docker-compose -f $rootdir/$extractdir/docker-compose.yml -p $stackname up -d

# Add a moderator user.  Change 'userid' and 'password' to something secure like 'UjcvJ4jb' and 'QBo3fMdLFpShtkg2jvg2XPCpZ4NkDf3zp6Xn6Ndf'
docker exec -i $(sudo docker ps | grep prosody | awk '{print $NF}') bash <<EOF
prosodyctl --config /config/prosody.cfg.lua register $jmoduser meet.jitsi $jmodpass
EOF

##################################################################################################################################
#  libretranslate - will not run on a subfolder!
#  Create the docker-compose file
containername=translate
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the libretranslate proxy-conf file using syncthing.subdomain.conf.sample as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;''/g' $destconf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/'$containername'/g' $destconf
sed -i 's/    server_name '$containername'./    server_name '$ltsubdomain'.''/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' $destconf

##################################################################################################################################
# Neko firefox browser
#  Create the docker-compose file

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

containername=neko
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:  # Neko firefox browser
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the neko proxy-conf file using syncthing.subfolder.conf as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/'$containername'/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;''/g' $destconf

#  Unlock neko policies in /usr/lib/firefox/distribution/policies.json
#docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
#sed -i 's/    \"BlockAboutConfig\": true/    \"BlockAboutConfig\": false''/g' /usr/lib/firefox/distribution/policies.json
#EOF

#  Pihole may block this domain which will prevent n.eko from running - checkip.amazonaws.com

#  Wait just a bit for the container to fully deploy
sleep 5

#  Remove the policy restrictions all together :)
docker exec -i $(sudo docker ps | grep $containername | awk '{print $NF}') bash <<EOF
mv /usr/lib/firefox/distribution/policies.json /usr/lib/firefox/distribution/policies.json.bak
EOF

# Change some of the parameters in mozilla.cfg (about:config) - /usr/lib/firefox/mozilla.cfg
docker exec -i $(sudo docker ps | grep $containername | awk '{print $NF}') bash <<EOF
sed -i 's/lockPref(\"xpinstall.enabled\", false);/''/g' /usr/lib/firefox/mozilla.cfg
EOF

docker exec -i $(sudo docker ps | grep $containername | awk '{print $NF}') bash <<EOF
sed -i 's/lockPref(\"xpinstall.whitelist.required\", true);/''/g' /usr/lib/firefox/mozilla.cfg
EOF

docker exec -i $(sudo docker ps | grep $containername | awk '{print $NF}') bash <<EOF
echo "lockPref(\"identity.sync.tokenserver.uri\", \"https://aqj9z.mine.nu/f4c4hm/token/1.0/sync/1.5\");" >> /usr/lib/firefox/mozilla.cfg
EOF

docker exec -i $(sudo docker ps | grep $containername | awk '{print $NF}') bash <<EOF
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
#  Create the docker-compose file
containername=tor
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:  # Neko tor browser
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the neko proxy-conf file using syncthing.subfolder.conf as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/'$containername'/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;''/g' $destconf

###########################################################################################################################
#  rss-proxy - will not run on a subfolder!
#  Create the docker-compose file
containername=rssproxy
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    image: damoeb/rss-proxy:js
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
#    volumes:
#      - $rootdir/docker/$containername:/opt/rss-proxy
#    Don't expose external ports to prevent access outside swag
#    ports:
#      - 3000:3000
    networks:
      - internet
      - no-internet
    deploy:
      restart_policy:
       condition: on-failure
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the rss-proxy proxy-conf file using syncthing.subdomain.conf.sample as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

#  Don't capture with Authelia or you won't be able to get your RSS feeds
#sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/'$containername'/g' $destconf
sed -i 's/    server_name '$containername'./    server_name '$rpsubdomain'.''/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 3000;''/g' $destconf

##################################################################################################################################
#  Shadowsocks proxy

while true; do
  read -rp "
Enter your desired shadowsocks password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " sspass
if [[ -z "${sspass}" ]]; then
    echo "Enter your desired shadowsocks password or hit ctrl+C to exit."
    continue
  fi
  break
done

#  Create the docker-compose file
containername=shadowsocks
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    image: shadowsocks/shadowsocks-libev
    ports:
      - 58211:8388/tcp
      - 58211:8388/udp
    environment:
      - METHOD=aes-256-gcm
      - PASSWORD=$sspass
      - DNS_ADDRS=$myip # Comma delimited
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

##################################################################################################################################
#  Synapse matrix server
#  https://github.com/mfallone/docker-compose-matrix-synapse/blob/master/docker-compose.yaml

while true; do
  read -rp "
Enter your desired synapse userid - example - 'wWDmJTkPzx': " syusrid
if [[ -z "${syusrid}" ]]; then
    echo "Enter your desired synapse userid or hit ctrl+C to exit."
    continue
  fi
  break
done


while true; do
  read -rp "
Enter your desired synapse password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " sypass
if [[ -z "${sypass}" ]]; then
    echo "Enter your desired synapse password or hit ctrl+C to exit."
    continue
  fi
  break
done

#  Create the docker-compose file
containername=synapse
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername

REG_SHARED_SECRET=$(openssl rand -hex 40)
POSTGRES_USER=$(openssl rand -hex 25)
POSTGRES_PASSWORD=$(openssl rand -hex 25)

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    container_name: $containername
    hostname: ${MATRIX_HOSTNAME}
    build:
        context: ../..
        dockerfile: docker/Dockerfile
    image: docker.io/matrixdotorg/synapse:latest
    restart: unless-stopped
    environment:
      - SYNAPSE_SERVER_NAME=$containername
      - SYNAPSE_REPORT_STATS=yes
      - SYNAPSE_NO_TLS=1
      #- SYNAPSE_ENABLE_REGISTRATION=no
      #- SYNAPSE_CONFIG_PATH=/config
      # - SYNAPSE_LOG_LEVEL=DEBUG
      - SYNAPSE_REGISTRATION_SHARED_SECRET=$REG_SHARED_SECRET
      - POSTGRES_DB=synapse
      - POSTGRES_HOST=synapsedb
      - POSTGRES_USER=$POSTGRES_USER
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
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
      - POSTGRES_USER=$POSTGRES_USER
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      no-internet:
$ymlftr" >> $ymlname

#  https://adfinis.com/en/blog/how-to-set-up-your-own-matrix-org-homeserver-with-federation/
#  Run first to generate the homeserver.yaml file
docker run -it --rm -v $rootdir/docker/synapse/data:/data -e SYNAPSE_SERVER_NAME=$sysubdomain -e SYNAPSE_REPORT_STATS=no -e SYNAPSE_HTTP_PORT=8008 -e PUID=1000 -e PGID=1000 matrixdotorg/synapse:latest generate
docker exec -it synapse register_new_matrix_user -u $syusrid -p $sypass -a -c /data/homeserver.yaml

#  Wait for the stack to fully deploy
#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  https://github.com/matrix-org/synapse/issues/6783
docker exec -it $(sudo docker ps | grep $containername | awk '{ print$NF }') register_new_matrix_user http://localhost:8008 -u $syusrid -p $sypass -a -c /data/homeserver.yaml
#sudo docker ps | grep synapse | awk '{ print$NF }'

destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/synapse.subdomain.conf.sample $destconf

sed -i 's/matrix/'$sysubdomain'''/g' $destconf
sed -i 's/        set $upstream_app synapse;/        set $upstream_app '$containername';''/g' $destconf

##################################################################################################################################
# Syncthing
#  Create the docker-compose file
containername=syncthing
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    image: lscr.io/linuxserver/syncthing
    #container_name: syncthing # Depricated
    hostname: syncthing # Optional
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/London
    volumes:
      - $rootdir/docker/$containername:/config
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the syncthing proxy-conf file
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf

#  Add a cron job to reset the permissions of the pihole directory if any changes are made - checks once per minute
#  Don't put ' around the commmand!  And, it must be run as root!
(crontab -l 2>/dev/null || true; echo "* * * * * chmod 777 -R $rootdir/docker/pihole/etc-pihole") | crontab -

#  When you set up the syncs for pihole, ensure you check 'Ignore Permissions' under the 'Advanced' tab during folder setup.

##################################################################################################################################
#  Whoogle
#  Create the docker-compose file
containername=whoogle
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername
mylink=$fssubdomain'.'$fqdn

#  Whoogle - https://hub.docker.com/r/benbusby/whoogle-search#g-manual-docker
#  Install dependencies
apt-get install -y -qq libcurl4-openssl-dev libssl-dev
git clone https://github.com/benbusby/whoogle-search.git

# Move the contents from directory whoogle-search to directory whoogle
mv $rootdir/whoogle-search $rootdir/docker/$containername

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
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
      - WHOOGLE_ALT_TW=$mylink/nitter
      - WHOOGLE_ALT_YT=$mylink/invidious
      - WHOOGLE_ALT_IG=$mylink/bibliogram/u
      - WHOOGLE_ALT_RD=$mylink/libreddit
      - WHOOGLE_ALT_MD=$mylink/scribe
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the whoogle proxy-conf file using syncthing.subfolder.conf as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/whoogle''/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' $destconf

##################################################################################################################################
#  Wireguard
#  Create the docker-compose file
containername=wireguard
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;
mkdir -p $rootdir/docker/$containername/config;
mkdir -p $rootdir/docker/$containername/modules;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
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
      - SERVERPORT=$wgport
      - PEERS=3
      - PEERDNS=auto
      - INTERNAL_SUBNET=10.18.18.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - $rootdir/docker/$containername/config:/config
      - $rootdir/docker/$containername/modules:/lib/modules
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

##################################################################################################################################
#  Wireguard gui - will not run on a subfolder!

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

containername=wgui
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;
mkdir -p $rootdir/docker/$containername/app;
mkdir -p $rootdir/docker/$containername/etc;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:
    image: ngoduykhanh/wireguard-ui:latest
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
      - $rootdir/docker/$containername/app:/app/db
      - $rootdir/docker/$containername/etc:/etc/wireguard
    #network_mode: host
    networks:
      - no-internet
      - internet
    deploy:
      restart_policy:
       condition: on-failure
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the wireguard gui (wgui) proxy-conf file using syncthing.subdomain.conf.sample as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;''/g' $destconf
sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/syncthing/'$containername'/g' $destconf
sed -i 's/    server_name '$containername'./    server_name '$wgsubdomain'.''/g' $destconf
sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;''/g' $destconf

dest=$rootdir/docker/$containername/app/server
#  Make a few alterations to the core config files
sed -i 's/\"1.1.1.1\"/\"'$myip'\"/g' $dest/global_settings.json
sed -i 's/\"mtu\": \"1450\"/\"mtu\": \"1500\"/g' $dest/global_settings.json
sed -i 's/\"listen_port\": \"51820\"/\"listen_port\": \"'$wgport'\"/g' $dest/interfaces.json

##################################################################################################################################
# Pihole - do this last or it may interrupt you installs due to blacklisting

#  Needed if you are going to run pihole
#    Reference - https://www.geeksforgeeks.org/create-your-own-secure-home-network-using-pi-hole-and-docker/
#    Reference - https://www.shellhacks.com/setup-dns-resolution-resolvconf-example/
sudo systemctl stop systemd-resolved.service
sudo systemctl disable systemd-resolved.service
sed -i 's/nameserver 127.0.0.53/nameserver 9.9.9.9/g' /etc/resolv.conf # We will change this later after the pihole is set up
#  sudo lsof -i -P -n | grep LISTEN - allows you to find out who is litening on a port
#  sudo apt-get install net-tools
#  sudo netstat -tulpn | grep ":53 " - port 53

while true; do
  read -rp "
Enter your desired pihole webgui password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " pipass
  if [[ -z "${pipass}" ]]; then
    echo "Enter your desired pihole webgui password or hit ctrl+C to exit."
    continue
  fi
  break
done

#  Create the docker-compose file
containername=pihole
ymlname=$rootdir/$containername-compose.yml
mkdir -p $rootdir/docker/$containername;
mkdir -p $rootdir/docker/$containername/etc-pihole;
mkdir -p $rootdir/docker/$containername/etc-dnsmasq.d;

rm -f $ymlname
touch $ymlname

echo "$ymlhdr
  $containername:  # See this link for some help getting the host configured properly or else there will be a port 53 conflict
           #      https://www.geeksforgeeks.org/create-your-own-secure-home-network-using-pi-hole-and-docker/
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
      - SERVERIP=$myip
    volumes:
       - $rootdir/docker/$containername/etc-pihole:/etc/pihole
       - $rootdir/docker/$containername/etc-dnsmasq.d:/etc/dnsmasq.d
    dns:
      - 127.0.0.1
      - 9.9.9.9
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
$ymlftr" >> $ymlname

docker-compose -f $ymlname -p $stackname up -d

#  First wait until the stack is first initialized...
while [ -f "$(sudo docker ps | grep $containername)" ];
do
 sleep 5
done

#  Prepare the pihole proxy-conf file using syncthing.subfolder.conf as a template
destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
cp $rootdir/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf.sample $destconf

sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;''/g' $destconf
sed -i 's/\    return 301 \$scheme:\/\/$host\/pihole\/;/    return 301 \$scheme:\/\/$host\/pihole\/admin;''/g' $destconf

# Ensure ownership of the 'etc-pihole' folder is set properly.
chown systemd-coredump:systemd-coredump $rootdir/docker/$containername/etc-pihole
#  This below step may not be needed.  Need to deploy to a server and check
#  Allow syncthing to write to the 'etc-pihole' directory so it can sync properly
#chmod 777 $rootdir/docker/pihole/etc-pihole

#  Route all traffic including localhost traffic through the pihole
#  https://www.tecmint.com/find-my-dns-server-ip-address-in-linux/
sed -i 's/nameserver 9.9.9.9/nameserver '$myip'/g' /etc/resolv.conf

##################################################################################################################################
#  Seal a recently (Jan-2022) revealead vulnerabilty
#    https://arstechnica.com/information-technology/2022/01/a-bug-lurking-for-12-years-gives-attackers-root-on-every-major-linux-distro/

chmod 0755 /usr/bin/pkexec

##################################################################################################################################

echo "
Cleaning up and restarting the stack for the final time...
"

#  Need to restart the stack - will commit changes to swag *.conf files
docker restart $(sudo docker ps -a | grep $stackname | awk '{ print$1 }')

##################################################################################################################################
#  Store non-persistent variables in .bashrc for later use across reboots
echo "
" >> $rootdir/.bashrc
echo "export authusr=$authusr" >> $rootdir/.bashrc
echo "export authpwd=$authpwd" >> $rootdir/.bashrc
echo "export rootdir=$rootdir" >> $rootdir/.bashrc
echo "export stackname=$stackname" >> $rootdir/.bashrc
echo "export swagloc=$swagloc" >> $rootdir/.bashrc
echo "export fqdn=$fqdn" >> $rootdir/.bashrc
echo "export nupass=$nupass" >> $rootdir/.bashrc
echo "export napass=$napass" >> $rootdir/.bashrc
echo "export pipass=$pipass" >> $rootdir/.bashrc
echo "export wguid=$wguid" >> $rootdir/.bashrc
echo "export wgpass=$wgpass" >> $rootdir/.bashrc
echo "export jwebsubdomain=$jwebsubdomain" >> $rootdir/.bashrc
echo "export ltsubdomain=$ltsubdomain" >> $rootdir/.bashrc
echo "export wgsubdomain=$wgsubdomain" >> $rootdir/.bashrc
echo "export rpsubdomain=$rpsubdomain" >> $rootdir/.bashrc
echo "export sspass=$sspass" >> $rootdir/.bashrc

# Commit the .bashrc changes
source $rootdir/.bashrc

echo "
Keep these in a safe place for future reference:

==========================================================================================================
Fully qualified domain name (FQDN): $fqdn
Subdomains:                         $subdomains
Authelia userid:                    $authusr
Authelia password:                  $authpwd
Neko user password:                 $nupass
Neko admin password:                $napass
Pihole admin password:              $pipass
Wireguard userid:                   $wguid
Wireguard password:                 $wgpass
Wireguasrd port:                    $wgport
Jitsi-meet web:                     $jwebsubdomain.$fqdn
Libretranslate:                     $ltsubdomain.$fqdn
RSS-Proxy:                          $rpsubdomain.$fqdn
Shadowsocks password:               $sspass
Synapse (Matrix Server):
E-Mail Server:
User directory root:                $usrdirroot
==========================================================================================================

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

