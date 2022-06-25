#!/bin/bash

# To Do - remove nitter ip address mod
#         remove DNSCrypt-proxy ip address mod

# https://github.com/oijkn/adguardhome-doh-dot
# https://simpledns.plus/kb/202/how-to-enable-dns-over-tls-dot-dns-over-https-doh-in-ios-v14
# https://rodneylab.com/how-to-enable-encrypted-dns-on-iphone-ios-14/
# https://github.com/oijkn/pihole-doh-dot
# https://www.reddit.com/r/pihole/comments/unx2kb/pihole_adguard_home_and_dohdot_and_such_what_was/
# https://www.linuxbabe.com/ubuntu/dns-over-https-doh-resolver-ubuntu-dnsdist
# https://www.aaflalo.me/2018/10/tutorial-setup-dns-over-https-server/
# https://www.whooglesearch.ml/search?q=vps+doh+or+dot+server
# https://github.com/satishweb/docker-doh


# Run this script as superuser with the -E flag to load to ensure the environmental
# variables are available.
#	sudo -E bash scriptnama.sh

# Formatted for use in Visual Studio Code - MS Product - https://code.visualstudio.com/
# All of the links in this file are archived at archive.today :)

##################################################################################################################################
# To Do:
	# 1.  Configure iptable rules
	# 2.  Wireguard
	# 3.  OpenVPN
	# 4.  Shadowsocks
	# 5.  ShadowVPN
##################################################################################################################################

################################################################################################################################## 
# For these VPN options, see the following - https://github.com/vimagick/dockerfiles
	#https://hub.docker.com/r/hwdsl2/ipsec-vpn-server
	#https://hub.docker.com/r/adrum/wireguard-ui
	#https://github.com/EmbarkStudios/wg-ui
	#https://hub.docker.com/r/dockage/shadowsocks-server
	#openvpn
	#ptpp
	#onionshare

	# Fail2ban - https://www.the-lazy-dev.com/en/install-fail2ban-with-docker/
##################################################################################################################################

##################################################################################################################################
# Required reading to understand this script:
	# sed - https://www.geeksforgeeks.org/sed-command-in-linux-unix-with-examples/
	# grep - 
	# awk - 
	# Redirect all output to a blackhole - 
	#     https://www.cyberithub.com/how-to-suppress-or-hide-all-the-output-of-a-linux-bash-shell-script/
##################################################################################################################################

