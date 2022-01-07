#!/bin/bash

stackname=authelia_swag

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

while true; do
  read -rp "
Enter your JWT secret - would look like 'AUVV2tYhu7YD5vbqZMkxDqX3wDEDkYYk8jQwBDq82Y9P3tHsSR': " jwts
  if [[ -z "${jwts}" ]]; then
    echo "Enter your JWT secret or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your Authelia secret - would look like 'KnCfXrWCRU7of96XqvTxQ9Zm8BFHKUFfnTXSUoiDM9kV8A94Cp': " auths
  if [[ -z "${auths}" ]]; then
    echo "Enter your JWT secret or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your Authelia encryption key - would look like 'NER38ZZAswXqnrkDzRAyVnXcxBJa2v9ffZC55r7W': " authec
  if [[ -z "${authec}" ]]; then
    echo "Enter your JWT secret or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired Authelia userid - would look like 'mynewuser' or 'Fkr5HZH4Rv': " authusr
  if [[ -z "${authusr}" ]]; then
    echo "Enter your JWT secret or hit ctrl+C to exit."
    continue
  fi
  break
done

while true; do
  read -rp "
Enter your desired Authelia password- would look like 'ycmLvUM3Qx9sRJR4uT5niWEYraYjaDN7gcuyoHEU': " authpwd
  if [[ -z "${authpwd}" ]]; then
    echo "Enter your JWT secret or hit ctrl+C to exit."
    continue
  fi
  break
done

echo "
"
rm docker-compose.yml

rm -r docker

docker stack rm $stackname

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

docker system prune

docker stack deploy --compose-file docker-compose.yml "authelia_swag"

# Wait a bit for the stack to deploy
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml ]
    do
      sleep 5
    done
    
echo "File found"

# Make a backup of the clean authelia configuration file 
cp /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml \
   /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml.bak

#  Comment out all the lines in the configuration file
sed -e 's/^\([^#]\)/#\1/g' -i /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml



#  Uncomment/modify the required lines
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
sed -i 's/\#  expiration: 1h/  expiration: 1h''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
sed -i 's/\#  inactivity: 5m/  inactivity: 5m''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/configuration.yml
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

pwdhash=$(docker run --rm authelia/authelia:latest authelia hash-password "$authpwd" | awk '{print $3}')


# Make sure the stack started properly
while [ ! -f /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml ]
    do
      sleep 5
    done
    
#sed -i 's/\#---/---''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml
sed -i 's/\    displayname: \"Test User\"/    displayname: \"T'"$authusr"'"''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml
sed -i 's/\    password: \"$argon2id$v=19$m=32768,t=1,p=8$eUhVT1dQa082YVk2VUhDMQ$E8QI4jHbUBt3EdsU1NFDu4Bq5jObKNx7nBKSn1EYQxk\"  # Password is 'authelia'/    password: \"$'"$pwdhash"'\"  # Password is 'authelia'''/g' /home/$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')/docker/authelia/users_database.yml


    #password: "$argon2id$v=19$m=32768,t=1,p=8$eUhVT1dQa082YVk2VUhDMQ$E8QI4jHbUBt3EdsU1NFDu4Bq5jObKNx7nBKSn1EYQxk"  # Password is 'authelia'


# Redeploy the stack
#docker stack rm $stackname
#docker system prune
#docker stack deploy --compose-file docker-compose.yml "$stackname"


