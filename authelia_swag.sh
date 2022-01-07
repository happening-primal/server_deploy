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
  read -rp "
Enter your fully qualified domain name (FQDN) from your DNS provider: " fqdn
  if [[ -z "${fqdn}" ]]; then
    echo "Enter your fully qualified domain name (FQDN) from your DNS provider or hit ctrl+C to exit."
    continue
  fi
  break
done

echo "
"
rm docker-compose.yml

rm -r docker

docker stack rm authelia_swag

docker swarm leave --force

docker swarm init

mkdir docker

mkdir docker/authelia
mkdir docker/swag

chown $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')":"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root') docker

touch docker-compose.yml

echo "version: \"3.1\"

services:
  swag:
    image: linuxserver/swag
    #container_name: swag
    cap_add:
      - NET_ADMIN
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      - URL=$fqdn
      - SUBDOMAINS=www
      #- VALIDATION=dns
      #- DNSPLUGIN=cloudflare #optional
      #- PROPAGATION= #optional
      #- DUCKDNSTOKEN= #optional
      #- EMAIL= #optional
      - ONLY_SUBDOMAINS=false #optional
      #- EXTRA_DOMAINS= #optional
      - STAGING=false #optional
    volumes:
      - /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/swag:/config
    ports:
      - 443:443
      - 80:80 # You must leave this open or you won't be able to get your ssl certificate
    deploy:
      restart_policy:
       condition: on-failure

  authelia:
    image: authelia/authelia:latest #4.32.0
    #container_name: authelia
    environment:
      - TZ=America/New_York
    volumes:
      - /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia:/config
    deploy:
      restart_policy:
       condition: on-failure" >> docker-compose.yml

docker stack deploy --compose-file docker-compose.yml "authelia_swag"

# Wait a bit for the stack to deploy
until [ -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml ]
    do
      sleep 5
    done
  echo "File found"
exit

# Make a backup of the clean authelia configuration file 
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml.bak