##################################################################################################################################
# Function declaration 

	manage_variable() {
		# Expects at least two arguments - variable name and variable value
		# and possibly a flag
		variablename=$1
		variablevalue=$2
		if grep -Fq "$variablename" $rootdir/.bashrc; # Check if the variable is already in .bashrc
		then
			# The variable is already there
			exportvalue="export $variablename=$variablevalue"
			if grep -Fxq "$exportvalue" $rootdir/.bashrc; # Check if the value stored in .bashrc is the same
			then
				:
			else
				rflag="-r"
				if [ -n "$3" ]; # Check for the replacement flag -r
				then
					# The variable is there, but it has a different value than $variablevalue
					# and the -r flag is set so replace the old value with the new value
					export_variable $variablename "$variablevalue"
				else
					# The variable is there and it has a different value but the -r flag is not set
					# so replace the new value with the old value
					oldvalue=$(cat $rootdir/.bashrc | grep -m1 "$variablename" ) # Only pull the first instance
					oldvalue=${oldvalue#*"="} # https://superuser.com/questions/1001973/bash-find-string-index-position-of-substring
					variablevalue=$oldvalue
					#echo old_value
				fi

			fi
		else
			# The variable doesn't exist, so create it.
			export_variable $variablename "$variablevalue"
			#echo create_value
		fi

		# Remove any comment
		variablevalue=${variablevalue%#*}
		# Trim the whitespace
		variablevalue=${variablevalue=##*( )}
		# Echo out the result
		echo $variablevalue
	}

	# This functions helps manage environmental variables stored in .bashrc so that any changes
	# are properly propigated
	export_variable() {

		# Expects up to two arguments arguments consisting of either (1) a description string
		# or (2) the variable name and vaue be save to .bashrc for later use (current user)

		# if [ -z $2 ] && [ "$1" == *"#"* ]; # Check if the input is a comment
		if grep -q "#" <<< "$1"; # Check if the input is a comment
		then
			commentvalue=$1
            # https://stackoverflow.com/questions/428109/extract-substring-in-bash
            if grep -Fq "#${commentvalue#*#}" $rootdir/.bashrc; # Check if the comment is already in the file
			then
				# The comment is there so do nothing
				: # noop - https://stackoverflow.com/questions/12404661/what-is-the-use-case-of-noop-in-bash
			else
				# The comment is not there so add it
				echo -e "$commentvalue" >> $rootdir/.bashrc
			fi
		elif [ -n $1 ] && [ -n ${2+x} ]; # Should be an actual export command because there are two inputs
										# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
		then
			variablename=$1
			variablevalue=$2
			exportvalue="export $variablename=$variablevalue"
			if grep -Fq "$variablename" $rootdir/.bashrc; # Check if the export value is already in the file
			then
				if grep -Fxq "$exportvalue" $rootdir/.bashrc;
				then
					# The export value is there and has the same as the value so do nothing
					: # noop - https://stackoverflow.com/questions/12404661/what-is-the-use-case-of-noop-in-bash
				else 
					# The variable is there, but has a different value so replace the value
					oldvalue=$(cat $rootdir/.bashrc | grep "$variablename")
					oldvalue=${oldvalue#*"="} # https://superuser.com/questions/1001973/bash-find-string-index-position-of-substring
					
					#echo "Partial match, replace it - $oldvalue --> $exportvalue"
					sed -i "s/$oldvalue/$variablevalue/g" $rootdir/.bashrc # Note the use of " versus ' for special characters like #
				fi
			else
				# The export variable is not present, so add it
				echo -e "export $variablename=$variablevalue" >> $rootdir/.bashrc
			fi
		fi
	}

##################################################################################################################################

##################################################################################################################################
# Initialization

	echo -e "\n- You must run this script as superuser.\n"

	# Detect Root
	if [[ ! "${EUID}"==0 ]]; then
		echo -e "This installer needs to be run without superuser privileges." >&2
		exit 1
	fi

	echo -e "Installing a few apps that will be used later in the script...
	"
	
	# Install fail2ban for use later
	sudo apt-get -qq update && sudo apt -y -qq install fail2ban tmux resolvconf

	# Install diceware (passphrase generator) for later use - https://github.com/ulif/diceware
	#sudo apt install -y -qq python3-pip
	#pip3 install diceware
	sudo apt -y -qq install diceware
	# Usage - diceware -d "_" --> Wavy_Baden_400_Whelp_Quest_Macon
	# Usage - diceware -n 3 -d " " --> Define Critter Lagoon

##################################################################################################################################

##################################################################################################################################
# Global variables

	# These variables need to be in place to bootstrap the script
	# All other variables defined few lines down under "# Global variables"
	stackname=authelia_swag
	nonrootuser=$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')
	rootdir=/home/$nonrootuser

	# Load any existing variables
	source $rootdir/.bashrc

	# Prepare for persistence
	
	# Make a clean copy of .bashrc if it doesn't already exist
	while [ ! -f $rootdir/.bashrc.bak ]
		do
			cp $rootdir/.bashrc $rootdir/.bashrc.bak
		done

	while true; do
		read -p $'\n'"Do you want to perform a completely fresh install (y/n)? " yn
		case $yn in
			[Yy]* ) 
				# Stop the running docker containers
				docker stop $(docker ps | grep -v portainer | grep -v "CONTAINER" |awk '{ print$1 }');
				# Remove the docker containers associated with stackname
				docker rm -vf $(docker ps --filter status=exited | grep -v portainer | grep -v "CONTAINER" | awk '{ print$1 }');
				# Remove the networks associated with stackname...these are a bit persistent and need
				# to be removed so they don't cause a conflict with any revised configureations.
				docker network rm $(docker network ls | grep $stackname | awk '{ print$1 }')
				# Purge any dangling items...
				docker system prune;
				# Remove the docker directory
				rm -rf docker;
				# Make a new, fresh docker directory
				mkdir docker;
				#chown $(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')":"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root') -R docker;
				
				# Restore clean copy of .bashrc
				cp .bashrc.bak .bashrc
				
				# Commit the .bashrc changes
				source $rootdir/.bashrc
				
				break;;
			[Nn]* ) break;;
			* ) echo -e "Please answer yes or no.";;
		esac
	done

	export_variable "# Global variables"
	nonrootuser=$(manage_variable nonrootuser $nonrootuser "-r")
	rootdir=$(manage_variable rootdir $rootdir "-r")
	stackname=$(manage_variable stackname $stackname "-r")  # Docker stack name
	swagloc=$(manage_variable swagloc swag "-r") # Directory for Secure Web Access Gateway (SWAG)
	swagname=$(manage_variable swagname $swagloc "-r") # Name of the swag container (same as the location)
	swagymlname=$(manage_variable swagymlname "$rootdir/$swagname-compose.yml" "-r") # Name of the SWAG .yml file

	# External IP address
	myip=$(manage_variable myip $(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1) "-r")

	# Docker external facing IP address management
	subnet=$(manage_variable subnet 172.20.10 "-r")
	dockersubnet=$(manage_variable dockersubnet $subnet.0 "-r")
	dockergateway=$(manage_variable dockergateway $subnet.1 "-r")
	
	# Starting IP subnet (for pihole)
	ipend=10
	# Set the pihole static ip address
	piholeip=$(manage_variable piholeip $subnet.$ipend "-r")
	
	# Amount to increment the starting IP subnet (10, 15, 20, 25...)
	ipincr=$(manage_variable ipincr 5 "-r")
	
	# Increment the subnet...
	ipend=$(($ipend+$ipincr))

	# Initialize with a random fqdn which will be overwritten by swag installation
	# If the fqdn exists (swag already installed), it will be loaded at this point
	export_variable "\n# Secure Web Access Gateway (SWAG)"
	fqdn=$(manage_variable fqdn "$(echo $RANDOM | md5sum | head -c 8)  # Fully qualified domain name (FQDN)")

	# Create domain string
	subdomains="www"
	# Add a few specific use case subdomains
	export_variable "\n# SWAG subdomains"
	# archivebox
	absubdomain=$(manage_variable absubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Archivebox") && subdomains+=", " && subdomains+=$absubdomain
	# adguard home
	agsubdomain=$(manage_variable agsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # AdGuard Home") && subdomains+=", " && subdomains+=$agsubdomain
	# coturn (used with synapse)
	ctsubdomain=$(manage_variable ctsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Coturn used with synapse") && subdomains+=", " && subdomains+=$ctsubdomain
	# dns over https
	dhsubdomain=$(manage_variable dhsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # DNS over HTTPS server") && subdomains+=", " && subdomains+=$dhsubdomain
	# dnsproxy
	dpsubdomain=$(manage_variable dpsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # DNSProxy") && subdomains+=", " && subdomains+=$dpsubdomain
	# farside
	fssubdomain=$(manage_variable fssubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Farside") && subdomains+=", " && subdomains+=$fssubdomain
	# huginn
	hgsubdomain=$(manage_variable hgsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Huginn") && subdomains+=", " && subdomains+=$hgsubdomain
	# jitsiweb
	jwebsubdomain=$(manage_variable jwebsubdomain "$(echo $RANDOM | md5sum | head -c 8)    # JitsiWeb") && subdomains+=", " && subdomains+=$jwebsubdomain
	# libretranslate - 
	ltsubdomain=$(manage_variable ltsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Libre translate") && subdomains+=", " && subdomains+=$ltsubdomain
	# lingva translate
	lvsubdomain=$(manage_variable lvsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Lingva translate") && subdomains+=", " && subdomains+=$lvsubdomain
	# nitter
	ntsubdomain=$(manage_variable ntsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Nitter (Twitter frontend)") && subdomains+=", " && subdomains+=$ntsubdomain
	# openvpn access server
	ovpnsubdomain=$(manage_variable ovpnsubdomain "$(echo $RANDOM | md5sum | head -c 8)    # OpenVPN Access Server") && subdomains+=", " && subdomains+=$ovpnsubdomain
	# rss-proxy
	rpsubdomain=$(manage_variable rpsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # RSS-Proxy") && subdomains+=", " && subdomains+=$rpsubdomain
	# synapse
	sysubdomain=$(manage_variable sysubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Synapse (Matrix)") && subdomains+=", " && subdomains+=$sysubdomain
	# synapseui
	suisubdomain=$(manage_variable sysubdomain "$(echo $RANDOM | md5sum | head -c 8)     # Synapse Web UI") && subdomains+=", " && subdomains+=$suisubdomain
	# whoogle
	whglsubdomain=$(manage_variable whglsubdomain "$(echo $RANDOM | md5sum | head -c 8)    # Whoogle") && subdomains+=", " && subdomains+=$whglsubdomain
	# wireguard gui
	wgsubdomain=$(manage_variable wgsubdomain "$(echo $RANDOM | md5sum | head -c 8)      # Wireguard GUI") && subdomains+=", " && subdomains+=$wgsubdomain

	# Header for the docker-compose .yml files
	ymlhdr='version: "3.1"\nservices:'
	
	# Basic environmental variables for the docker-compose .yml files
	ymlenv="environment:\n      - PUID=1000\n      - PGID=1000\n      - TZ=Europe/London"

	# Restart policies for the docker-compose .yml files
	ymlrestart="restart: unless-stopped\n    deploy:\n      restart_policy:\n        condition: on-failure"
	#ymlrestart="restart: unless-stopped"
	# Some containers will not start automatically after reboot with 'condition: on-failure'
	#ymlrestart="restart: unless-stopped\n    deploy:\n      restart_policy:\n        condition: unless-stopped"
	
	# Footer for the docker-compose .yml files
	ymlftr="networks:\n  # For networking setup explaination, see this link:"
	ymlftr+="\n  # https://stackoverflow.com/questions/39913757/restrict-internet-access-docker-container"
	ymlftr+="\n  # For ways to see how to set up specific networks for docker see:"
	ymlftr+="\n  # https://www.cloudsavvyit.com/14508/how-to-assign-a-static-ip-to-a-docker-container/"
	ymlftr+="\n  # Note the requirement to remove existing newtorks using:"
	ymlftr+="\n  # docker network ls | grep authelia_swag | awk '{ print\$1 }' | docker network rm;"
	ymlftr+="\n  no-internet:"
	ymlftr+="\n    driver: bridge"
	ymlftr+="\n    internal: true"
	ymlftr+="\n  internet:"
	ymlftr+="\n    driver: bridge"
	ymlftr+="\n    ipam:"
	ymlftr+="\n      driver: default"
	ymlftr+="\n      config:"
	ymlftr+="\n        - subnet: $dockersubnet/24"
	ymlftr+="\n          #gateway: $dockergateway"

##################################################################################################################################

##################################################################################################################################
# Installation section

	##############################################################################################################################
	# Secure Web Access Gateway (SWAG) installation - nginx reverse proxy. 
		
		# See SWAG installation near the end of this script.  It is moved there so that the entire script need to run before
		# the domains are assigned.  This prevents the issue of the limit with letsencrypt blocking you for 72 hours
		# after assigning new domain names.

		# Because of the limitation on setting wildcard domains using http we have to specify each domain,
		# one by one.  The following will automate the process for you by generating the specified
		# number of 8 digit random subdomain names.  Adds www by default.  See swag docker-compose.yml
		# output file for further infrormation.  Also adds required domains for subsequent services
		# that require a subdomain such as jitsi-meet, libretranslate, rss-proxy, etc...
		
		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall SWAG (y/n)? " yn
            case $yn in
                [Yy]* ) 
                    while true; do
                    read -rp $'\n'"Enter your fully qualified domain name (FQDN) from your DNS provider - would look like 'example.com': " fqdn
                    if [[ -z "${fqdn}" ]]; then
                        echo -e "Enter your fully qualified domain name (FQDN) from your DNS provider or hit Ctrl+C to exit."
                        continue
                    fi
                    break
                    done

                    while true; do
                        read -rp $'\n'"How many random subdomains would you like to generate? " rnddomain
                        if [[ -z "${rnddomain}" ]]; then
                            echo -e "Enter the number of random subdomains would you like to generate or hit Ctrl+C to exit."
                            continue
                        fi
                        break
                    done

					echo -e "\n"

                    # Add a few more for the novice user, they may need them later even though they don't know it now :)
                    rnddomain=$(($rnddomain+9))
					rnddomains=$(echo $RANDOM | md5sum | head -c 8)

                    # Domain and DNS setup section
                    i=0
                    while [ $i -ne $rnddomain ]
                        do
                            i=$(($i+1))
                            rnddomains+=", "
                            rnddomains+=$(echo $RANDOM | md5sum | head -c 8)
                        done
					
					subdomains+=$rnddomains

                    # Save variable to .bashrc for later persistent use
                    export_variable "\n# Secure Web Access Gateway (SWAG)"
					fqdn=$(manage_variable fqdn "$fqdn  # Fully qualified domain name (FQDN)" "-r")
                    
                    rm $rootdir/subdomains
                    echo -e "# Full subdomain string" >> $rootdir/subdomains
                    echo -e "$subdomains" >> $rootdir/subdomains
					echo -e "# Random subdomain string" >> $rootdir/subdomains
                    echo -e "$rnddomains" >> $rootdir/subdomains

                    # Commit the .bashrc changes
                    source $rootdir/.bashrc

                    # If using duckdns
                    #while true; do
                    # read -rp "
                    #Enter your duckdns token - would look like '1af7e11a-2342-49c9-abcd-88bf6d91de22': " ducktkn
                    # if [[ -z "${ducktkn}" ]]; then
                    #   echo -e "Enter your duckdns token or hit Ctrl+C to exit."
                    #   continue
                    # fi
                    # break
                    #done

                    # If using zerossl instead of letsencrypt
                    #while true; do
                    # read -rp "
                    #Enter your zerossl account email address: " zspwd
                    # if [[ -z "${zspwd}" ]]; then
                    #   echo -e "Enter your zerossl account email address or hit Ctrl+C to exit."
                    #   continue
                    # fi
                    # break
                    #done
                
                    # Create the docker-compose file
                    containername=$swagname  # See 'Global variables' section
                    ymlname=$swagymlname
                    rndsubfolder=$(openssl rand -hex 15)

                    # Remove any existing installation
                    $(docker-compose -f $ymlname -p $stackname down -v)
                    rm -rf $rootdir/docker/$containername

                    mkdir -p $rootdir/docker/$containername;

                    rm -f $ymlname && touch $ymlname

                    # Build the .yml file
                    # Header (generic)
                    echo -e "$ymlhdr" >> $ymlname
                    echo -e "  $containername:" >> $ymlname
                    echo -e "    container_name: $containername" >> $ymlname
                    echo -e "    hostname: $containername" >> $ymlname
                    # Docker image (user specified)
                    echo -e "    image: linuxserver/swag" >> $ymlname
                    # Environmental variables (generic)
                    echo -e "    $ymlenv" >> $ymlname
                    # Additional environmental variables (user specified)
                    echo -e "      - URL=$fqdn" >> $ymlname
                    echo -e "      #" >> $ymlname
                    echo -e "      # Use of wildcard domains is no longer possible using http authentication for letsencrypt or zerossl" >> $ymlname
                    echo -e "      # Linuxserver.io version:- 1.22.0-ls105 Build-date:- 2021-12-30T06:20:11+01:00" >> $ymlname
                    echo -e "      # 'Client with the currently selected authenticator does not support" >> $ymlname
                    echo -e "      # any combination of challenges that will satisfy the CA." >> $ymlname
                    echo -e "      # You may need to use an authenticator plugin that can do challenges over DNS.'" >> $ymlname
                    echo -e "      #- SUBDOMAINS=wildcard  # Won't work with current letsencrypt policies as per the above" >> $ymlname
                    echo -e "      - SUBDOMAINS=$subdomains" >> $ymlname
                    echo -e "      #" >> $ymlname
                    echo -e "      # If CERTPROVIDER is left blank, letsencrypt will be used" >> $ymlname
                    echo -e "      #- CERTPROVIDER=zerossl" >> $ymlname
                    echo -e "      #" >> $ymlname
                    echo -e "      #- VALIDATION=duckdns" >> $ymlname
                    echo -e "      #- DNSPLUGIN=cloudfare #optional" >> $ymlname
                    echo -e "      #- PROPAGATION= #optional" >> $ymlname
                    echo -e "      #- DUCKDNSTOKEN=$ducktkn" >> $ymlname
                    echo -e "      #- EMAIL=$zspwd  # Zerossl password" >> $ymlname
                    echo -e "      - ONLY_SUBDOMAINS=false #optional" >> $ymlname
                    echo -e "      #- EXTRA_DOMAINS= #optional" >> $ymlname
                    echo -e "      - STAGING=false #optional" >> $ymlname
                    # Miscellaneous docker container parameters (user specified)
                    echo -e "    cap_add:" >> $ymlname
                    echo -e "      - NET_ADMIN" >> $ymlname
                    # Network specifications (user specified)
                    echo -e "    networks:" >> $ymlname
                    echo -e "      no-internet:" >> $ymlname
                    echo -e "      internet:" >> $ymlname
                    echo -e "        ipv4_address: $ipaddress" >> $ymlname
                    # Ports specifications (user specified)
                    echo -e "    ports:" >> $ymlname
                    echo -e "      # You must leave port 80 open or you won't be able to get your ssl certificates via http" >> $ymlname
                    echo -e "      - 80:80" >> $ymlname
                    echo -e "      - 443:443" >> $ymlname
                    # Restart policies (generic)
                    echo -e "    $ymlrestart" >> $ymlname
                    # Volumes (user specified)
                    echo -e "    volumes:\n      - $rootdir/docker/swag:/config" >> $ymlname
                    # Networks, etc (generic)...
                    echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

                    docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

                    # Wait until the stack is first initialized...
                    while [ -f "$(sudo docker ps | grep $containername)" ];
                        do
                            sleep 5
                    done

                    # Make sure the stack started properly by checking for the existence of ssl.conf
                    while [ ! -f $rootdir/docker/$swagloc/nginx/ssl.conf ]
                        do
                            sleep 5
                    done

                    # Perform some SWAG hardening - https://virtualize.link/secure/
                    echo -e "\n# Additional SWAG hardening - https://virtualize.link/secure/" >> $rootdir/docker/$swagloc/nginx/ssl.conf
                    # No more Google FLoC
                    echo -e "add_header Permissions-Policy \"interest-cohort=()\";" >> $rootdir/docker/$swagloc/nginx/ssl.conf
                    # X-Robots-Tag - prevent applications from appearing in results of search engines and web crawlers
                    echo -e "add_header X-Robots-Tag \"noindex, nofollow, nosnippet, noarchive\";" >> $rootdir/docker/$swagloc/nginx/ssl.conf
                    # Enable HTTP Strict Transport Security (HSTS)
                    echo -e "add_header Strict-Transport-Security \"max-age=63072000; includeSubDomains; preload\" always;" >> $rootdir/docker/$swagloc/nginx/ssl.conf
                    
                    # Firewall rules
                    iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
                    iptables -t filter -A INPUT -p tcp --dport 80 -j ACCEPT
                    iptables -t filter -A OUTPUT -p udp --dport 80 -j ACCEPT
                    iptables -t filter -A INPUT -p udp --dport 80 -j ACCEPT

                    iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
                    iptables -t filter -A INPUT -p tcp --dport 443 -j ACCEPT
                    iptables -t filter -A OUTPUT -p udp --dport 443 -j ACCEPT
                    iptables -t filter -A INPUT -p udp --dport 443 -j ACCEPT

					#iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Authelia - two factor authentication for web apps

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Authelia (y/n)? " yn
            case $yn in
                [Yy]* ) 
                    while true; do
						read -rp $'\n'"Enter your desired Authelia userid - example - 'mynewuser' or (better) 'Fkr5HZH4Rv': " authusr
						if [[ -z "${authusr}" ]]; then
							echo -e "Enter your desired Authelia userid or hit Ctrl+C to exit."
							continue
						fi
						break
                    done

                    while true; do
						read -rp $'\n'"Enter your desired Authelia password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " authpwd
						if [[ -z "${authpwd}" ]]; then
							echo -e "Enter your desired Authelia password or hit Ctrl+C to exit."
							continue
						fi
						break
                    done

                    # Generate some of the variables that will be used later but that the user does
                    # not need to keep track of
                    #   https://linuxhint.com/generate-random-string-bash/
                    jwts=$(openssl rand -hex 40)     # Authelia JWT secret
                    auths=$(openssl rand -hex 40)    # Authelia secret
                    authec=$(openssl rand -hex 40)   # Authelia encryption key

                    # Create the docker-compose file
                    containername=authelia
                    ymlname=$rootdir/$containername-compose.yml
                    rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)

                    # Save variable to .bashrc for later persistent use
                    export_variable "\n# Authelia"
                    authusr=$(manage_variable "authusr" "$authusr" "-r")
                    authpwd=$(manage_variable "authpwd" "$authpwd" "-r")

                    # Commit the .bashrc changes
                    source $rootdir/.bashrc

                    # Remove any existing installation
                    $(docker-compose -f $ymlname -p $stackname down -v)
                    rm -rf $rootdir/docker/$containername

                    mkdir -p $rootdir/docker/$containername

                    rm -f $ymlname && touch $ymlname

                    # Build the .yml file
                    # Header (generic)
                    echo -e "$ymlhdr" >> $ymlname
                    echo -e "  $containername:" >> $ymlname
                    echo -e "    container_name: $containername" >> $ymlname
                    echo -e "    hostname: $containername" >> $ymlname
                    # Docker image (user specified)
                    echo -e "    image: authelia/authelia:latest #4.32.0" >> $ymlname
                    # Environmental variables (generic)
                    echo -e "    $ymlenv" >> $ymlname
                    # Additional environmental variables (user specified)
                    # Miscellaneous docker container parameters (user specified)
                    # Network specifications (user specified)
                    echo -e "    networks:" >> $ymlname
                    echo -e "      no-internet:" >> $ymlname
                    # Ports specifications (user specified)
                    # Restart policies (generic)
                    echo -e "    $ymlrestart" >> $ymlname
                    # Volumes (user specified)
                    echo -e "    volumes:" >> $ymlname
                    echo -e "      - $rootdir/docker/$containername:/config" >> $ymlname
                    # Networks, etc (generic)...
                    echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

                    docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

                    # Wait until the stack is first initialized...
                    echo -e "\nWaiting for the container to start for the first time..."
                    while [ -f "$(sudo docker ps | grep $containername)" ];
                        do
                            sleep 5
					done

					configbackname=configuration.yml
					configbackpath=$rootdir/docker/$containername/$configbackname

                    # Make sure the stack started properly by checking for the existence of configuration.yml
                    echo -e "Waiting for the $configbackname file to be created..."
                   	while [ ! -f $configbackpath ]
						do
							sleep 5
					done

                    # Backup the clean configuration file
					echo -e "Create a backup of the clean $configbackname file to $configbackname.bak..."
                    while [ ! -f $configbackpath.bak ]
                        do
                            cp $configbackpath $configbackpath.bak;
							chown "$nonrootuser:$nonrootuser" $configbackpath.bak;
					done
                    
                    #  Comment out all the lines in the ~/docker/authelia/configuration.yml.bak configuration file
					echo -e "Editing the $configbackname file..."
                    sed -e 's/^\([^#]\)/#\1/g' -i $rootdir/docker/$containername/configuration.yml

                    #  Uncomment/modify the required lines in the /docker/authelia/configuration.yml.bak file
                    sed -i 's/\#---/---/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#theme: light/theme: light/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#jwt_secret: a_very_important_secret/jwt_secret: '"$jwts"'/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#default_redirection_url: https:\/\/home.example.com\/default_redirection_url: https:\/\/'$fqdn'\//g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#server:/server:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  host: 0.0.0.0/  host: 0.0.0.0/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  port: 9091/  port: 9091/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  path: ""/  path: \"'$containername'\"/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  read_buffer_size: 4096/  read_buffer_size: 4096/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  write_buffer_size: 4096/  write_buffer_size: 4096/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#log:/log:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  level: debug/  level: debug/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#totp:/totp:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  algorithm: sha1/  algorithm: sha1/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  digits: 6/  digits: 6/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  period: 30/  period: 30/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  skew: 1/  skew: 1/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#authentication_backend:/authentication_backend:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  disable_reset_password: false/  disable_reset_password: false/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \# file:/  file:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#   path: \/config\/users_database.yml/    path: \/config\/users_database.yml/g' $rootdir/docker/$containername/configuration.yml
                    sed -i ':a;N;$!ba;s/\#  \#   password:/    password:''/1' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#     algorithm: argon2id/      algorithm: argon2id/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#     iterations: 1/      iterations: 1/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#     key_length: 32/      key_length: 32/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#     salt_length: 16/      salt_length: 16/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#     memory: 1024/      memory: 1024/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#     parallelism: 8/      parallelism: 8/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#access_control:/access_control:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  default_policy: deny/  default_policy: deny/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  rules:/  rules:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i ':a;N;$!ba;s/\#    - domain:/    - domain:''/3' $rootdir/docker/$containername/configuration.yml
                    sed -i "s/\#        - 'secure.example.com'/      - '$fqdn'/g" $rootdir/docker/$containername/configuration.yml
                    sed -i "s/\#        - 'private.example.com'/      - '\*.$fqdn'/g" $rootdir/docker/$containername/configuration.yml
                    # Change only the first instance
					sed -i ':a;N;$!ba;s/\#      policy: two_factor/      policy: two_factor''/1' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#session:/session:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  name: authelia_session/  name: authelia_session/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  domain: example.com/  domain: '"$fqdn"'/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  secret: insecure_session_secret/  secret: '"$auths"'/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  expiration: 1h/  expiration: 24h/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  inactivity: 5m/  inactivity: 12h/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  remember_me_duration: 1M/  remember_me_duration: 1M/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#regulation:/regulation:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  max_retries: 3/  max_retries: 3/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  find_time: 2m/  find_time: 2m/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  ban_time: 5m/  ban_time: 5m/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#storage:/storage:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \# encryption_key: you_must_generate_a_random_string_of_more_than_twenty_chars_and_configure_this/  encryption_key: '"$authec"'/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \# local:/  local:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#   path: \/config\/db.sqlite3/    path: \/config\/db.sqlite3/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#notifier:/notifier:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i ':a;N;$!ba;s/\#  disable_startup_check: false/  disable_startup_check: false''/2' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \# filesystem:/  filesystem:/g' $rootdir/docker/$containername/configuration.yml
                    sed -i 's/\#  \#   filename: \/config\/notification.txt/    filename: \/config\/notification.txt/g' $rootdir/docker/$containername/configuration.yml
                    # Yeah, that was exhausting...

                    # Restart Authelia so that it will generate the users_database.yml file
                    echo -e "\nRestarting the container to commit the configuration file changes...\n"
                    docker-compose -f $ymlname -p $stackname down

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

                    # Wait until the stack is first initialized...
                    echo -e "\nWaiting for the container to restart..."
                    while [ -f "$(sudo docker ps | grep $containername)" ];
                        do
                            sleep 5
                        done

					configbackname=users_database.yml
					configbackpath=$rootdir/docker/$containername/$configbackname

                    # Make sure the stack started properly by checking for the existence of users_database.yml
                    echo -e "Waiting for the $configbackname file to be created..."
                   	while [ ! -f $configbackpath ]
						do
							sleep 5
					done

                    # Backup the clean configuration file
					echo -e "Create a backup of the clean $configbackname file to $configbackname.bak..."
                    while [ ! -f $configbackpath.bak ]
                        do
                            cp $configbackpath $configbackpath.bak;
							chown "$nonrootuser:$nonrootuser" $configbackpath.bak;
					done

                    # Comment out all the lines in the ~/docker/authelia/users_database.yml configuration file
					echo -e "Editing the $configbackname file..."
                    sed -e 's/^\([^#]\)/#\1/g' -i $rootdir/docker/$containername/users_database.yml

                    # Generate the hashed password line to be added to users_database.yml.
                    echo -e "Generating the hashed password..."
                    pwdhash=$(docker run --rm authelia/authelia:latest authelia hash-password $authpwd | awk '{print $3}')

                    # Update the users database file with your username and hashed password.
                    echo -e "Updating the users database file..."
                    echo -e "users:" >> $rootdir/docker/$containername/users_database.yml
                    echo -e "  $authusr:\n    displayname: \"$authusr\"" >> $rootdir/docker/$containername/users_database.yml
                    echo -e "    password: \"$pwdhash\"" >> $rootdir/docker/$containername/users_database.yml
                    echo -e "    email: authelia@authelia.com" >> $rootdir/docker/$containername/users_database.yml
                    echo -e "    groups: []" >> $rootdir/docker/$containername/users_database.yml
                    echo -e "..." >> $rootdir/docker/$containername/users_database.yml

                    sed -i 's/\#---/---/g' $rootdir/docker/$containername/users_database.yml
                    
                    # Mind the $ signs and forward slashes / :(

                    # Configure the swag proxy-confs files
                    # Update the swag nginx default landing page to redirect to Authelia authentication
					# Note that if you make changes to 'default' you need to restart SWAG for the changes
					# to take effect
                    sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $rootdir/docker/$swagloc/nginx/site-confs/default
                    sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $rootdir/docker/$swagloc/nginx/site-confs/default
					#sed -i 's/\    location \/ {/#    location \/ {/g' $rootdir/docker/$swagloc/nginx/site-confs/default
                    #sed -i 's/\        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;/#        try_files \$uri \$uri\/ \/index.html \/index.php?\$args =404;/g' $rootdir/docker/$swagloc/nginx/site-confs/default
                    #sed -i ':a;N;$!ba;s/\    }/#    }''/1' $rootdir/docker/$swagloc/nginx/site-confs/default
                    sed -i 's/\##/#/g' $rootdir/docker/$swagloc/nginx/site-confs/default

                    # Restart the stack to get the configuration changes committed
                    docker-compose -f $ymlname -p $stackname down && docker-compose --log-level ERROR -f $ymlname -p $stackname up -d
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

                    # Wait until the stack is first initialized...
                    while [ -f "$(sudo docker ps | grep $containername)" ];
                        do
                            sleep 5
                        done
                    	
                    # Firewall rules
                    # None required
					# #iptables-save

                    # Once you register for the TOTP, you can find the registration link here:
                    #   'sudo cat /home/"$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')"/docker/authelia/notification.txt | grep http
                    
                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done
	##############################################################################################################################

	##############################################################################################################################
	# Archivebox - will not run on a subfolder

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend
		
		# Web page archiver like archive.today or waybackmachine
		# https://github.com/ArchiveBox/ArchiveBox#input-formats
		# https://raw.githubusercontent.com/ArchiveBox/ArchiveBox/master/docker-compose.yml
		# https://www.vultr.com/docs/install-archivebox-on-a-oneclick-docker-application/
		# Add new rss feeds from the command line
		#     https://computingforgeeks.com/install-use-archivebox-self-hosted-internet-archiving/
		# Add webgui admin user - https://3xn.nl/projects/2021/11/11/archivebox-docker-superuser-root-issues/

		# How to create a superuser
		# https://3xn.nl/projects/2021/11/11/archivebox-docker-superuser-root-issues/
		# sudo docker exec -it --user archivebox $(sudo docker ps | grep $containername) /bin/bash
		# https://github.com/ArchiveBox/ArchiveBox/issues/395
		# From the command line - https://github.com/ArchiveBox/ArchiveBox/wiki/Upgrading-or-Merging-Archives#example-adding-a-new-user-with-a-hashed-password

        while true; do
            read -p $'\n'"Do you want to install/reinstall Archivebox (y/n)? " yn
            case $yn in
                [Yy]* ) 
 
					# Create the docker-compose file
					containername=archivebox
					ymlname=$rootdir/$containername-compose.yml

                    # Commit the .bashrc changes
                    source $rootdir/.bashrc

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$containername'_sonic';
					mkdir -p $rootdir/docker/$containername'_sonic'/data;

					rm -rf $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: archivebox/archivebox:master" >> $ymlname
					# Environmental variables
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - ALLOWED_HOSTS=*  # add any config options you want as env vars" >> $ymlname
					echo -e "      # - SEARCH_BACKEND_ENGINE=sonic     # uncomment these if you enable sonic below" >> $ymlname
					echo -e "      # - SEARCH_BACKEND_HOST_NAME=sonic" >> $ymlname
					echo -e "      # - SEARCH_BACKEND_PASSWORD=SecretPassword" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    #build: .                              # for developers working on archivebox" >> $ymlname
					echo -e "    command: server --quick-init 0.0.0.0:8000" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 8222:8000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/data" >> $ymlname
      				echo -e "      # - ./archivebox:/app/archivebox    # for developers working on archivebox" >> $ymlname
					# To run the Sonic full-text search backend, first download the config file to sonic.cfg
					# curl -O https://raw.githubusercontent.com/ArchiveBox/ArchiveBox/master/etc/sonic.cfg
					# after starting, backfill any existing Snapshots into the index: docker-compose run archivebox update --index-only
					echo -e '  '$containername'_sonic:' >> $ymlname
					echo -e '    container_name: '$containername'_sonic' >> $ymlname
					echo -e '    hostname: '$containername'_sonic' >> $ymlname
					# Docker image (user specified)
					echo -e "    image: valeriansaliou/sonic:v1.3.0" >> $ymlname
					# Environmental variables
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					echo -e "    expose:" >> $ymlname
					echo -e "      - 1491" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					# Ports specifications
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					echo -e "    volumes:" >> $ymlname
					echo -e '      - '$rootdir'/docker/'$containername'_sonic/sonic.cfg:/etc/sonic.cfg:ro' >> $ymlname
      				echo -e '      - '$rootdir'/docker/'$containername'_sonic/data:/var/lib/sonic/store' >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					# Download the sonic.cfg file
					cd $rootdir'/docker/'$containername'_sonic'
					curl -O https://raw.githubusercontent.com/ArchiveBox/ArchiveBox/master/etc/sonic.cfg
					cd $rootdir

					#docker-compose run $containername init --setup -f $ymlname
					# Perform the initial setup of userid and password for admin user
					# https://www.vultr.com/docs/install-archivebox-on-a-oneclick-docker-application/
					docker-compose -f $ymlname -p $stackname run $containernam init --setup
					# Remove the temporary container
					docker-compose -f $ymlname -p $stackname down -v
					# Launch the container
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

                    # Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
                    destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
                    cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$absubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8000;/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1 > /dev/null

					echo -e ""
					echo -e "   Now execute the command 'archivebox manage createsuperuser' and add userid, email and password."
					echo -e "	You can enter a fake email address."
					echo -e "	When you are finished, type 'exit' to return to the main script."
					echo -e "	** Note that these inputs are not managed by this script, so you must save them manually **\n"

					docker exec -it --user archivebox $(sudo docker ps | grep $containername | grep -v $containername'_' | awk '{print $1}') /bin/bash
					#archivebox manage createsuperuser

					# Firewall rules
					# None required
					# #iptables-save

					break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done      
			
	##############################################################################################################################

	##########################################################################################################################
	# AdGuard home (DoH DoT Resolver)
	    
		# https://github.com/oijkn/adguardhome-doh-dot

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall AdGuard Home (DoH DoT Resolver) (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=adguardhome
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)
					agwebguiport=3000
					#upstreamdns=$piholeip # Route to pihole or other dns provider like 1.1.1.1 or 9.9.9.9

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$containername/conf;
					mkdir -p $rootdir/docker/$containername/work

					rm -rf $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: oijkn/adguardhome-doh-dot:latest" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified
					# Miscellaneous docker container parameters (user specified)
					echo -e "    cap_add:" >> $ymlname
      				echo -e "      - NET_ADMIN" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    # The port needs to be exposed to accept DNS requests" >> $ymlname
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- $agwebguiport:$agwebguiport # Web interface port" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/conf:/opt/adguardhome/conf" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/work:/opt/adguardhome/work" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					sed -i 's/\"remoteDnsServers\": \[\]/\"remoteDnsServers\": \['$piholeip'\]/g' $rootdir/docker/$containername/conf/config.json

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$agsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port '$agwebguiport';/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
				
					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# DNSCrypt-Proxy (DNS over HTTPS (DoH) proxy backend)

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall dnscrypt-proxy (y/n)? " yn
            case $yn in
                [Yy]* )

					# https://github.com/DNSCrypt/dnscrypt-proxy/wiki
					# https://docs.pi-hole.net/guides/dns/unbound/
					# Solve some permission errors when mapping local volume - https://github.com/MatthewVance/unbound-docker/issues/22
					# https://dnscrypt.info/stamps-specifications/
					# https://farside.link/scribe/privacytools/adding-custom-dns-over-https-resolvers-to-dnscloak-20ff5845f4b5

					containername=dnscrypt-proxy
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)

                    # Save variable to .bashrc for later persistent use
                    export_variable "\n# dnscrypt-proxy"
					dnscpipaddress=$(manage_variable "dnscpipaddress" "$ipaddress" -r)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername;

					mkdir -p $rootdir/docker/$containername;

					#chmod 777 -R $rootdir/docker/$containername # Required for unbound to write to the directory

					rm -f $ymlname && touch $ymlname

					# Fetch a default .toml file (can be modified after initial install)
					wget https://raw.githubusercontent.com/DNSCrypt/dnscrypt-proxy/master/dnscrypt-proxy/example-dnscrypt-proxy.toml
					mv example-dnscrypt-proxy.toml $rootdir/docker/$containername
					cp $rootdir/docker/$containername/example-dnscrypt-proxy.toml $rootdir/docker/$containername/dnscrypt-proxy.toml

					# Customize the .toml file
					# No traditional ipv4 servers
					sed -i "s/listen_addresses = \['127.0.0.1:53'\]/listen_addresses = \['$ipaddress:53'\]/g" $rootdir/docker/$containername/dnscrypt-proxy.toml
					# Increase max_clients to handle ipleak.net tests...
					sed -i 's/max_clients = 250/max_clients = 2500/g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's/ipv4_servers = true/ipv4_servers = false/g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					# Enable DNSSEC
					sed -i 's/require_dnssec = false/require_dnssec = true/g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's/\# dnscrypt_ephemeral_keys = false/dnscrypt_ephemeral_keys = true/g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					# Fuck google!
					sed -i "s/bootstrap_resolvers = \['9.9.9.11:53', '8.8.8.8:53'\]/bootstrap_resolvers = \['9.9.9.11:53', '1.1.1.1:53', '9.9.9.9:53'\]/g" $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's/log_files_max_age = 7/log_files_max_age = 1/g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's/block_ipv6 = false/block_ipv6 = true/g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's///g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's///g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					sed -i 's///g' $rootdir/docker/$containername/dnscrypt-proxy.toml
					#require_dnssec = false

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: gists/dnscrypt-proxy" >> $ymlname
					#echo -e "    image: klutchell/unbound" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 3000:3000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/dnscrypt-proxy.toml:/etc/dnscrypt-proxy/dnscrypt-proxy.toml" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					#chown -R "$nonrootuser:$nonrootuser" $rootdir/docker/$containername
					chmod 777 -R $rootdir/docker/$containername

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Firewall rules
					# None needed
					# #iptables-save
					# Drop all ipv6 traffic
					#ip6tables -P INPUT DROP
					#ip6tables -P FORWARD DROP
					#ip6tables -P OUTPUT DROP
					# ip6tables-save

					# Test the server
					# dig google.com @$dnscrypt-proxy-ipaddress -p $dnscrypt-proxy-port

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##################################################################################################################################

	##########################################################################################################################
	# DNS over HTTPS (DoH) Server (frontend) - will not run on a subfolder
	    
		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall the DNS over HTTPS server (DoH Resolver) (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=dohserver
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)
					dnsproxyport=8053
					tsconfname=doh-server.conf
					upstreamdns=$piholeip # Route to pihole or other dns provider like 1.1.1.1 or 9.9.9.9

					while true; do
						read -rp $'\n'"Enter the DoH server subfolder (https://$fqdn/somerandomsubfolder): " dohhttpsubfolder
						if [[ -z "${dohhttpsubfolder}" ]]; then
							echo -e "Enter the DoH server subfolder or hit Ctrl+C to exit."
							continue
						fi
						break
                    done
					# 'Subfolder' that will be used to append the query to
					#dohhttpsubfolder=$(openssl rand -hex 20)   # Makes it very hard for someone to abuse your DoH server
					# Save variable to .bashrc for later persistent use
                    export_variable "\n# DNS over HTTPS server"
					dohhttpsubfolder=$(manage_variable "dohhttpsubfolder" "$dohhttpsubfolder" -r)
					# The final query will look like https://$dhsubdomain.$fqdn/$dohhttpsubfolder?name=domain_to_be_looked_up&type=A
					#   Example:  https://$dhsubdomain.$fqdn/$dohhttpsubfolder?name=google.com&type=A
					# To configure firefox to use DoH, put https://$dhsubdomain.$fqdn/$dohhttpsubfolder in the network settings
					# page.  You can see this link for some help - https://www.linuxbabe.com/ubuntu/dns-over-https-doh-resolver-ubuntu-dnsdist
					# Similar configuration can be used for THunderbird - http://daemonforums.org/showthread.php?t=11203
					# aboout:config in firefox
					# Set network.trr.mode to 3 to only use DoH as the resolver
					# Set network.trr.bootstrapAddress to the ip address of the DoH server to allow
					# firefox / thunderbird to bootstrap up access to the DoH server.
					# https://www.inmotionhosting.com/support/security/dns-over-https-encrypted-sni-in-firefox/
					
					# Use this link to create the .mobilconfig file for iPhone
					# https://simpledns.plus/apple-dot-doh
					# Service / company name: doh-dns-proxy
					# DNS query URL:  https://$fqdn/$dohhttpsubfolder
					# Server IP addresses (one per line): $myip
					# https://simpledns.plus/kb/202/how-to-enable-dns-over-tls-dot-dns-over-https-doh-in-ios-v14
					# Can also see this link - https://rodneylab.com/how-to-enable-encrypted-dns-on-iphone-ios-14/
					# Add the 

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$containername/server;
					mkdir -p $rootdir/docker/$containername/app-config;

					rm -rf $ymlname && touch $ymlname
					rm -f $rootdir/docker/$containername/server/$tsconfname && touch $rootdir/docker/$containername/server/$tsconfname
					chmod 777 -R $rootdir/docker/$containername/server/$tsconfname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: satishweb/doh-server" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified
					echo -e '      - DEBUG=0' >> $ymlname
					echo -e '      - UPSTREAM_DNS_SERVER=udp:'$upstreamdns':53' >> $ymlname # 'Upstream' = provider like Quad9 of Cloudflare
					echo -e '      - DOH_HTTP_PREFIX=/'$dohhttpsubfolder >> $ymlname
					echo -e '      - DOH_SERVER_LISTEN=0.0.0.0:'$dnsproxyport >> $ymlname
					echo -e '      - DOH_SERVER_TIMEOUT=10' >> $ymlname
					echo -e '      - DOH_SERVER_TRIES=3' >> $ymlname
					echo -e '      - DOH_SERVER_VERBOSE=false' >> $ymlname # Change to 'true' for better logs
					# Miscellaneous docker container parameters (user specified)
					echo -e '    deploy:' >> $ymlname
					echo -e '      - replicas=1' >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    # The port needs to be exposed to accept DNS requests" >> $ymlname
					echo -e "    ports:" >> $ymlname
					echo -e "      - $dnsproxyport:$dnsproxyport" >> $ymlname
					echo -e "      - $dnsproxyport:$dnsproxyport/udp" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/server/$tsconfname:/server/doh-server.conf" >> $ymlname
      				echo -e "      # Mount app-config script with your customizations" >> $ymlname
      				echo -e "      - $rootdir/docker/$containername/app-config:/app-config" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					# Remove the last line of the file
                    sed -i '$ d' $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$dhsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port '$dnsproxyport';/g' $destconf

					echo -e "" >> $destconf
					echo -e "    # Do not proxy requests to the doh http prefix ($dohhttpsubfolder) through authelia so" >> $destconf
					echo -e "    # dns queries can come straight in without authentication but anyting else" >> $destconf
					echo -e "    # still gets routed for authentication" >> $destconf
					echo -e "    location /$dohhttpsubfolder {" >> $destconf
					echo -e "        # enable the next two lines for http auth" >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e "        #auth_basic_user_file /config/nginx/.htpasswd;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable the next two lines for ldap auth" >> $destconf
					echo -e "        #auth_request /auth;" >> $destconf
					echo -e "        #error_page 401 =200 /ldaplogin;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable for Authelia" >> $destconf
					echo -e "        #include /config/nginx/authelia-location.conf;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        include /config/nginx/proxy.conf;" >> $destconf
					echo -e "        include /config/nginx/resolver.conf;" >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port '$dnsproxyport';' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e "    }" >> $destconf

					echo -e "}" >> $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
				
					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##########################################################################################################################
	# DNSProxy (DNS over HTTPS (DoH) or DoT Resolver)
	    
		# http://mageddo.github.io/dns-proxy-server/latest/en/3-configuration/
		# https://www.linuxbabe.com/ubuntu/dns-over-https-doh-resolver-ubuntu-dnsdist

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall DNSProxy (DoH Resolver) (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=dnsproxy
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)
					dnsproxyport=5380
					#upstreamdns=$piholeip # Route to pihole or other dns provider like 1.1.1.1 or 9.9.9.9

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$containername/conf;
					mkdir -p $rootdir/docker/$containername/etc;
					mkdir -p $rootdir/docker/$containername/var-run;

					rm -rf $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: defreitas/dns-proxy-server" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified
					# Miscellaneous docker container parameters (user specified)
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    # The port needs to be exposed to accept DNS requests" >> $ymlname
					echo -e "    ports:" >> $ymlname
					echo -e "      - $dnsproxyport:$dnsproxyport" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/conf:/app/conf" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/etc:/var/run/docker.sock" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/var-run:/host/etc" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					sed -i 's/\"remoteDnsServers\": \[\]/\"remoteDnsServers\": \['$piholeip'\]/g' $rootdir/docker/$containername/conf/config.json

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$dpsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port '$dnsproxyport';/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
				
					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Farside - rotating redirector written in elixer by Ben Busby
		
		# https://github.com/benbusby/farside

		# Not running in docker!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

		containername=farside  # Not acutally a container, but used for consistency
		fssubfolder=farside  # Unpack subfolder - don't use spaces
		fsrunscriptname=fsrun.sh

        # Check if farside is already installed
        if [[ $(crontab -l | grep $fsrunscriptname) == *"$fsrunscriptname"* ]]
		then
                userprompt="Farside is already installed.  Do you want to reinstall it (y/n)? "
            else
                userprompt="Farside is not installed.  Do you want to install it (y/n)? "
        fi

        while true; do
            read -p $'\n'"$userprompt" yn
            case $yn in
                [Yy]* ) 
                    # Download the latest copy of radis - https://redis.io/
                    # wget https://download.redis.io/releases/redis-6.2.6.tar.gz
                    # Unpack the tarball
                    # tar -xzsf redis-6.2.6.tar.gz
                    # Install elixer - https://elixir-lang.org/install.html
                    wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb && sudo dpkg -i erlang-solutions_2.0_all.deb > /dev/null 2>&1
                    rm erlang-solutions_2.0_all.deb
                    sudo apt-get -qq update

                    # Install redis server
                    sudo apt install -y -qq redis-server esl-erlang elixir

                    # Download and upack farside
                    wget https://github.com/benbusby/farside/archive/refs/tags/v0.1.0.tar.gz
                    mkdir -p $rootdir/$fssubfolder
                    tar -xvf v0.1.0.tar.gz -C $rootdir/$fssubfolder --strip-components=1
					chmod 777 -R $rootdir/$fssubfolder
                    cd $rootdir/$fssubfolder
                    # Run the below from within the unpacked farside folder (farside-0.1.0)
                    # redis-server
                    mix deps.get
                    mix run -e Farside.Instances.sync
                    elixir --erl "-detached" -S mix run --no-halt

                    rm -f $fsrunscriptname && touch $fsrunscriptname

                    # Make a script to launch the app
                    # Check for running process and fire if not running
                    # Must use single quotes for !
                    echo -e '#!/bin/bash' >> $fsrunscriptname
                    echo -e 'cd $rootdir/$fssubfolder' >> $fsrunscriptname
                    echo -e 'while [ -z "$(ps aux | grep -w no-halt | grep elixir)" ];' >> $fsrunscriptname
                    echo -e 'do' >> $fsrunscriptname
                    echo -e 'elixir --erl "-detached" -S mix run --no-halt' >> $fsrunscriptname
                    echo -e 'sleep 30' >> $fsrunscriptname
                    echo -e 'done' >> $fsrunscriptname

                    # Set up a cron job to start the server once every five minutes if it isn't running
                    # so that it is always available.
                    if ! [[ $(crontab -l | grep $fsrunscriptname) == *"$fsrunscriptname"* ]]
                    then
                        (crontab -l 2>/dev/null || true; echo -e "*/5 * * * * $rootdir/$fssubfolder/$fsrunscriptname") | crontab -
                    fi
                    
                    # Uses localhost:4001
                    # edit farside-0.1.0/services.json if you desire to control the instances of redirects
                    # such as if you want to create your own federated list of servers to choose from
                    # in a less trusted model (e.g. yourserver.1, yourserver.2, yourserver.3...) ;)
                    cd $rootdir
                    rm -f v0.1.0.tar.gz

                    # Enable swag capture of farside
                    # Prepare the proxy-conf file using using syncthing.subdomain.conf.sample as a template
                    destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
                    cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sleep 5 && chown "$nonrootuser:$nonrootuser" $destconf

                    # Enabling authelia capture will greatly reduce the effectiveness of farside but opens you up to
                    # access to anyone on the internet.  Tradeoff...
                    #sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
                    #sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
                    sed -i 's/syncthing/'$containername'/g' $destconf
                    # Set the $upstream_app parameter to the ethernet IP address so it can be accessed from docker (swag)
                    sed -i 's/        set $upstream_app '$containername';/        set $upstream_app '$myip';/g' $destconf
                    sed -i 's/    server_name '$containername'./    server_name '$fssubdomain'./g' $destconf
                    sed -i 's/    set $upstream_port 8384;/    set $upstream_port 4001;/g' $destconf

v					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

                    # Firewall rules
                    iptables -t filter -A OUTPUT -p tcp --dport 4001 -j ACCEPT
                    iptables -t filter -A INPUT -p tcp --dport 4001 -j ACCEPT
                    iptables -t filter -A OUTPUT -p udp --dport 4001 -j ACCEPT
                    iptables -t filter -A INPUT -p udp --dport 4001 -j ACCEPT
                    # Block access to port 943 from the outside - traffic must go thhrough SWAG
                    # Blackhole outside connection attempts to port 943
                    #iptables -t nat -A PREROUTING -i eth0 ! -s 127.0.0.1 -p tcp --dport 4001 -j REDIRECT --to-port 0

					#iptables-save

	                break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done   

	##############################################################################################################################

	##############################################################################################################################
	# Firefox - linuxserver.io

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Firefox (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=firefox
					ymlname=$rootdir/$containername-compose.yml

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: lscr.io/linuxserver/firefox" >> $ymlname
					# Environmental variables
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - SUBFOLDER=/firefox/ # Required if using authelia to authenticate" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    shm_size: \"1gb\"" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					# Ports specifications
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 3000:3000 # WebApp port, don't publish this to the outside world - only proxy through swag/authelia" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/config" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/calibre.subfolder.conf.sample $destconf

					sed -i 's/calibre/firefox/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/    set $upstream_port 8080;/    set $upstream_port 3000;/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					# None required
					# #iptables-save

					break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done      

	##############################################################################################################################

	##############################################################################################################################
	# Homer - https://github.com/bastienwirtz/homer

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Homer (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# https://github.com/bastienwirtz/homer/blob/main/docs/configuration.md
					# Create the docker-compose file
					containername=homer
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername
					
					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: b4bz/homer" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					# Ports specifications (user speficied)
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/www/assets" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Make sure the stack started properly by checking for the existence of config.yml
					while [ ! -f $rootdir/docker/$containername/config.yml ]
						do
						sleep 5
						done

					# Create a backup of the config.yml file if needed
					while [ ! -f $rootdir/docker/$containername/config.yml.bak ]
						do
						cp $rootdir/docker/$containername/config.yml \
							$rootdir/docker/$containername/config.yml.bak;
						done

					sed -i 's/title: \"Demo dashboard\"/title: \"Dashboard - '"$fqdn"'\"/g' $rootdir/docker/$containername/config.yml
					sed -i 's/subtitle: \"Homer\"/subtitle: \"IP: '"$myip"'\"/g' $rootdir/docker/$containername/config.yml
					sed -i 's/  - name: \"another page!\"/\# - name: \"another page!\"/g' $rootdir/docker/$containername/config.yml
					sed -i 's/      icon: \"fas fa-file-alt\"/#     icon: \"fas fa-file-alt\"/g' $rootdir/docker/$containername/config.yml
					sed -i 's/          url: \"\#additionnal-page\"/#         url: \"\#additionnal-page\"/g' $rootdir/docker/$containername/config.yml
					sed -i 's/    icon: "fas fa-file-alt"/#   icon: "fas fa-file-alt"/g' $rootdir/docker/$containername/config.yml
					sed -i 's/    url: "#additionnal-page"/#   url: "#additionnal-page"/g' $rootdir/docker/$containername/config.yml

					# Throw everything over line 73
					sed -i '73,$ d' $rootdir/docker/$containername/config.yml

					# Add the links to other services installed above
					echo -e "    items:
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

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;/g' $destconf

					sed -i '3 i  
					' $destconf
					sed -i '4 i location / {' $destconf
					sed -i '5 i    return 301 $scheme://$host/'$containername'/;' $destconf
					sed -i '6 i }' $destconf
					sed -i '7 i 
					' $destconf
				
					# Firewall rules
					# None required
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
		done
	##############################################################################################################################

	##############################################################################################################################
	# Huginn - will not run on a subfolder

        #  Not working - compose has an issue.  See working

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Huginn (y/n)? " yn
            case $yn in
                [Yy]* ) 
                    # https://github.com/huginn/huginn/tree/master/docker/multi-process
                    # https://github.com/BytemarkHosting/configs-huginn-docker/blob/master/docker-compose.yml
                    # https://drwho.virtadpt.net/tags/huginn/
                    # Send a text message through email - https://www.digitaltrends.com/mobile/how-to-send-a-text-from-your-email-account/
                    # Learn regex for performing certain tasks like find+replace in huginn - https://regex101.com/

                    # Build after synapse so you can use the same postgres container
                    # Above didn't work for me, I had to go the route of using MySQL as
                    # the postgres container for huginn wouldn't launch properly unless
                    # it was on a completely seperate network.  Not able to figure out
                    # why exactly, and using a new database seemed to work.  Could try
                    # to get this sorted and use postgres, but it was simpler to just
                    # use mysql...whatever

                    # Create a very strong invitation code so that it is almost impossible
                    # for someone to sign up without prior knowledge
                    while true; do
						read -rp $'\n'"Enter your desired Huginn invitation code 'wWDmJTkPzx5zhxcWp': " invitationcode
						if [[ -z "${invitationcode}" ]]; then
							echo -e "Enter your desired Huginn invitation code or hit Ctrl+C to exit."
							continue
						fi
						break
                    done

                    # Create the docker-compose file
                    containername=huginn
                    ymlname=$rootdir/$containername-compose.yml
                    rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)
                    dbname=$containername && dbname+="_mysql"
                    huginndbuser=$(openssl rand -hex 12)
                    huginndbpass=$(openssl rand -hex 12)
                    mysqlrootpass=$(openssl rand -hex 12)
                    huginnport=3000 # Internal runs on 3000
					huginnseedusr=$(openssl rand -hex 12)
					huginnseedusrpass=$(openssl rand -hex 18)

                    huginnsubdirectory=$rndsubfolder

                    # Save variable to .bashrc for later persistent use
                    export_variable "\n# Huginn"
                    huginndbuser=$(manage_variable huginndbuser "$huginndbuser  # Huginn database user")
                    huginndbpass=$(manage_variable huginndbpass "$huginndbpass  # Huginn database password")
                    mysqlrootpass=$(manage_variable mysqlrootpass "$mysqlrootpass  # MySQL root password for huginn database")
                    invitationcode=$(manage_variable invitationcode "$invitationcode  # Huginn invitation code")
                    huginnseedusr=$(manage_variable huginnseedusr "$huginnseedusr  # Huginn seed (default) user")
                    huginnseedusrpass=$(manage_variable huginnseedusrpass "$huginnseedusrpass  # Huginn seed (default) user password")

                    # Commit the .bashrc changes
                    source $rootdir/.bashrc

                    # Remove any existing installation
                    $(docker-compose -f $ymlname -p $stackname down -v)
                    rm -rf $rootdir/docker/$containername

                    mkdir -p $rootdir/docker/$containername
                    mkdir -p $rootdir/docker/$containername/mysql

                    rm -f $ymlname && touch $ymlname

                    # Info on environmental variables
                    # https://github.com/huginn/huginn/blob/master/.env.example

                    # Build the .yml file
                    # Header (generic)
                    echo -e "$ymlhdr" >> $ymlname
                    echo -e "  $dbname:" >> $ymlname
                    echo -e "    container_name: $dbname" >> $ymlname
                    echo -e "    hostname: $dbname" >> $ymlname
                    echo -e "    # https://hub.docker.com/_/mariadb/" >> $ymlname
                    echo -e "    # Specify 10.3 as we only want watchtower to apply minor updates" >> $ymlname
                    echo -e "    # (eg, 10.3.1) and not major updates (eg, 10.4)." >> $ymlname
                    # Docker image (user specified)
                    echo -e "    image: mariadb:10.3" >> $ymlname
                    # Environmental variables (generic)
                    echo -e "    $ymlenv" >> $ymlname
                    # Additional environmental variables (user specified)
                    echo -e "      - MYSQL_ROOT_PASSWORD=$mysqlrootpass" >> $ymlname
                    echo -e "      - MYSQL_DATABASE=$dbname" >> $ymlname
                    echo -e "      - MYSQL_USER=$huginndbuser" >> $ymlname
                    echo -e "      - MYSQL_PASSWORD=$huginndbpass" >> $ymlname
                    # Miscellaneous docker container parameters (user specified)
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
                    # Network specifications (user specified)
                    echo -e "    networks:" >> $ymlname
                    echo -e "        no-internet:" >> $ymlname
                    # Ports specifications (user specified)
                    # Restart policies (generic)
                    echo -e "    $ymlrestart" >> $ymlname
                    # Volumes (user specified)
                    echo -e "    volumes:" >> $ymlname
                    echo -e "        # Ensure the database persists between restarts." >> $ymlname
                    echo -e "        - $rootdir/docker/$containername/mysql:/var/lib/mysql" >> $ymlname
                    
                    echo -e "  # The main application - https://hub.docker.com/hugin/hugin/" >> $ymlname
                    echo -e "  $containername:" >> $ymlname
                    echo -e "    container_name: $containername" >> $ymlname
                    echo -e "    hostname: $containername" >> $ymlname
                    # Docker image (user specified)
                    echo -e "    image: huginn/huginn" >> $ymlname
                    # Environmental variables (generic)
                    echo -e "    $ymlenv" >> $ymlname
                    # Additional environmental variables (user specified)
                    echo -e "      # Database configuration" >> $ymlname
                    echo -e "      - MYSQL_PORT_3306_TCP_ADDR=$dbname" >> $ymlname
                    echo -e "      - MYSQL_ROOT_PASSWORD=$mysqlrootpass" >> $ymlname
                    echo -e "      - HUGINN_DATABASE_NAME=$dbname" >> $ymlname
                    echo -e "      - HUGINN_DATABASE_USERNAME=$huginndbuser" >> $ymlname
                    echo -e "      - HUGINN_DATABASE_PASSWORD=$huginndbpass" >> $ymlname
                    echo -e "      - DATABASE_ENCODING=utf8mb4" >> $ymlname
                    echo -e "      # General Configuration" >> $ymlname
                    echo -e "      - INVITATION_CODE=$invitationcode" >> $ymlname
                    echo -e "      - REQUIRE_CONFIRMED_EMAIL=false" >> $ymlname
                    echo -e "      # Don't create the default "admin" user with password "password"." >> $ymlname
                    echo -e "      # Instead, use the below SEED_USERNAME and SEED_PASSWORD" >> $ymlname
                    echo -e "      - SEED_USERNAME=$huginnseedusr" >> $ymlname
                    echo -e "      - SEED_PASSWORD=$huginnseedusrpass" >> $ymlname
                    echo -e "      - DO_NOT_SEED=true # Do not provide default userid and password" >> $ymlname
                    # Miscellaneous docker container parameters (user specified)
                    echo -e "    depends_on:" >> $ymlname
                    echo -e "      - $dbname" >> $ymlname
                    # Network specifications (user specified)
                    echo -e "    networks:" >> $ymlname
                    echo -e "      no-internet:" >> $ymlname
                    echo -e "      internet:" >> $ymlname
                    echo -e "        ipv4_address: $ipaddress" >> $ymlname
                    # Ports specifications (user specified)
                    echo -e "    #ports:" >> $ymlname
                    echo -e "      #- $huginnport:3000" >> $ymlname
                    # Restart policies (generic)
                    echo -e "    $ymlrestart" >> $ymlname
                    # Volumes (user specified)
                    # Networks, etc (generic)...
                    echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

                    docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

                    # Wait until the stack is first initialized...
					echo -e "\nWaiting for the container to start for the first time..."
                    while [ -f "$(sudo docker ps | grep $containername)" ];
                        do
                            sleep 5
                    done

                    # Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
                    destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
                    cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

                    # Don't capture with Authelia or you won't be able to get your RSS feeds
                    # sed -i 's/    \#include \/config\/nginx\/authelia-server.conf;/    #include \/config\/nginx\/authelia-server.conf;/g' $destconf

                    sed -i 's/syncthing/'$containername'/g' $destconf
                    sed -i 's/    server_name '$containername'./    server_name '$hgsubdomain'./g' $destconf
                    sed -i 's/    \#include \/config\/nginx\/authelia-server.conf;/    include \/config\/nginx\/authelia-server.conf;/g' $destconf
                    sed -i 's/        \#include \/config\/nginx\/authelia-location.conf;/        include \/config\/nginx\/authelia-location.conf;/g' $destconf
                    #sed -i 's/        set $upstream_app '$containername';/        set $upstream_app '$ipaddress';/g' $destconf
					sed -i 's/        set $upstream_app '$containername';/        set $upstream_app '$containername';/g' $destconf
                    sed -i 's/    set $upstream_port 8384;/    set $upstream_port '$huginnport';/g' $destconf

                    # Remove the last line of the file
                    sed -i '$ d' $destconf

                    # https://stackoverflow.com/questions/22224441/nginx-redirect-all-requests-from-subdirectory-to-another-subdirectory-root
                    # https://linuxhint.com/nginx-location-regex-examples/
                    echo -e "" >> $destconf
                    echo -e '    # Allow unauthenticated access to xml used as rss feeds' >> $destconf
                    echo -e '    # by commenting out the authelia-location.conf line' >> $destconf
                    echo -e '    # for specifc request to the regex below.' >> $destconf
                    echo -e '    location ~ /users/(.*).xml$ {' >> $destconf
                    echo -e '        # enable the next two lines for http auth' >> $destconf
                    echo -e '        #auth_basic "Restricted";' >> $destconf
                    echo -e '        #auth_basic_user_file /config/nginx/.htpasswd;' >> $destconf
					echo -e "" >> $destconf
                    echo -e '        # enable the next two lines for ldap auth' >> $destconf
                    echo -e '        #auth_request /auth;' >> $destconf
                    echo -e '        #error_page 401 =200 /ldaplogin;' >> $destconf
					echo -e "" >> $destconf
                    echo -e '        # enable for Authelia' >> $destconf
                    echo -e '        #include /config/nginx/authelia-location.conf;' >> $destconf
					echo -e "" >> $destconf
                    echo -e '        include /config/nginx/proxy.conf;' >> $destconf
                    echo -e '        include /config/nginx/resolver.conf;' >> $destconf
                    #echo -e '        set $upstream_app '$ipaddress';' >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
                    echo -e '        set $upstream_port '$huginnport';' >> $destconf
                    echo -e '        set $upstream_proto http;' >> $destconf
                    echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e '    }' >> $destconf
					echo -e '}' >> $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

                    # Firewall rules
                    # None required
					# #iptables-save

                    break;;
	            [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done      
	##############################################################################################################################

	##############################################################################################################################
	# JAMS Jami server application - https://jami.biz/jams-user-guide#Obtaining-JAMS

		# https://git.jami.net/savoirfairelinux/jami-jams
		# JAMS - https://git.jami.net/savoirfairelinux/jami-jams
		##################################################################################################################################
		
		#wget https://git.jami.net/savoirfairelinux/jami-jams

		#docker run -p 80:8080 --rm jams:latest
		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

	##############################################################################################################################

	##############################################################################################################################
	# Jitsi meet server - will not run on a subfolder

		# Not a docker container!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend
		
		# Requires four ip addresses
		jwipend=$ipend && ip1=$ipaddress
		jwipend=$(($jwipend+1)) && ip2=$subnet.$jwipend
		jwipend=$(($jwipend+1)) && ip3=$subnet.$jwipend
		jwipend=$(($jwipend+1)) && ip4=$subnet.$jwipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Jitsi Meet (y/n)? " yn
            case $yn in
                [Yy]* )

                    while true; do
						read -rp $'\n'"Enter your desired Jitsi-Meet userid - example - 'mynewuser' or (better) 'Fkr5HZH4Rv': " jmoduser
						if [[ -z "${jmoduser}" ]]; then
							echo -e "Enter your desired Jitsi-Meet userid or hit Ctrl+C to exit."
							continue
						fi
						break
                    done

                    while true; do
						read -rp $'\n'"Enter your desired Jitsi-Meet password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " jmodpass
						if [[ -z "${jmodpass}" ]]; then
							echo -e "Enter your desired Jitsi-Meet password or hit Ctrl+C to exit."
							continue
						fi
						break
                    done

                    while true; do
						read -rp $'\n'"Enter your desired Jitsi-Meet meeting prefix 'wWDmJTkPzx5zhxcWp': " meetingprefix
						if [[ -z "${meetingprefix}" ]]; then
							echo -e "Enter your desired Jitsi-Meet meeting prefix or hit Ctrl+C to exit."
							continue
						fi
						break
                    done

					# https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker
					# https://github.com/jitsi/jitsi-meet-electron/releases
					# https://scribe.rip/nginx-and-lets-encrypt-with-docker-in-less-than-5-minutes-b4b8a60d3a71

					# Unresolved issue of endpoints on the same network not showing video or audio
					#    https://community.jitsi.org/t/jitsi-meet-coturn/82394/14
					#    https://community.jitsi.org/t/use-turn-server-with-docker-version-of-jitsi/110032/12
					#    https://meetrix.io/blog/webrtc/jitsi/setting-up-a-turn-server-for-jitsi-meet.html
					#    https://jitsi.github.io/handbook/docs/devops-guide/turn/#use-turn-server-on-port-443


					# Jitsi Broadcasting Infrastructure (Jibri) - https://jitsi.github.io/handbook/docs/devops-guide/devops-guide-docker#advanced-configuration
					# Install dependencies
					sudo apt-get -qq update && sudo apt-get install -y -qq linux-image-extra-virtual

					containername=jitsiweb
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)
					jitsilatest=stable-6826
					jextractdir=docker-jitsi-meet-$jitsilatest
					jcontdir=jitsi-meet
					# Meeting prefix is used to let people into the meeting without the need
					# for authelia login.  Usefull for sending links to 'guests'
					# meetingprefix=$(echo $RANDOM | md5sum | head -c 15)

					# Save variable to .bashrc for later persistent use
					export_variable "\n# Jitsi Meet"
					jitsilatest=$(manage_variable "jitsilatest" "$jitsilatest" "-r")
					jextractdir=$(manage_variable "jextractdir" "$jextractdir" "-r")
					jcontdir=$(manage_variable "jcontdir" "$jcontdir" "-r")
					jmoduser=$(manage_variable "jmoduser" "$jmoduser" "-r")
					jmodpass=$(manage_variable "jmodpass" "$jmodpass" "-r")
					meetingprefix=$(manage_variable "meetingprefixs" "$meetingprefix" -r)
					tssharedsecret=$(manage_variable "tssharedsecret" "$tssharedsecret # Turnserver shared secret")

					# Commit the .bashrc changes
					source $rootdir/.bashrc

					# Remove any existing installation
					rm -rf $jitsilatest.tar.gz*
					rm -rf $rootdir/$jextractdir
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername/{web/crontabs,web/letsencrypt,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}

					wget https://github.com/jitsi/docker-jitsi-meet/archive/refs/tags/$jitsilatest.tar.gz

					tar -xzsf $jitsilatest.tar.gz
					rm -rf $jitsilatest.tar.gz*

					# Copy env.example file to production (.env) if needed
					while [ ! -f $rootdir/$jextractdir/.env ]
						do
							cp $rootdir/$jextractdir/env.example \
								$rootdir/$jextractdir/.env;
					done

					# Generate some strong passwords in the .env file
					$rootdir/$jextractdir/gen-passwords.sh

					mypath="$rootdir"
					# Fix it up for substitutions using sed by adding backslashes to escaped charaters
					mypath=${mypath//\//\\/}

					# Update the .env file
					sed -i 's/CONFIG=~\/.jitsi-meet-cfg/CONFIG='$mypath'\/docker\/'$jcontdir'/g' $rootdir/$jextractdir/.env
					sed -i 's/HTTP_PORT=8000/HTTP_PORT=8181/g' $rootdir/$jextractdir/.env
					sed -i 's/\#PUBLIC_URL=https:\/\/meet.example.com/PUBLIC_URL=https:\/\/'$jwebsubdomain'.'$fqdn'/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_LOBBY=1/ENABLE_LOBBY=1/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_AV_MODERATION=1/ENABLE_AV_MODERATION=1/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_PREJOIN_PAGE=0/ENABLE_PREJOIN_PAGE=0/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_WELCOME_PAGE=1/ENABLE_WELCOME_PAGE=1/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_CLOSE_PAGE=0/ENABLE_CLOSE_PAGE=0/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_NOISY_MIC_DETECTION=1/ENABLE_NOISY_MIC_DETECTION=1/g' $rootdir/$jextractdir/.env

					# If having any issues with nginx not picking up the letsencrypt certificate see:
					# https://github.com/jitsi/docker-jitsi-meet/issues/92
					#sed -i 's/\#ENABLE_LETSENCRYPT=1/\#ENABLE_LETSENCRYPT=1/g' $rootdir/$jextractdir/.env
					sed -i 's/\#LETSENCRYPT_DOMAIN=meet.example.com/LETSENCRYPT_DOMAIN='$jwebsubdomain'.'$fqdn'/g' $rootdir/$jextractdir/.env
					sed -i 's/\#LETSENCRYPT_EMAIL=alice@atlanta.net/LETSENCRYPT_EMAIL='$(openssl rand -hex 25)'@'$(openssl rand -hex 25)'.net/g' $rootdir/$jextractdir/.env
					sed -i 's/\#LETSENCRYPT_USE_STAGING=1/\#LETSENCRYPT_USE_STAGING=1/g' $rootdir/$jextractdir/.env

					# Use the staging server (for avoiding letsencrypt rate limits while testing) - not for production environment
					#LETSENCRYPT_USE_STAGING=1
					sed -i 's/\#ENABLE_AUTH=1/ENABLE_AUTH=1/g' $rootdir/$jextractdir/.env
					sed -i 's/\#ENABLE_GUESTS=1/ENABLE_GUESTS=1/g' $rootdir/$jextractdir/.env
					sed -i 's/\#AUTH_TYPE=internal/AUTH_TYPE=internal/g' $rootdir/$jextractdir/.env

					# Configure an external TURN server
					#sed -i "s/\# TURN_CREDENTIALS=secret/TURN_CREDENTIALS=$tssharedsecret/g" $rootdir/$jextractdir/.env
					#sed -i "s/\# TURN_HOST=turnserver.example.com/TURN_HOST=$ctsubdomain.$fqdn/g" $rootdir/$jextractdir/.env
					#sed -i 's/\# TURN_PORT=443/TURN_PORT=3478/g' $rootdir/$jextractdir/.env
					#sed -i "s/\# TURNS_HOST=turnserver.example.com/TURNS_HOST=$ctsubdomain.$fqdn/g" $rootdir/$jextractdir/.env
					#sed -i 's/\# TURNS_PORT=443/TURNS_PORT=3478/g' $rootdir/$jextractdir/.env

					# Enabling these will stop swag from picking up the container on port 80
					#sed -i 's/\#ENABLE_HTTP_REDIRECT=1/ENABLE_HTTP_REDIRECT=1/g' $rootdir/$jextractdir/.env
					#sed -i 's/\# ENABLE_HSTS=1/ENABLE_HSTS=1/g' $rootdir/$jextractdir/.env

					# https://community.jitsi.org/t/you-have-been-disconnected-on-fresh-docker-installation/89121/10
					# Solution below:
					echo -e "\n\n# Added based on this - https://community.jitsi.org/t/you-have-been-disconnected-on-fresh-docker-installation/89121/10" >> $rootdir/$jextractdir/.env
					echo -e "ENABLE_XMPP_WEBSOCKET=0" >> $rootdir/$jextractdir/.env

					cp $rootdir/$jextractdir/docker-compose.yml $rootdir/$jextractdir/docker-compose.yml.bak

					# Rename the web gui docker container
					sed -i "s/    web:/    $containername:/g" $rootdir/$jextractdir/docker-compose.yml
					# Don't publish an ports, only expose through authelia
					sed -i '8 s/./#&/' $rootdir/$jextractdir/docker-compose.yml # Comment out line 8
					sed -i '9 s/./#&/' $rootdir/$jextractdir/docker-compose.yml # Comment out line 9
					sed -i '10 s/./#&/' $rootdir/$jextractdir/docker-compose.yml # Comment out line 10

					# Prevent guests from creating rooms or joining until a moderator has joined
					sed -i 's/            - ENABLE_AUTO_LOGIN/            #- ENABLE_AUTO_LOGIN/g' $rootdir/$jextractdir/docker-compose.yml

					# Add the required netowrks for compatability with other containers
					# First get rid of the existing mee.jitsi network
					sed -i ':a;N;$!ba;s/networks:\n    meet.jitsi://g' $rootdir/$jextractdir/docker-compose.yml
					# Echo in our custom network setup
					echo -e "$ymlftr" >> $rootdir/$jextractdir/docker-compose.yml

					# Jitsi video bridge (jvb) container needs access to the internet for video and audio to work (4th instance)
					sed -i 's/            meet.jitsi:/            no-internet:\n            internet:\n                ipv4_address: '$ip1'/g' $rootdir/$jextractdir/docker-compose.yml
					sed -i ':a;N;$!ba;s/'$ip1'/'$ip2'/2' $rootdir/$jextractdir/docker-compose.yml
					sed -i ':a;N;$!ba;s/'$ip1'/'$ip3'/2' $rootdir/$jextractdir/docker-compose.yml
					sed -i ':a;N;$!ba;s/'$ip1'/'$ip4'/2' $rootdir/$jextractdir/docker-compose.yml
					
					# Bring up the docker containers
					docker-compose -f $rootdir/$jextractdir/docker-compose.yml -p $stackname up -d

					# Add a moderator user.  Change 'userid' and 'password' to something secure like 'UjcvJ4jb' 
					# and 'QBo3fMdLFpShtkg2jvg2XPCpZ4NkDf3zp6Xn6Ndf'
					docker exec -i $(sudo docker ps | grep prosody | awk '{print $NF}') bash -c "prosodyctl --config /config/prosody.cfg.lua register $jmoduser meet.jitsi $jmodpass"

					# Prepare the proxy-conf file using syncthing.subdomain.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf
					
					# Capture the landing and conference call creation page through authelia to prevent misuse
					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i "s/syncthing/$containername/g" $destconf
					sed -i "s/server_name $containername./server_name $jwebsubdomain./g" $destconf
					sed -i 's/    \#include \/config\/nginx\/authelia-server.conf;/    include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/        \#include \/config\/nginx\/authelia-location.conf;/        include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 80;/g' $destconf
	
					# Do not proxy subfolders to the landing page through authelia so that 
					# inviies can come straight in.

					# Remove the last line of the file
                    sed -i '$ d' $destconf

					echo -e "" >> $destconf
					echo -e "    # Do not proxy subfolders to the landing page through authelia so that invities" >> $destconf
					echo -e "    # can come straight in if the meeting subfolder starts with $meetingprefix." >> $destconf
					echo -e "    location ~ /($meetingprefix|libs|css|colibri-ws|sounds|images|.well-known)(.+)$ {" >> $destconf
					echo -e "        # enable the next two lines for http auth" >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e "        #auth_basic_user_file /config/nginx/.htpasswd;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable the next two lines for ldap auth" >> $destconf
					echo -e "        #auth_request /auth;" >> $destconf
					echo -e "        #error_page 401 =200 /ldaplogin;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable for Authelia" >> $destconf
					echo -e "        #include /config/nginx/authelia-location.conf;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        include /config/nginx/proxy.conf;" >> $destconf
					echo -e "        include /config/nginx/resolver.conf;" >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port 80;' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e "    }" >> $destconf


					echo -e "" >> $destconf
					echo -e "    # Do not proxy subfolders to the landing page through authelia so that invities" >> $destconf
					echo -e "    # can come straight in if the meeting subfolder starts with $meetingprefix." >> $destconf
					echo -e "    location /config.js {" >> $destconf
					echo -e "        # enable the next two lines for http auth" >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e "        #auth_basic_user_file /config/nginx/.htpasswd;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable the next two lines for ldap auth" >> $destconf
					echo -e "        #auth_request /auth;" >> $destconf
					echo -e "        #error_page 401 =200 /ldaplogin;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable for Authelia" >> $destconf
					echo -e "        #include /config/nginx/authelia-location.conf;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        include /config/nginx/proxy.conf;" >> $destconf
					echo -e "        include /config/nginx/resolver.conf;" >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port 80;' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e "    }" >> $destconf

					echo -e "" >> $destconf
					echo -e "    # Do not proxy subfolders to the landing page through authelia so that invities" >> $destconf
					echo -e "    # can come straight in if the meeting subfolder starts with $meetingprefix." >> $destconf
					echo -e "    location /http-bind {" >> $destconf
					echo -e "        # enable the next two lines for http auth" >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e "        #auth_basic_user_file /config/nginx/.htpasswd;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable the next two lines for ldap auth" >> $destconf
					echo -e "        #auth_request /auth;" >> $destconf
					echo -e "        #error_page 401 =200 /ldaplogin;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable for Authelia" >> $destconf
					echo -e "        #include /config/nginx/authelia-location.conf;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        include /config/nginx/proxy.conf;" >> $destconf
					echo -e "        include /config/nginx/resolver.conf;" >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port 80;' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e "    }" >> $destconf

					echo -e "}" >> $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					# Jitsi video bridge
					iptables -t filter -A OUTPUT -p udp --dport 4443 -j ACCEPT
					iptables -t filter -A INPUT -p udp --dport 4443 -j ACCEPT
					iptables -t filter -A OUTPUT -p tcp --dport 10000 -j ACCEPT
					iptables -t filter -A INPUT -p tcp --dport 10000 -j ACCEPT

					#iptables-save

					# Ran into some issues with the app not working on iOS.  Below few links may be helpful
					#  - https://community.jitsi.org/t/you-have-been-disconnected/33529/4


                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Libre translate - will not run on a subfolder!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Libre translate (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=libretranslate
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: libretranslate/libretranslate" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					echo -e "    #build: ." >> $ymlname
					echo -e "    # Uncomment below command and define your args if necessary" >> $ymlname
					echo -e "    # command: --ssl --ga-id MY-GA-ID --req-limit 100 --char-limit 500" >> $ymlname
					echo -e "    command: --ssl --build-arg with_models=true" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    # Don't expose external ports to prevent access outside swag" >> $ymlname
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 5000:5000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/config" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$ltsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
				
					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Lingva translate- will not run on a subfolder!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Lingva translate (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=lingvatranslate
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: thedaviddelta/lingva-translate:latest" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - site_domain=$lvsubdomain.$fqdn" >> $ymlname
					echo -e "      - dark_theme=true" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    # Don't expose external ports to prevent access outside swag" >> $ymlname
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 3000:3000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/config" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$lvsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 3000;/g' $destconf
					
					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					# None needed
					# #iptables-save
					
                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Neko Firefox browser

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Neko (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					while true; do
						read -rp $'\n'"Enter your desired neko user password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " nekoupass
						
						if [[ -z "${nekoupass}" ]]; then
							echo -e "Enter your desired neko user password or hit Ctrl+C to exit."
							continue
						fi

						break
					done

					while true; do
						read -rp $'\n'"Enter your desired neko admin password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " nekoapass
						
						if [[ -z "${nekoapass}" ]]; then
							echo -e "Enter your desired neko admin password or hit Ctrl+C to exit."
							continue
						fi

						break
					done

					while true; do
						read -rp $'\n'"Enter the URL for your Firefox sync server (eg https://somedomain/somesubfolder): " nekoffsync

						if [[ -z "${nekoffsync}" ]]; then
							echo -e "Enter the URL for your Firefox sync server or hit Ctrl+C to exit."
							continue
						fi

						break
					done

					containername=neko        
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(echo $RANDOM | md5sum | head -c 15)
					nekosubdirectory=$rndsubfolder
					nekoportrange1=52100
					nekoportrange2=52199

					# Save variable to .bashrc for later persistent use
					export_variable "\n# Neko"
					nekoupass=$(manage_variable "nekoupass" "$nekoupass" "-r")
					nekoapass=$(manage_variable "nekoapass" "$nekoapass" "-r")
					nekoffsync=$(manage_variable "nekoffsync" "$nekoffsync" "-r")
					#nekoffsync=${nekoffsync//\//\\/} # set up for sed replacement

					# Commit the .bashrc changes
					source $rootdir/.bashrc

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					wget https://raw.githubusercontent.com/m1k1o/neko/master/.docker/firefox/policies.json
					mv policies.json $rootdir/docker/$containername/policies.json

					wget https://raw.githubusercontent.com/m1k1o/neko/master/.docker/firefox/neko.js
					mv neko.js $rootdir/docker/$containername/mozilla.cfg

					mkdir -p $rootdir/docker/$containername/home;
					chmod 777 -R $rootdir/docker/$containername/home;

					# Remove the policy restrictions all together :)
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') /bin/bash -c "cp /usr/lib/firefox/distribution/policies.json /usr/lib/firefox/distribution/policies.json.bak"
					# Change some of the parameters in mozilla.cfg (about:config) - /usr/lib/firefox/mozilla.cfg
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') bash -c "sed -i 's/lockPref(\"xpinstall.enabled\", false);//g' /usr/lib/firefox/mozilla.cfg"
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') bash -c "sed -i 's/lockPref(\"xpinstall.whitelist.required\", true);//g' /usr/lib/firefox/mozilla.cfg"
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') bash -c 'echo -e "lockPref(\"identity.sync.tokenserver.uri\", \"'$nekoffsync'/token/1.0/sync/1.5\");" >> /usr/lib/firefox/mozilla.cfg'
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') bash -c "sed -i 's/lockPref(/pref(/g' /usr/lib/firefox/mozilla.cfg"

					# Configure policies for firefox - 
					# Remove the policy restrictions all together by deleting this file
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') /bin/bash -c "mv /usr/lib/firefox/distribution/policies.json /usr/lib/firefox/distribution/policies.json.bak"
					echo -e "	Adjusting policies.json..."
					sed -i 's/\"BlockAboutConfig\": true,/\"BlockAboutConfig\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/\"BlockAboutProfiles\": true,/\"BlockAboutProfiles\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/\"BlockAboutSupport\": true,/\"BlockAboutSupport\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/\"DisableAppUpdate\": true,/\"DisableAppUpdate\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/\"DisableBuiltinPDFViewer\": true,/\"DisableBuiltinPDFViewer\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/\"DisableFirefoxAccounts\": true,/\"DisableFirefoxAccounts\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/\"DisablePrivateBrowsing\": true,/\"DisablePrivateBrowsing\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/    \"DisableProfileImport\": true,/    \"DisableProfileImport\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/    \"DisableProfileRefresh\": true,/    \"DisableProfileRefresh\": false,/g' $rootdir/docker/$containername/policies.json # Allow installation of user selected add-ons
					sed -i 's/    \"DisableSystemAddonUpdate\": true,/    \"DisableSystemAddonUpdate\": false,/g' $rootdir/docker/$containername/policies.json
					sed -i 's/    \"DisplayBookmarksToolbar\": false,/    \"DisplayBookmarksToolbar\": true,/g' $rootdir/docker/$containername/policies.json  $rootdir/docker/$containername/policies.json
					#sed -i 's///g' $rootdir/docker/$containername/policies.json  $rootdir/docker/$containername/policies.json
					#sed -i 's///g' $rootdir/docker/$containername/policies.json  $rootdir/docker/$containername/policies.json
					#sed -i 's///g' $rootdir/docker/$containername/policies.json  $rootdir/docker/$containername/policies.json
					#sed -i 's///g' $rootdir/docker/$containername/policies.json  $rootdir/docker/$containername/policies.json
					#sed -i ':a;N;$!ba;s/      \"\*\": {\n//1' $rootdir/docker/$containername/policies.json
					#sed -i ':a;N;$!ba;s/        \"installation_mode\": \"blocked\"\n//1' $rootdir/docker/$containername/policies.json
					sed -i ':a;N;$!ba;s/        \"installation_mode\": \"blocked\"/        \"installation_mode\": \"allowed\"/1' $rootdir/docker/$containername/policies.json
					#sed -i ':a;N;$!ba;s/      },\n//3' $rootdir/docker/$containername/policies.json
					
					# Remove ublock origin
					sed -i ':a;N;$!ba;s/      \"uBlock0@raymondhill.net\": {\n//1' $rootdir/docker/$containername/policies.json
					sed -i ':a;N;$!ba;s/        \"install_url\": \"https:\/\/addons.mozilla.org\/firefox\/downloads\/latest\/ublock-origin\/latest.xpi\",\n//1' $rootdir/docker/$containername/policies.json
					# Change only the first instance
					sed -i ':a;N;$!ba;s/        \"installation_mode\": \"force_installed\"\n//1' $rootdir/docker/$containername/policies.json
					# Change only the third instance (now three, was four, but above eliminated one)
					sed -i ':a;N;$!ba;s/      },\n//2' $rootdir/docker/$containername/policies.json
										# Remove sponsorblock add-on
					sed -i ':a;N;$!ba;s/      \"sponsorBlocker@ajay.app\": {\n//1' $rootdir/docker/$containername/policies.json
					sed -i ':a;N;$!ba;s/        \"install_url\": \"https:\/\/addons.mozilla.org\/firefox\/downloads\/latest\/sponsorblock\/latest.xpi\",\n//1' $rootdir/docker/$containername/policies.json
					# Change only the first instance
					sed -i ':a;N;$!ba;s/        \"installation_mode\": \"force_installed\"\n//1' $rootdir/docker/$containername/policies.json
					# Change only the third instance (now three, was four, but above eliminated one)
					sed -i ':a;N;$!ba;s/      },\n//2' $rootdir/docker/$containername/policies.json
					sed -i ':a;N;$!ba;s/      },\n//2' $rootdir/docker/$containername/policies.json
					#sed -i 's/        \"installation_mode\": \"force_installed\"/        \"installation_mode\": \"force_installed\"/g' $rootdir/docker/$containername/policies.json
					#sed -i 's///g' $rootdir/docker/$containername/policies.json

					echo -e "	Adjusting mozilla.cfg...\n"
					sed -i 's/lockPref(\"app.update.auto\", false);/\#lockPref(\"app.update.auto\", false);/g' $rootdir/docker/$containername/mozilla.cfg
					sed -i 's/lockPref(\"app.update.enabled\", false);/\#lockPref(\"app.update.enabled\", false);/g' $rootdir/docker/$containername/mozilla.cfg
					sed -i 's/lockPref(\"extensions.update.enabled\", false);/\#lockPref(\"extensions.update.enabled\", false);/g' $rootdir/docker/$containername/mozilla.cfg
					#sed -i 's/lockPref(\"profile.allow_automigration\", false);/\#lockPref(\"profile.allow_automigration\", false);/g' $rootdir/docker/$containername/mozilla.cfg
					sed -i 's/lockPref(\"xpinstall.enabled\", false);/\#lockPref(\"xpinstall.enabled\", false);/g' $rootdir/docker/$containername/mozilla.cfg
					sed -i 's/lockPref(\"xpinstall.whitelist.required\", true);/\#lockPref(\"xpinstall.whitelist.required\", true);/g' $rootdir/docker/$containername/mozilla.cfg
					#sed -i 's/lockPref(\"identity.sync.tokenserver.uri\"/\"'$nekoffsync'\"/g' $rootdir/docker/$containername/mozilla.cfg
					# Set custon firefox sync server
					echo -e 'lockPref("identity.sync.tokenserver.uri", "'$nekoffsync'");' >> $rootdir/docker/$containername/mozilla.cfg
					#sed -i 's///g' $rootdir/docker/$containername/mozilla.cfg
					#sed -i 's///g' $rootdir/docker/$containername/mozilla.cfg					
					#sed -i 's///g' $rootdir/docker/$containername/mozilla.cfg
					#sed -i 's///g' $rootdir/docker/$containername/mozilla.cfg

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: m1k1o/neko:firefox" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - NEKO_SCREEN=1440x900@60" >> $ymlname
					echo -e "      - NEKO_PASSWORD=$nekoupass" >> $ymlname
					echo -e "      - NEKO_PASSWORD_ADMIN=$nekoapass" >> $ymlname
					echo -e "      - NEKO_EPR=$nekoportrange1-$nekoportrange2" >> $ymlname
					echo -e "      - NEKO_ICELITE=1" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    shm_size: \"2gb\"" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point neko to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    ports:" >> $ymlname
					echo -e "      #- 8000:8000" >> $ymlname
					echo -e "      - $nekoportrange1-$nekoportrange2:$nekoportrange1-$nekoportrange2/udp" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/policies.json:/usr/lib/firefox/distribution/policies.json:ro" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/mozilla.cfg:/usr/lib/firefox/mozilla.cfg:ro" >> $ymlname
					# Required so that you can transfer files to a location accessible to the browser (e.g. uBlock Origin config)
					#echo -e "      - $rootdir/docker/$containername/home:/home/neko" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername | grep -v tor)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;/g' $destconf

					# Remove the policy restrictions all together by deleting this file
					#docker exec -i $(sudo docker ps | grep $containername | grep -v tor | awk '{print $NF}') /bin/bash -c "mv /usr/lib/firefox/distribution/policies.json /usr/lib/firefox/distribution/policies.json.bak"

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Restart the container
					docker-compose -f $ymlname -p $stackname down
					
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the container is initialized...
					while [ -f "$(sudo docker ps | grep $containername | grep -v tor)" ];
						do
							sleep 5
					done

					# Unlock neko policies in /usr/lib/firefox/distribution/policies.json
					#docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
					#sed -i 's/    \"BlockAboutConfig\": true/    \"BlockAboutConfig\": false/g' /usr/lib/firefox/distribution/policies.json
					#EOF

					# Pihole may block this domain which will prevent n.eko from running - checkip.amazonaws.com

					# Wait just a bit for the container to fully deploy
					sleep 5

					# Firewall rules
					iptables -A INPUT -p udp --dport $nekoportrange1:$nekoportrange2 -j ACCEPT

					#iptables-save

					# Add custom search engine
					#   You must install the add-on 'Add custom search engine' in firefox.
					# After you add the custom search enigine, you can disable it
					# Whoogle
					# https://farside.link/whoogle/search?q=%s

					# /home/neko/.mozilla/firefox/profile.default - prefs.js

					# https://stackoverflow.com/questions/39236537/exec-sed-command-to-a-docker-container
					# Run commands inside the docker
					#docker exec -i $(sudo docker ps | grep _neko | awk '{print $NF}') bash <<EOF
					#sed -ire '/URL_BASE = /c\api.myapiurl' /tmp/config.ini
					#grep URL_BASE /tmp/config.ini
					# any other command you like
					#EOF

					# Move your firefox cointainers
					# about:support
					# Follow the link to 'Profile Folder'

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Neko Tor browser

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Neko Tor (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=tor
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)
					torsubdirectory=$rndsubfolder
					torportrange1=52200
					torportrange2=52299

					nekoupass=$(manage_variable "nekoupass" "$nekoupass")
					nekoapass=$(manage_variable "nekoapass" "$nekoapass")

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: m1k1o/neko:tor-browser" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - NEKO_SCREEN=1440x900@60" >> $ymlname
					echo -e "      - NEKO_PASSWORD=$nekoupass" >> $ymlname
					echo -e "      - NEKO_PASSWORD_ADMIN=$nekoapass" >> $ymlname
					echo -e "      - NEKO_EPR=$torportrange1-$torportrange2" >> $ymlname
					echo -e "      - NEKO_ICELITE=1" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    shm_size: \"2gb\"" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point neko to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    ports:" >> $ymlname
					echo -e "      #- 8000:8000" >> $ymlname
					echo -e "      - $torportrange1-$torportrange2:$torportrange1-$torportrange2/udp" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
					do
					sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;/g' $destconf
					
					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					iptables -A INPUT -p udp --dport $torportrange1:$torportrange2 -j ACCEPT

					#iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Nitter (Twitter frontend) - will not run on a subfolder

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend
		#nipend=$(($ipend+100)) && ipaddress=$subnet.$nipend # You can remove this later for full deploy

		# Requires two ip addresses
		#redisipend=$(($ipend+1)) && redisip=$subnet.$redisipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Nitter a Twitter frontend (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# https://github.com/goodtiding5/docker-nitter
					# https://github.com/zedeus/nitter

					# Install some depndencies
					sudo apt-get -qq update && sudo apt install -y -qq git yarn nodejs

					# Create the docker-compose file
					containername=nitter
					redisname=$containername'_redis'
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername;
					rm -rf $rootdir/docker/$redisname;

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$redisname;

					rm -f $ymlname && touch $ymlname

					# Create the .conf files
					rm -f $rootdir/docker/$containername/nitter.conf && touch $rootdir/docker/$containername/nitter.conf
					chown "$nonrootuser:$nonrootuser" $rootdir/docker/$containername/nitter.conf

					rm -f $rootdir/docker/$redisname/redis.conf && touch $rootdir/docker/$redisname/redis.conf
					chown "$nonrootuser:$nonrootuser" $rootdir/docker/$redisname/redis.conf

					# Build the .yml file - https://github.com/goodtiding5/docker-nitter
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname

					echo -e "  $redisname:" >> $ymlname
					echo -e "    container_name: $redisname" >> $ymlname
					echo -e "    hostname: $redisname" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: redis:alpine" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					# Ports specifications (user specified)
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
      				echo -e "      - $rootdir/docker/$redisname:/data" >> $ymlname

					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: epenguincom/nitter:latest" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - REDIS_HOST=\"$redisname\"" >> $ymlname
					echo -e "      - NITTER_HOST=farside.link\/nitter" >> $ymlname
					echo -e "      - NITTER_NAME=$containername" >> $ymlname
					echo -e "      - REPLACE_TWITTER=farside.link\/nitter" >> $ymlname
					#echo -e "      - REPLACE_YOUTUBE=piped.kavin.rocks" >> $ymlname
					echo -e "      - REPLACE_YOUTUBE=farside.link\/invidious" >> $ymlname
					echo -e "      - REPLACE_REDDIT=farside.link\/libreddit" >> $ymlname
					echo -e "      - REPLACE_INSTAGRAM=farside.link\/bibliogram" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    depends_on:" >> $ymlname
					echo -e "      - $redisname" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 8080:8080" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					#echo -e "    volumes:" >> $ymlname
      				#echo -e "      - $rootdir/docker/$containername/nitter.conf:/src/nitter.conf" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname
					
					# Launch the 'normal' way using the yml file
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$ntsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 8080;/g' $destconf

					# Remove the last line of the file
                    sed -i '$ d' $destconf

					# Allow rss feeds to be retrieved without authentication
					echo -e "" >> $destconf
					echo -e "    # Do not proxy rss feeds through authelia so that they can be" >> $destconf
					echo -e "    # updeated by your rss feed reader without authentication." >> $destconf
					echo -e "    location ~ /(.+)/rss$ {" >> $destconf
					echo -e "        # enable the next two lines for http auth" >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e "        #auth_basic_user_file /config/nginx/.htpasswd;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable the next two lines for ldap auth" >> $destconf
					echo -e "        #auth_request /auth;" >> $destconf
					echo -e "        #error_page 401 =200 /ldaplogin;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable for Authelia" >> $destconf
					echo -e "        #include /config/nginx/authelia-location.conf;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        include /config/nginx/proxy.conf;" >> $destconf
					echo -e "        include /config/nginx/resolver.conf;" >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port 8080;' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e "    }" >> $destconf

					echo -e "" >> $destconf
					echo -e "    # Do not proxy rss feeds through authelia so that they can be" >> $destconf
					echo -e "    # updeated by your rss feed reader without authentication." >> $destconf
					echo -e "    location ~ /(.+)/with_replies/rss$ {" >> $destconf
					echo -e "        # enable the next two lines for http auth" >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e "        #auth_basic_user_file /config/nginx/.htpasswd;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable the next two lines for ldap auth" >> $destconf
					echo -e "        #auth_request /auth;" >> $destconf
					echo -e "        #error_page 401 =200 /ldaplogin;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        # enable for Authelia" >> $destconf
					echo -e "        #include /config/nginx/authelia-location.conf;" >> $destconf
					echo -e "" >> $destconf
					echo -e "        include /config/nginx/proxy.conf;" >> $destconf
					echo -e "        include /config/nginx/resolver.conf;" >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port 8080;' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e "    }" >> $destconf

					echo -e "}" >> $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# PhantomJS - 

		# https://stackoverflow.com/questions/39451134/installing-phantomjs-with-node-in-docker

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

	##############################################################################################################################

	##############################################################################################################################
	# PolitePol
	    
		# https://github.com/taroved/pol

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Politepol (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# https://irosyadi.gitbook.io/irosyadi/app/rss-tool
					# https://gitlab.com/stormking/feedropolis
					# Create the docker-compose file

					git clone https://github.com/taroved/pol
					cd pol

					containername=politepol
					# Note small change on ymlname below...
					ymlname=$rootdir/pol/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)
					ppolsubdirectory=$rndsubfolder
					pport=8088
					dbport=3336
					dbname=$containername && dbname+="_mysql"

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername

					# Save variable to .bashrc for later persistent use
					export_variable "\n# Politepol - rss feed generator"
					pport=$(manage_variable "pport" "$pport  # Politepol port" "-r")

					# Commit the .bashrc changes
					source $rootdir/.bashrc

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: politepol:latest" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - DB_NAME=$containername" >> $ymlname
					echo -e "      - DB_USER=rooooooooooot" >> $ymlname
					echo -e "      - DB_PASSWORD=toooooooooooor" >> $ymlname
					echo -e "      - DB_HOST=$dbname" >> $ymlname
					echo -e "      - DB_PORT=$dbport" >> $ymlname
					echo -e "      - WEB_PORT=$pport" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    build:" >> $ymlname
					echo -e "      context: ." >> $ymlname
					echo -e "    #command: [\"./wait-for-it.sh\", \"dbpolitepol:3306\", \"--\", \"/bin/bash\", \"./frontend/start.sh\"]" >> $ymlname
					echo -e "    command: [\"./wait-for-it.sh\", \"$dbname:$dbport\", \"/bin/bash\", \"./frontend/start.sh\"]" >> $ymlname
					echo -e "    depends_on:" >> $ymlname
					echo -e "      - '$dbname'" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)

					echo -e "  $dbname:" >> $ymlname
					echo -e "    container_name: $dbname" >> $ymlname
					echo -e "    hostname: $dbname" >> $ymlname
					echo -e "    image: mysql:5.7" >> $ymlname
					echo -e "    environment:" >> $ymlname
					echo -e "      - MYSQL_DATABASE='$containername'" >> $ymlname
					echo -e "      - MYSQL_USER=rooooooooooot" >> $ymlname
					echo -e "      - MYSQL_PASSWORD=toooooooooooor" >> $ymlname
					echo -e "      - MYSQL_ROOT_PASSWORD=rootpass" >> $ymlname
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "    $ymlrestart" >> $ymlname
					echo -e "    volumes:" >> $ymlname
					echo -e "      - ./mysql:/var/lib/mysql" >> $ymlname

					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

					#sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port '$pport';/g' $destconf

					# Back to rootdir and clean up
					cd $rootdir
					rm -rf $rootdir/pol
					
					# Firewall rules
					iptables -A INPUT -p tcp --dport $pport -j ACCEPT

					#iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# rss-proxy - will not run on a subfolder!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall rss-proxy (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					# rss-proxy has some type of memory leak that leads it to spawn
					# multiple running process every time you try to get an update to
					# a given rss feed.  I chose to solve this by adding a cron job
					# running once per minute that kills all running rss-proxy processes
					# * * * * * ps -efw | grep rss-proxy | grep -v grep | awk '{print $2}' | xargs kill

					containername=rssproxy
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: damoeb/rss-proxy:js" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 3000:3000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    #volumes:" >> $ymlname
					echo -e "      #- $rootdir/docker/$containername:/opt/rss-proxy" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Add the crontab job to kill off already used rss-proxy feeds as this does
					# not seem to be done automatically and leads to overloaded CPU and memory
					# after repeted requests for feed update(s).  Run every two minutes
					if ! [[ $(crontab -l | grep rss-proxy) == *"rss-proxy"* ]]
					then
						(crontab -l 2>/dev/null || true; echo -e "*/1 * * * * ps -eaf | grep rss-proxy | grep -v grep | awk '{print $2}' | xargs kill") | crontab -
					fi

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					# Capture the setup page through authelia to prevent misuse
					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$rpsubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 3000;/g' $destconf

					# Do not proxy subfolders to the setup page through authelia so that 
					# feed readers can access the service without login.
					# Remove the last line of the file
                    sed -i '$ d' $destconf
					
					echo -e "" >> $destconf
					echo -e "    # Do not proxy subfolders to the landing page through authelia so that" >> $destconf
					echo -e '    # inviies can come straight in.' >> $destconf
					echo -e '    location ~ /api/(.*)$ {' >> $destconf
					echo -e '        # enable the next two lines for http auth' >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e '        #auth_basic_user_file /config/nginx/.htpasswd;' >> $destconf
					echo -e "" >> $destconf
					echo -e '        # enable the next two lines for ldap auth' >> $destconf
					echo -e '        #auth_request /auth;' >> $destconf
					echo -e '        #error_page 401 =200 /ldaplogin;' >> $destconf
					echo -e "" >> $destconf
					echo -e '        # enable for Authelia' >> $destconf
					echo -e '        #include /config/nginx/authelia-location.conf;' >> $destconf
					echo -e "" >> $destconf
					echo -e '        include /config/nginx/proxy.conf;' >> $destconf
					echo -e '        include /config/nginx/resolver.conf;' >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port 3000;' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e '    }' >> $destconf
					echo -e '}' >> $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##################################################################################################################################

	##################################################################################################################################
	# Synapse matrix server - will not run on a subfolder!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend
		# coturn IP address
		ctipend=$(($ipend+1)) && ctipaddress=$subnet.$ctipend

		# Video and audio calling only work on same lan - https://github.com/vector-im/element-web/issues/11368
		# Installing synapse with coturn:
		#		https://github.com/Miouyouyou/matrix-coturn-docker-setup/blob/master/docker-compose.yml
		#		https://hub.docker.com/r/coturn/coturn
		#		https://github.com/matrix-org/synapse/blob/develop/docs/turn-howto.md
		#		https://raddinox.com/self-hosted-discord-alternetive
		#		https://discourse.linuxserver.io/t/setting-up-matrix-behind-swag/3427
		# https://discourse.destinationlinux.network/t/setting-up-matrix-with-1-1-audio-video-calling-and-no-federation/2833
		#
		# You may need to enable access to the "Local Network" in iPhone for calling to work.

        while true; do
            read -p $'\n'"Do you want to install/reinstall Synapse (Matrix) (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# https://github.com/mfallone/docker-compose-matrix-synapse/blob/master/docker-compose.yaml
					# https://manpages.debian.org/testing/matrix-synapse/register_new_matrix_user.1.en.html

					while true; do
					read -rp $'\n'"Enter your desired synapse userid (only small letters)- example - 'wonderingwall': " syusrid
					if [[ -z "${syusrid}" ]]; then
						echo -e "Enter your desired synapse userid or hit Ctrl+C to exit."
						continue
					fi
					break
					done

					while true; do
					read -rp $'\n'"Enter your desired synapse password (only small letters)- example - 'brilliant_caustic': " sypass
					if [[ -z "${sypass}" ]]; then
						echo -e "Enter your desired synapse password or hit Ctrl+C to exit."
						continue
					fi
					break
					done

					while true; do
					read -rp $'\n'"How many non-admin users would you like to generate?: " nausrs
					if [[ -z "${nausrs}" ]]; then
						echo -e "Enter the number of random subdomains would you like to generate or hit Ctrl+C to exit."
						continue
					fi
					break
					done

					# Add a few more for the novice user, they may need them later even though they don't know it now :)
					#nausrs=$(($nausrs+10))

					# Create the docker-compose file
					containername=synapse
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)
					synapseport=8008
					dbname=$containername && dbname+="_postgres"
					ctname=coturn # Name of the coturn server
					REG_SHARED_SECRET=$(openssl rand -hex 35)
					POSTGRES_USER=synapse #$(openssl rand -hex 10)
					POSTGRES_PASSWORD=somepassword #$(openssl rand -hex 10)
					coturnportrange1=52300
					coturnportrange2=52399
					tsconfname=turnserver.conf
					tssharedsecret=$(echo $RANDOM | md5sum | head -c 25)

					# Save variable to .bashrc for later persistent use
					export_variable "\n# Synapse Matrix"
					syusrid=$(manage_variable "syusrid" "$syusrid  # Synapse userid" "-r")
					sypass=$(manage_variable "sypass" "$sypass  # Syanpse password" "-r")
					synapseport=$(manage_variable "synapseport" "$synapseport  # Syanpse port" "-r")
					tssharedsecret=$(manage_variable "tssharedsecret" "$tssharedsecret # Turnserver shared secret" "-r")
					
					# Commit the .bashrc changes
					source $rootdir/.bashrc

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername
					rm -rf $rootdir/docker/$ctname
					rm -rf $rootdir/docker/$dbname

					mkdir -p $rootdir/docker/$containername
					mkdir -p $rootdir/docker/$containername/data
					mkdir -p $rootdir/docker/$ctname
					mkdir -p $rootdir/docker/$ctname/var-lib-coturn
					mkdir -p $rootdir/docker/$dbname
					mkdir -p $rootdir/docker/$dbname/data

					rm -f $ymlname && touch $ymlname
					rm -f $rootdir/docker/$ctname/$tsconfname && touch $rootdir/docker/$ctname/$tsconfname

					# Build the .yml file - https://hub.docker.com/r/matrixdotorg/synapse
					#                       https://linuxhandbook.com/install-matrix-synapse-docker/
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname

					echo -e "  $ctname:" >> $ymlname
					echo -e "    container_name: $ctname" >> $ymlname
					echo -e "    hostname: $ctname" >> $ymlname
                    # Docker image (user specified)
					echo -e "    image: coturn/coturn:latest" >> $ymlname
                    echo -e "    $ymlenv" >> $ymlname
                    # Additional environmental variables (user specified)
                    # Miscellaneous docker container parameters (user specified)
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
                    # Network specifications (user specified)
                    echo -e "    networks:" >> $ymlname
                    echo -e "      no-internet:" >> $ymlname
                    echo -e "      internet:" >> $ymlname
                    echo -e "        ipv4_address: $ctipaddress" >> $ymlname
                    # Ports specifications (user specified)
                    echo -e "    ports:" >> $ymlname
                    echo -e "      - 3478:3478/tcp" >> $ymlname
                    echo -e "      - 3478:3478/udp" >> $ymlname
					echo -e "      - 5349:5349/tcp" >> $ymlname
					echo -e "      - 5349:5349/udp" >> $ymlname
					echo -e "      - $coturnportrange1-$coturnportrange2:$coturnportrange1-$coturnportrange2/udp" >> $ymlname
					echo -e "    $ymlrestart" >> $ymlname
					echo -e "    volumes:" >> $ymlname
					#echo -e "      - $rootdir/docker/$ctname/etc:/etc" >> $ymlname
					echo -e "      - $rootdir/docker/$ctname/$tsconfname:/etc/turnserver.conf:ro" >> $ymlname
      				echo -e "      - $rootdir/docker/$ctname/var-lib-coturn:/var/lib/coturn" >> $ymlname
					#echo -e "      - $rootdir/docker/$dbname/data:/var/lib/postgresql/data" >> $ymlname

					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: docker.io/matrixdotorg/synapse:latest" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - SYNAPSE_SERVER_NAME=$containername" >> $ymlname
					echo -e "      #- SYNAPSE_SERVER_ADDRESS=https://$containername" >> $ymlname
					echo -e "      - SYNAPSE_REPORT_STATS=no # Privacy" >> $ymlname
					echo -e "      - SYNAPSE_NO_TLS=1" >> $ymlname
					echo -e "      #- SYNAPSE_ENABLE_REGISTRATION=no" >> $ymlname
					echo -e "      #- SYNAPSE_CONFIG_PATH=/config" >> $ymlname
					echo -e "      #- SYNAPSE_LOG_LEVEL=DEBUG" >> $ymlname
					echo -e "      - SYNAPSE_REGISTRATION_SHARED_SECRET=$REG_SHARED_SECRET" >> $ymlname
					echo -e "      - SYNAPSE_VOIP_TURN_MAIN_URL=stun:$ctsubdomain.$fqdn:5349" >> $ymlname
					#echo -e "      - POSTGRES_DB=$containername" >> $ymlname
					#echo -e "      - POSTGRES_HOST=$dbname" >> $ymlname
					#echo -e "      - POSTGRES_USER=$POSTGRES_USER" >> $ymlname
					#echo -e "      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >> $ymlname
					echo -e "      - SYNAPSE_SERVER_NAME=$sysubdomain.$fqdn" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    #build:" >> $ymlname
					echo -e "      #context: ../.." >> $ymlname
					echo -e "      #dockerfile: docker/Dockerfile" >> $ymlname
					echo -e "    depends_on:" >> $ymlname
					echo -e "      - $ctname     # For the VOIP" >> $ymlname
					#echo -e "      - $dbname" >> $ymlname
					# Network specifications (user specified)
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point neko to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname # Required for push notifications to work
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    ports:" >> $ymlname
					echo -e "      # In order to expose Synapse, remove one of the following, you might for" >> $ymlname
					echo -e "      # instance expose the TLS port directly." >> $ymlname
					echo -e "      - $synapseport:$synapseport/tcp" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/data:/data" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					# https://adfinis.com/en/blog/how-to-set-up-your-own-matrix-org-homeserver-with-federation/
					# Run first to generate the homeserver.yaml file
					docker run -it --rm -v $rootdir/docker/$containername/data:/data -e SYNAPSE_SERVER_NAME=$sysubdomain.$fqdn -e SYNAPSE_REPORT_STATS=no -e SYNAPSE_HTTP_PORT=$synapseport -e PUID=1000 -e PGID=1000 matrixdotorg/synapse:latest generate

					configbackname=homeserver.yaml
					configbackpath=$rootdir/docker/$containername/data/$configbackname

					# Add a step to wait untilt the homeserver.yml file is created
					echo -e "Waiting for the $configbackname file to be created..."
					while [ ! -f $configbackpath ]
						do
							sleep 5
					done

					# Backup the clean configuration file
					echo -e "Create a backup of the clean $configbackname file to $configbackname.bak..."
                    while [ ! -f $configbackpath.bak ]
                        do
                            cp $configbackpath $configbackpath.bak;
							chown "$nonrootuser:$nonrootuser" $configbackpath.bak;
					done

					#  Edit the configuration file
					echo -e "Editing the $configbackname file..."
					chown "$nonrootuser:$nonrootuser" $configbackpath
					sed -i ':a;N;$!ba;s/\#max_upload_size: 50M/max_upload_size: 250M/1'$configbackpath # Maximum file upload size
					sed -i ':a;N;$!ba;s/  \#enabled: true/  enabled: true/2' $configbackpath # Replace the second instance
					sed -i 's/\#default_policy:/default_policy:/g' $configbackpath
					sed -i 's/\#  min_lifetime: 1d/  min_lifetime: 1d/g' $configbackpath
					sed -i 's/\#  max_lifetime: 1y/  max_lifetime: 7d/g' $configbackpath

					echo -e "\nturn_uris: [ \"turn:$ctsubdomain.$fqdn?transport=udp\", \"turn:$ctsubdomain.$fqdn?transport=tcp\" ]" >> $configbackpath
					echo -e "turn_shared_secret: \"$tssharedsecret\"" >> $configbackpath
					echo -e "turn_user_lifetime: 86400000" >> $configbackpath
					echo -e "turn_allow_guests: true" >> $configbackpath

					# Launch the 'normal' way using the yml file
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait for the stack to fully deploy
					while [ -f "$(sudo docker ps | grep $containername | grep -v ui)" ];
						do
							sleep 5
					done

					configbackname=$tsconfname
					configbackpath=$rootdir/docker/$ctname/$configbackname

					# Add a step to wait untilt the homeserver.yml file is created
					echo -e "Waiting for the $configbackname file to be created..."
					while [ ! -f $configbackpath ]
						do
							sleep 5
					done

					#  Edit the configuration file
					echo -e "Editing the $configbackname file..."
					echo -e "realm=$ctsubdomain.$fqdn" >> $configbackpath
					echo -e "use-auth-secret" >> $configbackpath
					echo -e "static-auth-secret=$tssharedsecret" >> $configbackpath
					echo -e "listening-ip=0.0.0.0" >> $configbackpath
					echo -e "listening-port=3478" >> $configbackpath
					echo -e "cli-password=$(echo $RANDOM | md5sum | head -c 40)" >> $configbackpath

					#chown "$nonrootuser:$nonrootuser" $configbackpath

					#sed -i 's/database:/\#database:/g' $configbackpath
					#sed -i 's/  name: sqlite3/\#  name: sqlite3/g' $configbackpath

					# Resatart the container
					$(docker-compose -f $ymlname -p $stackname down) && $(docker-compose --log-level ERROR -f $ymlname -p $stackname up -d)
					$(docker-compose --log-level ERROR -f $ymlname -p $stackname up -d)

					# Wait for the stack to fully deploy
					while [ -f "$(sudo docker ps | grep -w $containername | grep -v ui)" ];
						do
							sleep 5
					done

					sleep 5

					# Add the administrative user
					# If you are using a port other than 8448, it may fail unless to tell it where to look.  This command assumes it is on port 8448
					# docker exec -it $(sudo docker ps | grep $containername | awk '{ print$NF }') register_new_matrix_user -u $syusrid -p $sypass -a -c /data/homeserver.yaml
					# See this for a solution https://github.com/matrix-org/synapse/issues/6783
					echo -e "Adding the administrative user..."
					echo -e "docker exec -it $(sudo docker ps | grep -w $containername | grep -v ui | awk '{ print$NF }') register_new_matrix_user http://localhost:$synapseport -u $syusrid -p $sypass -a -c /data/homeserver.yaml"
					docker exec -it $(sudo docker ps | grep -w $containername | grep -v ui | awk '{ print$NF }') register_new_matrix_user http://localhost:$synapseport -u $syusrid -p $sypass -a -c /data/homeserver.yaml
					#$(docker exec -it $(sudo docker ps | grep -w $containername | grep -v ui | awk '{ print$NF }') register_new_matrix_user http://localhost:$synapseport -u $syusrid -p $sypass -a -c /data/homeserver.yaml)
					#sudo docker ps | grep synapse | awk '{ print$NF }'

					echo -e "You can just hit enter at the 'Make admin [no]:' prompt(s)."

					# Create the non-admin users
					i=0
					while [ $i -ne $nausrs ]
						do
							i=$(($i+1))
							nausrid=$(diceware -n 2 -d "_" --no-caps)  # synapse only accepts lower case userids
							napassphrase=$(diceware -n 3 -d "_")
							# Store the users in .bashrc if they don't already exist
							nausrid=$(manage_variable "nausr$i" "$nausrid  # Syanpse non-admin user$i")
							napassphrase=$(manage_variable "napassphrase$i" "$napassphrase  # Syanpse non-admin user$i passphrase")
							echo "docker exec -it $(sudo docker ps | grep $containername | grep -v ui | awk '{ print$NF }') register_new_matrix_user http://localhost:$synapseport -u $nausrid -p $napassphrase -c /data/homeserver.yaml"
							docker exec -it $(sudo docker ps | grep $containername | grep -v ui | awk '{ print$NF }') register_new_matrix_user http://localhost:$synapseport -u $nausrid -p $napassphrase -c /data/homeserver.yaml
					done

					# Set up swag
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/synapse.subdomain.conf.sample $destconf

					# Add a step to wait untilt the homeserver.yml file is created
					echo -e "Waiting for the $containername.subdomain.conf file to be created..."
					while [ ! -f $configbackpath ]
						do
							sleep 5
							cp $rootdir/docker/$swagloc/nginx/proxy-confs/synapse.subdomain.conf.sample $destconf
					done

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/    server_name matrix./    server_name '$sysubdomain'./g' $destconf
					sed -i 's/        set $upstream_app synapse;/        set $upstream_app '$containername';/g' $destconf
					sed -i 's/        set $upstream_port 8008;/        set $upstream_port '$synapseport';/g' $destconf

					# Do not proxy subfolders to the setup page through authelia so that 
					# feed readers can access the service without login.
					# Remove the last line of the file
                    sed -i '$ d' $destconf
					
					echo -e "" >> $destconf
					echo -e "    # Do not proxy subfolders to the landing page through authelia so that" >> $destconf
					echo -e '    # inviies can come straight in.' >> $destconf
					echo -e '    location ~ /(_matrix|_synapse|.well-known)/(.*)$ {' >> $destconf
					echo -e '        # enable the next two lines for http auth' >> $destconf
					echo -e '        #auth_basic "Restricted";' >> $destconf
					echo -e '        #auth_basic_user_file /config/nginx/.htpasswd;' >> $destconf
					echo -e "" >> $destconf
					echo -e '        # enable the next two lines for ldap auth' >> $destconf
					echo -e '        #auth_request /auth;' >> $destconf
					echo -e '        #error_page 401 =200 /ldaplogin;' >> $destconf
					echo -e "" >> $destconf
					echo -e '        # enable for Authelia' >> $destconf
					echo -e '        #include /config/nginx/authelia-location.conf;' >> $destconf
					echo -e "" >> $destconf
					echo -e '        include /config/nginx/proxy.conf;' >> $destconf
					echo -e '        include /config/nginx/resolver.conf;' >> $destconf
					echo -e '        set $upstream_app '$containername';' >> $destconf
					echo -e '        set $upstream_port '$synapseport';' >> $destconf
					echo -e '        set $upstream_proto http;' >> $destconf
					echo -e '        proxy_pass $upstream_proto://$upstream_app:$upstream_port;' >> $destconf
					echo -e '    }' >> $destconf
					echo -e '}' >> $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					iptables -A INPUT -p tcp --dport $synapseport -j ACCEPT
					
					#iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################
	
	##############################################################################################################################
	# Synapse UI - will not run on a subfolder!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Synapse UI (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# https://hub.docker.com/r/awesometechnologies/synapse-admin

					# Install some depndencies
					sudo apt-get -qq update && sudo apt install -y -qq git yarn nodejs

					# Download the repository
					#git clone https://github.com/Awesome-Technologies/synapse-admin.git

					#cd synapse-admin
					#yarn install
					#yarn start
					#cd $rootdir

					# Create the docker-compose file
					# Note the reuse of the synapse container name with appended 'ui'
					# This is there because grep will not find containers only named
					# 'synapse' and if synapse and synapseui are both installed, you
					# will have trouble getting just the synapse container.  See
					# the synapse installation fro grep command with '-v ui'.
					containername=synapseui
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)
					synapseuisubdirectory=$rndsubfolder

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;

					rm -f $ymlname && touch $ymlname

					#docker run awesometechnologies/synapse-admin

					# Build the .yml file - https://hub.docker.com/r/awesometechnologies/synapse-admin
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: awesometechnologies/synapse-admin" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - REACT_APP_SERVER=\"https://$sysubdomain.$fqdn\""  >> $ymlname  # Set the synapse url
					# Miscellaneous docker container parameters (user specified)
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 8080:80" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname
					
					# Launch the 'normal' way using the yml file
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					# Capture the setup page through authelia to prevent misuse
					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$suisubdomain'./g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 80;/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Syncthing

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Syncthing (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=syncthing
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)
					syncthingsubdirectory=$rndsubfolder

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$containername/Sync;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: lscr.io/linuxserver/syncthing" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    ports:" >> $ymlname
					echo -e "      #- 8384:8384 # WebApp port, don't publish this to the outside world - only proxy through swag/authelia" >> $ymlname
					echo -e "      - 21027:21027/udp" >> $ymlname
					echo -e "      - 22000:22000/tcp" >> $ymlname
					echo -e "      - 22000:22000/udp" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/config" >> $ymlname
					echo -e "      - $rootdir/docker:/config/Sync" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Restart syncthing so that changes to config.xml will not get overwritten
					docker-compose -f $ymlname -p $stackname down
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d
					docker-compose -f $ymlname -p $stackname down

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					configbackname=config.xml
					configbackpath=$rootdir/docker/$containername/$configbackname

                    # Make sure the stack started properly by checking for the existence of config.xml
                    echo -e "Waiting for the $configbackname file to be created..."
                   	while [ ! -f $configbackpath ]
						do
							sleep 5
					done

                    # Backup the clean configuration file
					echo -e "Create a backup of the clean $configbackname file to $configbackname.bak..."
                    while [ ! -f $configbackpath.bak ]
                        do
                            cp $configbackpath $configbackpath.bak;
							chown "$nonrootuser:$nonrootuser" $configbackpath.bak;
					done

					#  Edit the default config.xml file
					echo -e "Editing the $configbackname file..."
					# Make the default folder etc-pihole
					sed -i 's/<folder id=\"default\"/<folder id=\"etc-pihole\"/g' $configbackpath
					sed -i 's/label=\"Default Folder\"/label=\"Pihole Sync\"/g' $configbackpath
					sed -i 's/path=\"\/config\/Sync\"/path=\"\/config\/Sync\/pihole\/etc-pihole\"/g' $configbackpath
					sed -i 's/ignorePerms=\"false\"/ignorePerms=\"true\"/g' $configbackpath
					
					# Allow setting webgui userid and password
					sed -i "s/<address>127.0.0.1:8384/<address>$ipaddress:8384/g" $configbackpath
					# Turn off anonymous reporting
					sed -i 's/<urAccepted>0/<urAccepted>-1/g' $configbackpath
					sed -i 's/<urSeen>0/<urSeen>3/g' $configbackpath
					# Turn off crash reporting
					sed -i "s/crash.syncthing.net/$(openssl rand -hex 40)/g" $configbackpath
                    sed -i 's/<crashReportingEnabled>true/<crashReportingEnabled>false/g' $configbackpath

					# Restart syncthing so that changes to config.xml will not get overwritten
					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Prepare the proxy-conf file
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subfolder.conf.sample $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Firewall rules
					iptables -A INPUT -p udp --dport 21027 -j ACCEPT
					iptables -A OUTPUT -p udp --dport 21027 -j ACCEPT
					iptables -A INPUT -p tcp --dport 22000 -j ACCEPT
					iptables -A INPUT -p udp --dport 22000 -j ACCEPT
					iptables -A OUTPUT -p tcp --dport 22000 -j ACCEPT
					iptables -A OUTPUT -p udp --dport 22000 -j ACCEPT

					#iptables-save

					# Create a new folder from the web gui:
					#   Folder ID: etc-pihole
					#   Folder Path: /config/Sync/pihole/etc-pihole
					#   Advanced>Ignore Permissions checked

					# You will need to bootstrap up the pihole sync by adding other 
					# devices which can be done through the syncthing gui.
					# Please make sure that your pihole database is updated to the
					# latest version through the pihole gui first, or the 'new'
					# version of the pihole database on this instance will overwrite
					# your other devices database and you will loses your configuration.
					
					# Also, suggest you add a userid and password to syncthing gui
					# for added protection.

	                break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Unbound (DNS over HTTPS (DoH) proxy backend)

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Unbound a DoH proxy backend (y/n)? " yn
            case $yn in
                [Yy]* )

					# https://docs.pi-hole.net/guides/dns/unbound/
					# Solve some permission errors when mapping local volume - https://github.com/MatthewVance/unbound-docker/issues/22

					containername=unbound
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername;


					mkdir -p $rootdir/docker/$containername;
					#chmod 777 -R $rootdir/docker/$containername # Required for unbound to write to the directory

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: mvance/unbound:latest" >> $ymlname
					#echo -e "    image: klutchell/unbound" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					# Miscellaneous docker container parameters (user specified)
					#echo -e "    detach:" >> $ymlname
					#echo -e "      true" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 3000:3000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername:/etc/unbound/" >> $ymlname
					#echo -e "      - $rootdir/docker/$containername/unbound.conf:/etc/unbound/unbound.conf:ro" >> $ymlname
					#echo -e "      - $rootdir/docker/$containername/a-records.conf:/etc/unbound/a-records.conf:ro" >> $ymlname
					#echo -e "      - $rootdir/docker/$containername/srv-records.conf:/etc/unbound/srv-records.conf:ro" >> $ymlname
					#echo -e "      - $rootdir/docker/$containername/forward-records.conf:/etc/unbound/forward-records.conf:ro" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					#touch $rootdir/docker/$containername/unbound.conf
					#touch $rootdir/docker/$containername/a-records.conf
					#touch $rootdir/docker/$containername/srv-records.conf
					#touch $rootdir/docker/$containername/forward-records.conf

					#chown -R "$nonrootuser:$nonrootuser" $rootdir/docker/$containername
					chmod 777 -R $rootdir/docker/$containername

					#a-records.conf
					#srv-records.conf
					#forward-records.conf

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##################################################################################################################################

	##############################################################################################################################
	# VPNs

		##########################################################################################################################
		# VPN - IPSec/IKEv2

			# Increment this regardless of installation or repeat runs of this
			# script will lead to docker errors due to address already in use
			ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

			while true; do
				read -p $'\n'"Do you want to install/reinstall IPSec/IKEv2 (y/n)? " yn
				case $yn in
					[Yy]* ) 
						# https://github.com/hwdsl2/docker-ipsec-vpn-server

						# Create the docker-compose file
						containername=vpn-ipsec
						ymlname=$rootdir/$containername-compose.yml
						rndsubfolder=$(openssl rand -hex 15)
						ipsecpsk=$(openssl rand -hex 40)  # Pre-Shared Key (PSK)
						ipsecusrid=$(openssl rand -hex 40)
						ipsecpass=$(openssl rand -hex 40)
						sespw=$(openssl rand -hex 40)  # Server management password
						sehpw=$(openssl rand -hex 40)  # Hub management password
						# SoftEther ports - L2TP/IPSec ports
						ipsecl2tp1port1=500
						ipsecl2tp1port2=4500
						# SoftEther ports - SoftEther VPN
						sevpnport1=5555
						sevpnport2=992
						sesstpport=9347

						# Save variable to .bashrc for later persistent use
						export_variable "\n# VPN - IPSec/IKEv2"
						ipsecpsk=$(manage_variable "ipsecpsk" "$psecpsk  # SoftEther pre-shared key (PSK)")
						ipsecusrid=$(manage_variable "ipsecusrid" "$ipsecusrid # IPSec userid")
						ipsecpass=$(manage_variable "ipsecpass" "$ipsecpass  # IPSec password")

						# Commit the .bashrc changes
						source $rootdir/.bashrc

						# Remove any existing installation
						$(docker-compose -f $ymlname -p $stackname down -v)
						rm -rf $rootdir/docker/$containername

						mkdir -p $rootdir/docker/$containername
						mkdir -p $rootdir/docker/$containername/ikev2-vpn-data
						mkdir -p $rootdir/docker/$containername/lib
						mkdir -p $rootdir/docker/$containername/lib/modules

						rm -f $ymlname && touch $ymlname

						# Build the .yml file
						# Header (generic)
						echo -e "$ymlhdr" >> $ymlname
						echo -e "  $containername:" >> $ymlname
						echo -e "    container_name: $containername" >> $ymlname
						echo -e "    hostname: $containername" >> $ymlname
						# Docker image (user specified)
						echo -e "    hwdsl2/ipsec-vpn-server" >> $ymlname
						# Environmental variables (generic)
						echo -e "    $ymlenv" >> $ymlname
						# Additional environmental variables (user specified)
						echo -e "      - VPN_IPSEC_PSK=$ipsecpsk # Pre-Shared Key (PSK)" >> $ymlname
						echo -e "      - VPN_USER=$ipsecusrid" >> $ymlname
						echo -e "      - VPN_PASSWORD=$ipsecpass" >> $ymlname
						# Miscellaneous docker container parameters (user specified)
						echo -e "    privileged: true" >> $ymlname
						# Network specifications (user specified)
						echo -e "    networks:" >> $ymlname
						echo -e "      no-internet:" >> $ymlname
						echo -e "      internet:" >> $ymlname
						echo -e "        ipv4_address: $ipaddress" >> $ymlname
						# Ports specifications (user specified)
						echo -e "    ports:" >> $ymlname
						echo -e "      - $ipsecl2tp1port1:500/udp  # for L2TP/IPSec" >> $ymlname
						echo -e "      - $ipsecl2tp1port2:4500/tcp  # for L2TP/IPSec" >> $ymlname
						echo -e "      #- $sel2tp1port3:4500/udp  # for L2TP/IPSec" >> $ymlname
						echo -e "      #- $sevpnport1:5555/tcp  # for SoftEther VPN (recommended by vendor)." >> $ymlname
						echo -e "      #- $sevpnport2:992/tcp  # is also available as alternative." >> $ymlname
						echo -e "      #- $sesstpport:443/tcp # for SSTP" >> $ymlname
						# Restart policies (generic)
						echo -e "    $ymlrestart" >> $ymlname
						# Volumes (user specified)
						echo -e "    volumes:" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/ikev2-vpn-data:/etc/ipsec.d" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/ikev2-vpn-data/lib/modules:/lib/modules:ro" >> $ymlname
						echo -e "      # By default SoftEther has a very verbose logging system. For privacy or" >> $ymlname
						echo -e "      # space constraints, this may not be desirable. The easiest way to solve this" >> $ymlname
						echo -e "      # create a dummy volume to log to /dev/null. In your docker run you can" >> $ymlname
						echo -e "      # use the following volume variables to remove logs entirely." >> $ymlname
						echo -e "      #- /dev/null:/usr/vpnserver/server_log" >> $ymlname
						echo -e "      #- /dev/null:/usr/vpnserver/packet_log" >> $ymlname
						echo -e "      #- /dev/null:/usr/vpnserver/security_log" >> $ymlname
						# Networks, etc (generic)...
						echo -e "$ymlftr" >> $ymlname

						sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

						docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

						chmod 777 -R $rootdir/docker/$containername/ikev2-vpn-data/vpnclient.*

						# --env-file use for above to hide environmental variables from the portainer gui

						# Wait until the stack is first initialized...
						while [ -f "$(sudo docker ps | grep $containername)" ];
							do
								sleep 5
						done

						# Firewall rules
						iptables -A INPUT -p udp --dport 58211 -j ACCEPT
						iptables -A INPUT -p tcp --dport 58211 -j ACCEPT

						#iptables-save

						break;;
					[Nn]* ) break;;
					* ) echo -e "Please answer yes or no.";;
				esac
			done

		##########################################################################################################################

		##########################################################################################################################
		# VPN - OpenVPN Access Server

			# Not a docker container!

			# Increment this regardless of installation or repeat runs of this
			# script will lead to docker errors due to address already in use
			ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

			while true; do
				read -p $'\n'"Do you want to install/reinstall OpenVPN Access Server (y/n)? " yn
				case $yn in
					[Yy]* ) 
						# https://openvpn.net/vpn-software-packages/ubuntu/#install-from-repository
						# https://openvpn.net/vpn-server-resources/advanced-option-settings-on-the-command-line/
						# https://askubuntu.com/questions/1133903/where-is-openvpns-sacli - /usr/local/openvpn_as/scripts/sacli

						# Install some dependencies
						sudo apt update && sudo apt -y install -qq ca-certificates wget net-tools gnupg
						wget -qO - https://as-repository.openvpn.net/as-repo-public.gpg | sudo apt-key add -
						sudo echo -e "deb http://as-repository.openvpn.net/as/debian focal main">/etc/apt/sources.list.d/openvpn-as-repo.list

						# Install OpenVPN Access Server
						sudo apt update && sudo apt -y install -qq openvpn-as

						containername=openvpnas
						ymlname=$rootdir/$containername-compose.yml
						rndsubfolder=$(openssl rand -hex 15)
						sacliloc=/usr/local/openvpn_as/scripts/sacli
						ovpntcpport=26111
						ovpnudpport=21894
						ovpnuser=$(openssl rand -hex 8)
						ovpnpass=$(openssl rand -hex 32)
						ovpngroup=$(openssl rand -hex 8)

						# Save variable to .bashrc for later persistent use
						export_variable "\n# OpenVPN Access Server"
						sacliloc=$(manage_variable "sacliloc" "$sacliloc")
						ovpntcpport=$(manage_variable "ovpntcpport" "$ovpntcpport")
						ovpnudpport=$(manage_variable "ovpnudpport" "$ovpnudpport")
						ovpnuser=$(manage_variable "ovpnuser" "$ovpnuser")
						ovpnpass=$(manage_variable "ovpnpass" "$ovpnpass")
						ovpngroup=$(manage_variable "ovpngroup=" "$ovpngroup")

						# Commit the .bashrc changes
						source $rootdir/.bashrc

						# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
						destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
						cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

						sed -i 's/syncthing/'$containername'/g' $destconf
						# Set the $upstream_app parameter to the localhost address (127.0.0.1) so it can be accessed from docker (swag)
						sed -i 's/        set $upstream_app '$containername';/        set $upstream_app '$myip';/g' $destconf
						sed -i 's/    server_name '$containername'./    server_name '$ovpnsubdomain'./g' $destconf
						sed -i 's/    \#include \/config\/nginx\/authelia-server.conf;/    include \/config\/nginx\/authelia-server.conf;/g' $destconf
						sed -i 's/        \#include \/config\/nginx\/authelia-location.conf;/        include \/config\/nginx\/authelia-location.conf;/g' $destconf
						sed -i 's/    set $upstream_port 8384;/    set $upstream_port 943;/g' $destconf
						sed -i 's/        set $upstream_proto http;/        set $upstream_proto https;/g' $destconf

						# Set the openvpn tcp/upd ports - https://openvpn.net/vpn-server-resources/managing-user-and-group-properties-from-command-line/
						$sacliloc  --key "vpn.server.daemon.tcp.port" --value $ovpntcpport ConfigPut
						$sacliloc  --key "vpn.server.daemon.udp.port" --value $ovpnudpport ConfigPut

						# Create a new user and set the password for the user - https://openvpn.net/vpn-server-resources/managing-user-and-group-properties-from-command-line/
						$sacliloc --user $ovpnuser --key "type" --value "user_connect" UserPropPut
						$sacliloc --user $ovpnuser --new_pass=$ovpnpass SetLocalPassword

						# Create a group for the new user - not stricktly needed
						#$sacliloc --user $ovpngroup --key "type" --value "group" UserPropPut
						#$sacliloc --user $ovpngroup --key "group_declare" --value "true" UserPropPut
						#$sacliloc --user $ovpnuser --key "conn_group" --value "$ovpngroup" UserPropPut

						# Make it admin
						$sacliloc --user $ovpnuser --key "prop_superuser" --value "true" UserPropPut

						# Remove the defualt user (openvpn)
						$sacliloc --user openvpn --key "conn_group" UserPropDel
						$sacliloc --user openvpn UserPropDelAll

						# Set up a cron job to purge any logs that get created
						if ! [[ $(crontab -l | grep openvpnas.log) == *"openvpnas.log"* ]]
						then
							(crontab -l 2>/dev/null || true; echo -e "0 4 * * * /bin/rm /var/log/openvpnas.log.{15..1000} >/dev/null 2>&1") | crontab -
						fi

						# Restart the server
						$sacliloc start
						
						# Firewall rules
						# Block access to port 943 from the outside - traffic must go thhrough SWAG
						# Blackhole outside connection attempts to port 943 web interface
						iptables -t nat -A PREROUTING -i eth0 ! -s 127.0.0.1 -p tcp --dport 943 -j REDIRECT --to-port 0
						# Open VPN ports
						iptables -A INPUT -p udp --dport $ovpntcpport -j ACCEPT
						iptables -A INPUT -p udp --dport $ovpnudpport -j ACCEPT

						#iptables-save
						break;;
					[Nn]* ) break;;
					* ) echo -e "Please answer yes or no.";;
				esac
			done

		##########################################################################################################################

		##########################################################################################################################
		# VPN - Outline
		##########################################################################################################################

		##########################################################################################################################
		# VPN - Shadowsocks proxy

						# Increment this regardless of installation or repeat runs of this
						# script will lead to docker errors due to address already in use
						ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

			while true; do
				read -p $'\n'"Do you want to install/reinstall Shadowsocks proxy (y/n)? " yn
				case $yn in
					[Yy]* ) 
						while true; do
						read -rp $'\n'"Enter your desired shadowsocks password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " sspass
						if [[ -z "${sspass}" ]]; then
							echo -e "Enter your desired shadowsocks password or hit Ctrl+C to exit."
							continue
						fi
							break
						done

						# Create the docker-compose file
						containername=shadowsocks
						ymlname=$rootdir/$containername-compose.yml
						rndsubfolder=$(openssl rand -hex 15)
						shadowsockssubdirectory=$rndsubfolder

						# Remove any existing installation
						$(docker-compose -f $ymlname -p $stackname down -v)
						rm -rf $rootdir/docker/$containername

						mkdir -p $rootdir/docker/$containername;

						# Save variable to .bashrc for later persistent use
						export_variable "\n# Shadowsocks proxy"
						sspass=$(manage_variable "sspass" "$sspass  # Shadowsocks password" "-r")

						# Commit the .bashrc changes
						source $rootdir/.bashrc

						rm -f $ymlname && touch $ymlname

						# Build the .yml file
						# Header (generic)
						echo -e "$ymlhdr" >> $ymlname
						echo -e "  $containername:" >> $ymlname
						echo -e "    container_name: $containername" >> $ymlname
						echo -e "    hostname: $containername" >> $ymlname
						# Docker image (user specified)
						echo -e "    image: shadowsocks/shadowsocks-libev" >> $ymlname
						# Environmental variables (generic)
						echo -e "    $ymlenv" >> $ymlname
						# Additional environmental variables (user specified)
						echo -e "      - METHOD=aes-256-gcm" >> $ymlname
						echo -e "      - PASSWORD=$sspass" >> $ymlname
						echo -e "      - DNS_ADDRS=$piholeip # Comma delimited, need to use external to this vps or internal to docker" >> $ymlname
						# Miscellaneous docker container parameters (user specified)
						echo -e "    cap-add:" >> $ymlname # this is throwing an error??
						echo -e "      - NET_ADMIN" >> $ymlname
						# Network specifications (user specified)
						echo -e "    networks:" >> $ymlname
						echo -e "      no-internet:" >> $ymlname
						echo -e "      internet:" >> $ymlname
						echo -e "        ipv4_address: $ipaddress" >> $ymlname
						# Ports specifications (user specified)
						echo -e "    ports:" >> $ymlname
						echo -e "      - 58211:8388/tcp" >> $ymlname
						echo -e "      - 58211:8388/udp" >> $ymlname
						# Restart policies (generic)
						echo -e "    $ymlrestart" >> $ymlname
						# Volumes (user specified)
						# Networks, etc (generic)...
						echo -e "$ymlftr" >> $ymlname

						sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

						docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

						# Wait until the stack is first initialized...
						while [ -f "$(sudo docker ps | grep $containername)" ];
							do
								sleep 5
						done
						
						# Firewall rules
						iptables -A INPUT -p udp --dport 58211 -j ACCEPT
						iptables -A INPUT -p tcp --dport 58211 -j ACCEPT

						#iptables-save

						break;;
					[Nn]* ) break;;
					* ) echo -e "Please answer yes or no.";;
				esac
			done

		##########################################################################################################################

		##########################################################################################################################
		# VPN - STunnel
		##########################################################################################################################

		##########################################################################################################################
		# VPN - Softether VPN

			# Get download link from here:
			# https://www.softether-download.com/en.aspx
			# https://hub.docker.com/r/siomiz/softethervpn
			# https://hub.docker.com/r/fernandezcuesta/softethervpn

			# Increment this regardless of installation or repeat runs of this
			# script will lead to docker errors due to address already in use
			ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

			while true; do
				read -p $'\n'"Do you want to install/reinstall Softether VPN (y/n)? " yn
				case $yn in
					[Yy]* ) 
						wget https://github.com/SoftEtherVPN/SoftEtherVPN_Stable/releases/download/v4.38-9760-rtm/softether-vpnserver-v4.38-9760-rtm-2021.08.17-linux-arm64-64bit.tar.gz
						tar -xzsf $(ls -la | grep softether | awk '{print $9}')
						cd vpnserver
						tar -xzsf $(ls -la | grep softether | awk '{print $9}')

						# Create the docker-compose file
						containername=softether
						ymlname=$rootdir/$containername-compose.yml
						rndsubfolder=$(openssl rand -hex 15)
						sepsk=$(openssl rand -hex 40)  # Pre-Shared Key (PSK)
						seusrid=$(openssl rand -hex 40)
						sepass=$(openssl rand -hex 40)
						sespw=$(openssl rand -hex 40)  # Server management password
						sehpw=$(openssl rand -hex 40)  # Hub management password
						# SoftEther ports - L2TP/IPSec ports
						sel2tp1port1=500
						sel2tp1port2=1701
						sel2tp1port3=4500
						# SoftEther ports - SoftEther VPN
						sevpnport1=5555
						sevpnport2=992
						sesstpport=9347

						# Save variable to .bashrc for later persistent use
						export_variable "\n# Softether"
						sepsk=$(manage_variable "sepsk" "$sepsk  # SoftEther pre-shared key (PSK)")
						seusrid=$(manage_variable "seusrid" "$seusrid  # SoftEther userid")
						sepass=$(manage_variable "sepass" "$sepass  # SoftEther password")
						sespw=$(manage_variable "sespw" "$sespw  # Server management password")
						sehpw=$(manage_variable "sehpw" "$sehpw  # Hub management password")

						# Commit the .bashrc changes
						source $rootdir/.bashrc

						# Remove any existing installation
						$(docker-compose -f $ymlname -p $stackname down -v)
						rm -rf $rootdir/docker/$containername

						mkdir -p $rootdir/docker/$containername
						mkdir -p $rootdir/docker/$containername/vpnserver

						# Obtain a a config file template
						docker run --name vpnconf -e SPW=$sespw -e HPW=$sehpw siomiz/softethervpn echo
						docker cp vpnconf:/usr/vpnserver/vpn_server.config $rootdir/docker/$containername/vpnserver/vpn_server.config
						docker rm vpnconf

						rm -f $ymlname && touch $ymlname

						# Build the .yml file
						# Header (generic)
						echo -e "$ymlhdr" >> $ymlname
						echo -e "  $containername:" >> $ymlname
						echo -e "    container_name: $containername" >> $ymlname
						echo -e "    hostname: $containername" >> $ymlname
						# Docker image (user specified)
						echo -e "    image: siomiz/softethervpn" >> $ymlname
						# Environmental variables (generic)
						echo -e "    $ymlenv" >> $ymlname
						echo -e "      # Additional environmental variables (user specified)" >> $ymlname
						echo -e "      - PSK=$sepsk  # Pre-Shared Key (PSK), if not set: "notasecret" (without quotes) by default." >> $ymlname
						echo -e "      # Multiple usernames and passwords may be set with the following pattern:" >> $ymlname
						echo -e "      # username:password;user2:pass2;user3:pass3. Username and passwords" >> $ymlname
						echo -e "      # are separated by :. Each pair of username:password should be separated" >> $ymlname
						echo -e "      # by ;. If not set a single user account with a random username " >> $ymlname
						echo -e "      # ("user[nnnn]") and a random weak password is created." >> $ymlname
						echo -e "      - USERNAME=$seusrid" >> $ymlname
						echo -e "      - PASSWORD=$sepass" >> $ymlname
						echo -e "      #- USERS=$seusrid:$sepass" >> $ymlname
						echo -e "      - SPW=$sespw  # Server management password. :warning:" >> $ymlname
						echo -e "      - HPW=$sehpw  # 'DEFAULT' hub management password. :warning:" >> $ymlname
						echo -e "      - L2TP_ENABLED=true  # Disabled by default" >> $ymlname
						echo -e "      - OPENVPN_ENABLED=false  # Disabled by default" >> $ymlname
						echo -e "      - SSTP_ENABLED=true  # Disabled by default" >> $ymlname
						# Miscellaneous docker container parameters (user specified)
						echo -e "    cap_add:" >> $ymlname
						echo -e "      - NET_ADMIN" >> $ymlname
						# Network specifications (user specified)
						echo -e "    networks:" >> $ymlname
						echo -e "      no-internet:" >> $ymlname
						echo -e "      internet:" >> $ymlname
						echo -e "        ipv4_address: $ipaddress" >> $ymlname
						# Ports specifications (user specified)
						echo -e "    ports:" >> $ymlname
						echo -e "      - $sel2tp1port1:500/udp  # for L2TP/IPSec" >> $ymlname
						echo -e "      - $sel2tp1port2:1701/tcp  # for L2TP/IPSec" >> $ymlname
						echo -e "      - $sel2tp1port3:4500/udp  # for L2TP/IPSec" >> $ymlname
						echo -e "      - $sevpnport1:5555/tcp  # for SoftEther VPN (recommended by vendor)." >> $ymlname
						echo -e "      - $sevpnport2:992/tcp  # is also available as alternative." >> $ymlname
						echo -e "      - $sesstpport:443/tcp # for SSTP" >> $ymlname
						# Restart policies (generic)
						echo -e "    $ymlrestart" >> $ymlname
						# Volumes (user specified)
						echo -e "    volumes:" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/vpnserver:/usr/vpnserver  # vpn_server.config" >> $ymlname
						echo -e "      # By default SoftEther has a very verbose logging system. For privacy or" >> $ymlname
						echo -e "      # space constraints, this may not be desirable. The easiest way to solve this" >> $ymlname
						echo -e "      # create a dummy volume to log to /dev/null. In your docker run you can" >> $ymlname
						echo -e "      # use the following volume variables to remove logs entirely." >> $ymlname
						echo -e "      - $rootdir/docker/$containername/vpnserver/vpn_server.config:/usr/vpnserver/vpn_server.config" >> $ymlname
						echo -e "      - /dev/null:/usr/vpnserver/server_log" >> $ymlname
						echo -e "      - /dev/null:/usr/vpnserver/packet_log" >> $ymlname
						echo -e "      - /dev/null:/usr/vpnserver/security_log" >> $ymlname
						# Networks, etc (generic)...
						echo -e "$ymlftr" >> $ymlname

						docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

						# --env-file use for above to hide environmental variables from the portainer gui

						# Wait until the stack is first initialized...
						while [ -f "$(sudo docker ps | grep $containername)" ];
							do
								sleep 5
						done
					
						# Firewall rules
						iptables -A INPUT -p udp --dport 58211 -j ACCEPT
						iptables -A INPUT -p tcp --dport 58211 -j ACCEPT

						#iptables-save

						break;;
					[Nn]* ) break;;
					* ) echo -e "Please answer yes or no.";;
				esac
			done	
	
		##########################################################################################################################

		##########################################################################################################################
		# VPN - Wireguard

			# Increment this regardless of installation or repeat runs of this
			# script will lead to docker errors due to address already in use
			ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

			while true; do
				read -p $'\n'"Do you want to install/reinstall Wireguard (y/n)? " yn
				case $yn in
					[Yy]* ) 
						# Create the docker-compose file
						containername=wireguard
						ymlname=$rootdir/$containername-compose.yml
						rndsubfolder=$(openssl rand -hex 15)
						wgport=50220

						# Save variable to .bashrc for later persistent use
						export_variable "\n# Wireguard"
						mwgport=$(manage_variable "mwgport" "$wgport  # Wireguard port")

						# Commit the .bashrc changes
						source $rootdir/.bashrc

						# Remove any existing installation
						$(docker-compose -f $ymlname -p $stackname down -v)
						rm -rf $rootdir/docker/$containername

						mkdir -p $rootdir/docker/$containername;
						mkdir -p $rootdir/docker/$containername/config;
						mkdir -p $rootdir/docker/$containername/modules;

						rm -f $ymlname && touch $ymlname

						# Build the .yml file
						# Header (generic)
						echo -e "$ymlhdr" >> $ymlname
						echo -e "  $containername:" >> $ymlname
						echo -e "    container_name: $containername" >> $ymlname
						echo -e "    hostname: $containername" >> $ymlname
						# Docker image (user specified)
						echo -e "    image: ghcr.io/linuxserver/wireguard" >> $ymlname
						# Environmental variables (generic)
						echo -e "    $ymlenv" >> $ymlname
						echo -e "      - SERVERURL=$fqdn" >> $ymlname
						echo -e "      - SERVERPORT=$wgport" >> $ymlname
						echo -e "      - PEERS=3" >> $ymlname
						echo -e "      - PEERDNS=$piholeip  # Need to use external to this vps or internal docker dns (pihole)" >> $ymlname
						echo -e "      - INTERNAL_SUBNET=$ipaddress" >> $ymlname
						echo -e "      - ALLOWEDIPS=0.0.0.0/0" >> $ymlname
						# Miscellaneous docker container parameters (user specified)
						echo -e "    cap_add:" >> $ymlname
						echo -e "      - NET_ADMIN" >> $ymlname
						echo -e "      - SYS_MODULE" >> $ymlname
						echo -e "    sysctls:" >> $ymlname
						echo -e "      - net.ipv4.conf.all.src_valid_mark=1" >> $ymlname
						# Network specifications (user specified)
						echo -e "    networks:" >> $ymlname
						echo -e "      no-internet:" >> $ymlname
						echo -e "      internet:" >> $ymlname
						echo -e "        ipv4_address: $ipaddress" >> $ymlname
						# Ports specifications (user specified)
						echo -e "    ports:" >> $ymlname
						echo -e "      - 50220:51820/udp # Internal port must stay as 51820!" >> $ymlname
						# Restart policies (generic)
						echo -e "    $ymlrestart" >> $ymlname
						# Volumes (user specified)
						echo -e "    volumes:" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/config:/config" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/modules:/lib/modules" >> $ymlname
						# Networks, etc (generic)...
						echo -e "$ymlftr" >> $ymlname

						sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

						docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

						# Wait until the stack is first initialized...
						while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
						done

						# Firewall rules
						iptables -A INPUT -p tcp --dport $wgport -j ACCEPT
						iptables -A OUTPUT -p tcp --dport $wgport -j ACCEPT
						iptables -A INPUT -p udp --dport $wgport -j ACCEPT
						iptables -A OUTPUT -p udp --dport $wgport -j ACCEPT

						#iptables-save

						break;;
					[Nn]* ) break;;
					* ) echo -e "Please answer yes or no.";;
				esac
			done	

		##########################################################################################################################

		##########################################################################################################################
		# VPN - Wireguard GUI - will not run on a subfolder!

			# Increment this regardless of installation or repeat runs of this
			# script will lead to docker errors due to address already in use
			ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

			while true; do
				read -p $'\n'"Do you want to install/reinstall Wireguard GUI (y/n)? " yn
				case $yn in
					[Yy]* ) 
						while true; do
						read -rp $'\n'"Enter your desired wireguard ui userid - example - 'mynewuser' or (better) 'Fkr5HZH4Rv': " wguid
						if [[ -z "${wguid}" ]]; then
							echo -e "Enter your desired wireguard ui userid or hit Ctrl+C to exit."
							continue
						fi
						break
						done

						while true; do
						read -rp $'\n'"Enter your desired wireguard ui password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " wgpass
						if [[ -z "${wgpass}" ]]; then
							echo -e "Enter your desired wireguard ui password or hit Ctrl+C to exit."
							continue
						fi
						break
						done

						containername=wgui
						ymlname=$rootdir/$containername-compose.yml
						rndsubfolder=$(openssl rand -hex 15)
						wguisubdirectory=$rndsubfolder

						# Save variable to .bashrc for later persistent use
						export_variable "\n# Wireguard UI"
						wguid=$(manage_variable "wguid" "$wguid" "-r")
						wgpass=$(manage_variable "wgpass" "$wgpass" "-r")

						# Commit the .bashrc changes
						source $rootdir/.bashrc

						# Remove any existing installation
						$(docker-compose -f $ymlname -p $stackname down -v)
						rm -rf $rootdir/docker/$containername

						mkdir -p $rootdir/docker/$containername;
						mkdir -p $rootdir/docker/$containername/app;
						mkdir -p $rootdir/docker/$containername/etc;

						rm -f $ymlname && touch $ymlname

						# Build the .yml file
						# Header (generic)
						echo -e "$ymlhdr" >> $ymlname
						echo -e "  $containername:" >> $ymlname
						echo -e "    container_name: $containername" >> $ymlname
						echo -e "    hostname: $containername" >> $ymlname
						# Docker image (user specified)
						echo -e "    image: ngoduykhanh/wireguard-ui:latest" >> $ymlname
						# Environmental variables (generic)
						echo -e "    $ymlenv" >> $ymlname
						echo -e "      #- SENDGRID_API_KEY" >> $ymlname
						echo -e "      #- EMAIL_FROM_ADDRESS" >> $ymlname
						echo -e "      #- EMAIL_FROM_NAME" >> $ymlname
						echo -e "      - SESSION_SECRET=$(openssl rand -hex 30)" >> $ymlname
						echo -e "      - WGUI_USERNAME=$wguid" >> $ymlname
						echo -e "      - WGUI_PASSWORD=$wgpass" >> $ymlname
						# Miscellaneous docker container parameters (user specified)
						echo -e "    #cap_add:" >> $ymlname
						echo -e "      #- NET_ADMIN" >> $ymlname
						echo -e "    driver: json-file" >> $ymlname
						echo -e "    logging:" >> $ymlname
						echo -e "    #network_mode: host" >> $ymlname
						echo -e "    options:" >> $ymlname
						echo -e "      max-size: 50m" >> $ymlname
						# Network specifications (user specified)
						echo -e "    networks:" >> $ymlname
						echo -e "      no-internet:" >> $ymlname
						echo -e "      internet:" >> $ymlname
						echo -e "        ipv4_address: $ipaddress" >> $ymlname
						# Ports specifications (user specified)
						echo -e "    #ports:" >> $ymlname
						echo -e "      #- 5000:5000" >> $ymlname
						# Restart policies (generic)
						echo -e "    $ymlrestart" >> $ymlname
						# Volumes (user specified)
						echo -e "    volumes:" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/app:/app/db" >> $ymlname
						echo -e "      - $rootdir/docker/$containername/config:/etc/wireguard" >> $ymlname
						echo -e "      #- $rootdir/docker/$containername/etc:/etc/wireguard" >> $ymlname
						# Networks, etc (generic)...
						echo -e "$ymlftr" >> $ymlname

						echo -e "$ymlhdr
						$containername:
							container_name: $containername
							hostname: $containername
							image: ngoduykhanh/wireguard-ui:latest
							#cap_add:
								#- NET_ADMIN
							driver: json-file
							$ymlenv
								#- SENDGRID_API_KEY
								#- EMAIL_FROM_ADDRESS
								#- EMAIL_FROM_NAME
								- SESSION_SECRET=$(openssl rand -hex 30)
								- WGUI_USERNAME=$wguid
								- WGUI_PASSWORD=$wgpass
							logging:
							#network_mode: host
							networks:
								no-internet:
								internet:
									ipv4_address: $ipaddress
							options:
								max-size: 50m
							# Port 5000
							$ymlrestart
							volumes:
								- $rootdir/docker/$containername/app:/app/db
								- $rootdir/docker/$containername/config:/etc/wireguard
								#- $rootdir/docker/$containername/etc:/etc/wireguard" >> $ymlname
						echo -e "$ymlftr" >> $ymlname

						sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

						docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

						# Wait until the stack is first initialized...
						while [ -f "$(sudo docker ps | grep $containername)" ];
							do
								sleep 5
						done

						# Prepare the proxy-conf file using syncthing.subdomain.conf.sample as a template
						destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
						cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

						sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
						sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
						sed -i 's/syncthing/'$containername'/g' $destconf
						sed -i 's/    server_name '$containername'./    server_name '$wgsubdomain'./g' $destconf
						sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;/g' $destconf

						dest=$rootdir/docker/$containername/app/server
						# Make a few alterations to the core config files
						sed -i 's/\"1.1.1.1\"/\"'$myip'\"/g' $dest/global_settings.json
						sed -i 's/\"mtu\": \"1450\"/\"mtu\": \"1500\"/g' $dest/global_settings.json
						sed -i 's/\"10.252.1.0\/24\"/\"'$dockersubnet'\/24\"/g' $dest/interfaces.json
						sed -i 's/\"listen_port\": \"51820\"/\"listen_port\": \"'$wgport'\"/g' $dest/interfaces.json
					
						# Firewall rules
						# None needed
						# #iptables-save

						break;;
					[Nn]* ) break;;
					* ) echo -e "Please answer yes or no.";;
				esac
			done	
		##########################################################################################################################

	##############################################################################################################################

	##############################################################################################################################
	# Whoogle - will not run on a subfolder!

		# Increment this regardless of installation or repeat runs of this
		# script will lead to docker errors due to address already in use
		ipend=$(($ipend+$ipincr)) && ipaddress=$subnet.$ipend

        while true; do
            read -p $'\n'"Do you want to install/reinstall Whoogle (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Create the docker-compose file
					containername=whoogle
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)
					# Change mylink to your own farside domain if you have one
					# or consider making it farside.link
					mylink=farside.link # $whglsubdomain'.'$fqdn

					# Save variable to .bashrc for later persistent use
					export_variable "\n# Whoogle"
					mylink=$(manage_variable "mylink" "$mylink" "-r")

					# Commit the .bashrc changes
					source $rootdir/.bashrc

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/whoogle-search
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername

					# Whoogle - https://hub.docker.com/r/benbusby/whoogle-search#g-manual-docker
					# Install dependencies
					sudo apt-get -qq update && sudo apt-get install -y -qq libcurl4-openssl-dev libssl-dev
					git clone https://github.com/benbusby/whoogle-search

					# Move the contents from directory whoogle-search to directory whoogle
					cd $rootdir/whoogle-search

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: benbusby/whoogle-search" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      # Basic auth configuration, uncomment to enable" >> $ymlname
					echo -e "      #- WHOOGLE_USER=<auth username>" >> $ymlname
					echo -e "      #- WHOOGLE_PASS=<auth password>" >> $ymlname
					echo -e "      # Proxy configuration, uncomment to enable" >> $ymlname
					echo -e "      #- WHOOGLE_PROXY_USER=<proxy username>" >> $ymlname
					echo -e "      #- WHOOGLE_PROXY_PASS=<proxy password>" >> $ymlname
					echo -e "      #- WHOOGLE_PROXY_TYPE=<proxy type (http|https|socks4|socks5)" >> $ymlname
					echo -e "      #- WHOOGLE_PROXY_LOC=<proxy host/ip>" >> $ymlname
					echo -e "      # See the subfolder /static/settings folder for .json files with options on country and language" >> $ymlname
					echo -e "      - WHOOGLE_CONFIG_COUNTRY=US" >> $ymlname
					echo -e "      - WHOOGLE_CONFIG_LANGUAGE=lang_en" >> $ymlname
					echo -e "      - WHOOGLE_CONFIG_SEARCH_LANGUAGE=lang_en" >> $ymlname
					echo -e "      - EXPOSE_PORT=5000" >> $ymlname
					echo -e "      # Site alternative configurations, uncomment to enable" >> $ymlname
					echo -e "      # Note: If not set, the feature will still be available" >> $ymlname
					echo -e "      # with default values." >> $ymlname
					echo -e "      - WHOOGLE_ALT_TW=$mylink/nitter" >> $ymlname
					echo -e "      - WHOOGLE_ALT_YT=$mylink/invidious" >> $ymlname
					echo -e "      - WHOOGLE_ALT_IG=$mylink/bibliogram/u" >> $ymlname
					echo -e "      - WHOOGLE_ALT_RD=$mylink/libreddit" >> $ymlname
					echo -e "      - WHOOGLE_ALT_MD=$mylink/scribe" >> $ymlname
					echo -e "      - WHOOGLE_ALT_TL=lingva.ml" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    cap_drop:" >> $ymlname
					echo -e "      - ALL" >> $ymlname
					echo -e "    #env_file: # Alternatively, load variables from whoogle.env" >> $ymlname
					echo -e "      #- whoogle.env" >> $ymlname
					echo -e "    mem_limit: 256mb" >> $ymlname
					echo -e "    memswap_limit: 256mb" >> $ymlname
					echo -e "    pids_limit: 50" >> $ymlname
					echo -e "    security_opt:" >> $ymlname
					echo -e "      - no-new-privileges" >> $ymlname
					echo -e "    #tmpfs:" >> $ymlname
					echo -e "      #- /config/:size=10M,uid=102,gid=102,mode=1700" >> $ymlname
					echo -e "      #- /var/lib/tor/:size=10M,uid=102,gid=102,mode=1700" >> $ymlname
					echo -e "      #- /run/tor/:size=1M,uid=102,gid=102,mode=1700" >> $ymlname
					echo -e "    #user: '102' # user debian-tor from tor package" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- xxx.xxx.xxx.xxx server external to this machine (e.x. 8.8.8.8, 1.1.1.1)" >> $ymlname
					echo -e "      # If you are running pihole in a docker container, point archivebox to the pihole" >> $ymlname
					echo -e "      # docker container ip address.  Probably best to set a static ip address for" >> $ymlname
					echo -e "      # the pihole in the configuration so that it will never change." >> $ymlname
					echo -e "      - $piholeip" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        ipv4_address: $ipaddress" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 5000:5000" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
                    destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subdomain.conf
                    cp $rootdir/docker/$swagloc/nginx/proxy-confs/syncthing.subdomain.conf.sample $destconf

					chown "$nonrootuser:$nonrootuser" $destconf

					sed -i 's/\#include \/config\/nginx\/authelia-server.conf;/include \/config\/nginx\/authelia-server.conf;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/syncthing/'$containername'/g' $destconf
					sed -i 's/    server_name '$containername'./    server_name '$whglsubdomain'./g' $destconf
					sed -i 's/        set $upstream_app '$containername';/        set $upstream_app '$ipaddress';/g' $destconf
					sed -i 's/    set $upstream_port 8384;/    set $upstream_port 5000;/g' $destconf

					# Back to rootdir and clean up
					cp $ymlname $rootdir/$ymlname
					cd $rootdir
					rm -rf $rootdir/whoogle-search

					# Firewall rules
					# None needed
					# #iptables-save

                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

	##############################################################################################################################

	##############################################################################################################################
	# Pihole - do this last or it may interrupt your installs due to blacklisting

		# Pihole ip address set in the Global Variables section near the beginning
		# of this script.

        while true; do
            read -p $'\n'"Do you want to install/reinstall Pihole (y/n)? " yn
            case $yn in
                [Yy]* ) 
					# Needed if you are going to run pihole
					#   Reference - https://www.geeksforgeeks.org/create-your-own-secure-home-network-using-pi-hole-and-docker/
					#   Reference - https://www.shellhacks.com/setup-dns-resolution-resolvconf-example/
					#   Reference - https://docs.pi-hole.net/regex/pi-hole/ (how to block AAAA record lookups)
					# Cloudflared - https://docs.pi-hole.net/guides/dns/cloudflared/
					# PiHold DoH DoT - https://libreddit.dcs0.hu/r/pihole/comments/gljrg2/pihole_with_doh_and_dot/
					# Unbound DoH DoT - https://docs.pi-hole.net/guides/dns/unbound/
					# Set webgui timeout - https://www.reddit.com/r/pihole/comments/dckr5i/web_logout_setting/
					#                      https://discourse.pi-hole.net/t/persistent-login-to-pi-hole-admin-page/9225/3
					#                      https://stackoverflow.com/questions/8311320/how-to-change-the-session-timeout-in-php

					sudo systemctl stop systemd-resolved.service
					sudo systemctl disable systemd-resolved.service
					sed -i 's/nameserver 127.0.0.53/nameserver 9.9.9.9/g' /etc/resolv.conf # We will change this later after the pihole is set up
					# sudo lsof -i -P -n | grep LISTEN - allows you to find out who is listening on a port
					# sudo apt-get install net-tools
					# sudo netstat -tulpn | grep ":53 " - port 53

					while true; do
					read -rp $'\n'"Enter your desired pihole webgui password - example - 'wWDmJTkPzx5zhxcWpQ3b2HvyBbxgDYK5jd2KBRvw': " pipass
					if [[ -z "${pipass}" ]]; then
						echo -e "Enter your desired pihole webgui password or hit Ctrl+C to exit."
						continue
					fi
					break
					done

					# Create the docker-compose file
					containername=pihole
					ymlname=$rootdir/$containername-compose.yml
					rndsubfolder=$(openssl rand -hex 15)

					# Save variable to .bashrc for later persistent use
					export_variable "\n# Pihole Admin"
					piholeip=$(manage_variable "piholeip" "$piholeip")
					pipass=$(manage_variable "pipass" "$pipass" "-r")

					# Commit the .bashrc changes
					source $rootdir/.bashrc

					# Remove any existing installation
					$(docker-compose -f $ymlname -p $stackname down -v)
					rm -rf $rootdir/docker/$containername

					mkdir -p $rootdir/docker/$containername;
					mkdir -p $rootdir/docker/$containername/etc-pihole;
					mkdir -p $rootdir/docker/$containername/etc-dnsmasq.d;

					rm -f $ymlname && touch $ymlname

					# Build the .yml file
					# Header (generic)
					echo -e "$ymlhdr" >> $ymlname
					echo -e "  $containername:" >> $ymlname
					echo -e "    container_name: $containername" >> $ymlname
					echo -e "    hostname: $containername" >> $ymlname
					# Docker image (user specified)
					echo -e "    image: pihole/pihole:latest" >> $ymlname
					# Environmental variables (generic)
					echo -e "    $ymlenv" >> $ymlname
					# Additional environmental variables (user specified)
					echo -e "      - WEBPASSWORD=$pipass" >> $ymlname
					echo -e "      - SERVERIP=$myip" >> $ymlname
					echo -e "      - IPv6=False" >> $ymlname
					# Miscellaneous docker container parameters (user specified)
					echo -e "    cap_add:" >> $ymlname
					echo -e "      - NET_ADMIN" >> $ymlname
					echo -e "    dns:" >> $ymlname
					echo -e "      #- 127.0.0.1" >> $ymlname
					echo -e "      - 9.9.9.9" >> $ymlname
					# Network specifications (user specified)
					echo -e "    networks:" >> $ymlname
					echo -e "      no-internet:  # Required to access the web gui" >> $ymlname
					echo -e "      internet:" >> $ymlname
					echo -e "        # Set a static ip address for the pihole" >> $ymlname
					echo -e "        # https://www.cloudsavvyit.com/14508/how-to-assign-a-static-ip-to-a-docker-container/" >> $ymlname
					echo -e "        ipv4_address: $piholeip" >> $ymlname
					# Ports specifications (user specified)
					echo -e "    #ports:" >> $ymlname
					echo -e "      #- 53:53/udp  # Disable these if using DNS over HTTPS (DoH) server" >> $ymlname
					echo -e "      #- 53:53/tcp  # Disable these if using DNS over HTTPS (DoH) server" >> $ymlname
					echo -e "      #- 67:67/tcp  # Disable these if using DNS over HTTPS (DoH) server" >> $ymlname
					echo -e "      #- 8080:80/tcp # WebApp port, don't publish this to the outside world - only proxy through swag/authelia" >> $ymlname
					echo -e "      #- 8443:443/tcp # WebApp port, don't publish this to the outside world - only proxy through swag/authelia" >> $ymlname
					# Restart policies (generic)
					echo -e "    $ymlrestart" >> $ymlname
					# Volumes (user specified)
					echo -e "    volumes:" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/etc-pihole:/etc/pihole" >> $ymlname
					echo -e "      - $rootdir/docker/$containername/etc-dnsmasq.d:/etc/dnsmasq.d" >> $ymlname
					# Networks, etc (generic)...
					echo -e "$ymlftr" >> $ymlname

					sleep 5 && chown "$nonrootuser:$nonrootuser" $ymlname

					docker-compose --log-level ERROR -f $ymlname -p $stackname up -d

					# Wait until the stack is first initialized...
					while [ -f "$(sudo docker ps | grep $containername)" ];
						do
							sleep 5
					done

					# Prepare the proxy-conf file using syncthing.subfolder.conf as a template
					destconf=$rootdir/docker/$swagloc/nginx/proxy-confs/$containername.subfolder.conf
					cp $rootdir/docker/$swagloc/nginx/proxy-confs/pihole.subfolder.conf.sample $destconf

					sed -i 's/    return 301 $scheme:\/\/$host\/pihole\/;/    return 301 $scheme:\/\/$host\/pihole\/admin;/g' $destconf
					sed -i 's/\#include \/config\/nginx\/authelia-location.conf;/include \/config\/nginx\/authelia-location.conf;/g' $destconf
					sed -i 's/\    return 301 \$scheme:\/\/$host\/pihole\/;/    return 301 \$scheme:\/\/$host\/pihole\/admin;/g' $destconf

					# Ensure ownership of the 'etc-pihole' folder is set properly.
					chown systemd-coredump:systemd-coredump $rootdir/docker/$containername/etc-pihole
					# This below step may not be needed.  Need to deploy to a server and check
					# Allow syncthing to write to the 'etc-pihole' directory so it can sync properly
					#chmod 777 $rootdir/docker/pihole/etc-pihole

					# Restart SWAG to propogate the changes to proxy-confs
					echo -e "Restarting SWAG..."
					$(docker-compose -f $swagymlname -p $stackname down) > /dev/null 2>&1 && $(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1
					$(docker-compose --log-level ERROR -f $swagymlname -p $stackname up -d) > /dev/null 2>&1

					# Add a cron job to reset the permissions of the pihole directory if any changes are made - checks once per minute
					# Don't put ' around the commmand!  And, it must be run as root!
					if ! [[ $(crontab -l | grep etc-pihole) == *"etc-pihole"* ]]
                    then
						(crontab -l 2>/dev/null || true; echo -e "* * * * * chmod 777 -R $rootdir/docker/$containername/etc-pihole") | crontab -
					fi

					# Route all traffic including localhost traffic through the pihole
					# https://www.tecmint.com/find-my-dns-server-ip-address-in-linux/
					# https://kifarunix.com/make-permanent-dns-changes-on-resolv-conf-in-linux/
					# apt install resolvconf
					# sed -i 's/nameserver 9.9.9.9/nameserver '$piholeip'/g' /etc/resolv.conf - not persistent
					rm -rf /etc/resolvconf/resolv.conf.d/base && touch /etc/resolvconf/resolv.conf.d/base
					echo "nameserver $piholeip" >> /etc/resolvconf/resolv.conf.d/base
					resolvconf -u


					# https://robinwinslow.uk/fix-docker-networking-dns
					# Route all docker traffic through the pihole DNS
					#rm -rf /etc/docker/daemon.json && touch /etc/docker/daemon.json

					# Force all docker traffic through the pihole
					#echo -e "{" >> /etc/docker/daemon.json
   				 	#echo -e '	dns": ["'$piholeip'"]' >> /etc/docker/daemon.json
					#echo -e "}" >> /etc/docker/daemon.json

					#service docker restart

					# You can check who is providing name servies using the below
					# docker run busybox nslookup google.com
					# nslookup google.com

					# Firewall rules
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

					# Specific requests to block dns requests by name.  The number (02, 08, 09) represents the count of characters
					# before the string.
					# |Type | Code| |------------| |Any | 00ff| |A | 0011| |CNAME | 0005| |MX | 000f| |AAAA | 001c| |NS | 0002| |SOA | 0006|
					iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|02|sl|00|" --algo bm -j DROP -m comment --comment 'sl'
					iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|09|peacecorp|03|org" --algo bm -j DROP -m comment --comment 'peacecorp.org'
					iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|08|pizzaseo|03|com" --algo bm -j DROP -m comment --comment 'pizzaseo.com'
					iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|07|version|04|bind|0000ff|" --algo bm -j DROP -m comment --comment 'version.bind'
					iptables -I INPUT -i eth0 -p udp -m udp --dport 53 -m string --hex-string "|05|xerox|03|com" --algo bm -j DROP -m comment --comment 'xerox.com'

					#iptables-save

					# You will need to bootstrap up the pihole sync by adding other 
					# devices which can be done through the syncthing gui.
					# Please make sure that your pihole database is updated to the
					# latest version through the pihole gui first, or the 'new'
					# version of the pihole database on this instance will overwrite
					# your other devices database and you will loses your configuration.
					#   Go to Settings>Teleporter in the pihole gui of an existing
					#   syncronizing node
					#   Perform a backup to your local machine
					#   Go to Settings>Teleporter in the pihole gui on the new node
					#   and restore the backup configuration file from the existing
					#   syncronizing node.
					#   After that is complete, go to Settings>DNS and select
					#   your DNS providers (maybe not Google, maybe Level3, Comodo
					#   Quad9).  After that, under advanced (also on the DNS tab)
					#   select 'Never forward non-FQDN A and AAAA queries' and 
					#   'Never forward reverse lookups for private IP ranges' followed
					#   by clicking 'Save' at the lower right of the page.
					# You should now have an up and running pihole.



                    break;;
                [Nn]* ) break;;
                * ) echo -e "Please answer yes or no.";;
            esac
        done

		##################################################################################################################################
		# Seal a recently (Jan-2022) revealead vulnerabilty
		#   https://arstechnica.com/information-technology/2022/01/a-bug-lurking-for-12-years-gives-attackers-root-on-every-major-linux-distro/

		chmod 0755 /usr/bin/pkexec
	##############################################################################################################################
	
##################################################################################################################################

##################################################################################################################################
# Save firewall changes

	iptables-save > /dev/null 2>&1

##################################################################################################################################

##################################################################################################################################
# Finalize

	echo -e "
	Cleaning up and restarting the stack for the final time...
	"

	# Need to restart the stack - will commit changes to swag *.conf files
	docker restart $(sudo docker ps -a | grep $stackname | awk '{ print$1 }')

##################################################################################################################################

##################################################################################################################################
# Closeout

	echo -e "
	Keep these in a safe place for future reference:

	==========================================================================================================
	Fully qualified domain name (FQDN): $fqdn
	Subdomains:                         $subdomains
	Authelia userid:                    $authusr
	Authelia password:                  $authpwd
	Neko user password:                 $nekoupass
	Neko admin password:                $nekoapass
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
	# This last part about cat'ing out the url is there beacuase I was unable to get email authentication working

##################################################################################################################################
