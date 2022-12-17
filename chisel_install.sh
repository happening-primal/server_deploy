#!/bin/bash

# This script will install chisel (a fast TCP/UDP tunnel, transported over HTTP, secured via SSH).
# Instalation options include client, server, or client/server and includes the option to
# run chisel as a linux sservice.  Tested on Ubuntu 20.

# References:
# https://gosamples.dev/check-go-version/
# https://farside.link/scribe/geekculture/chisel-network-tunneling-on-steroids-a28e6273c683
# https://github.com/jpillora/chisel
# https://0xdf.gitlab.io/2020/08/10/tunneling-with-chisel-and-ssf-update.html)

# Prerun
# Make sure go language is intalled
sudo apt update && sudo apt -y install golang-go telnet && sudo apt -y upgrade

# Variable declarations
startdir=$(pwd)
chiseldir="/etc/chisel"
chiselsericename="chisel"
servicefolder="/lib/systemd/system"
chiselservicescript="chisel_keepalive.sh"
myip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
nonrootuser=$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')
rootdir=/home/$nonrootuser

# Allow the service script to be run at boot time without a password
# Check if the directive already exists and if not, add it
sudocheck=$(sudo cat /etc/sudoers | grep "ALL ALL=NOPASSWD: $chiseldir")

if [[ -z "${sudocheck}" ]]; then
    sudo rm -f /etc/sudoers.tmp
    sudo touch /etc/sudoers.tmp
    sudo chmod 777 /etc/sudoers.tmp
    sudo cat /etc/sudoers >> /etc/sudoers.tmp
    sudo echo -e "ALL ALL=NOPASSWD: $chiseldir/chisel" >> /etc/sudoers.tmp
    checksudo=$(sudo visudo -c -f /etc/sudoers.tmp | grep sudoers.tmp | awk '{print $3}')
    if [ $checksudo=="OK" ]; then
        sudo chmod 0440 /etc/sudoers.tmp
        sudo cp /etc/sudoers.tmp /etc/sudoers
    fi
    sudo rm -f /etc/sudoers.tmp
fi

# Check for previous installs and remove as necessary

# Chisel service
if test -f "$servicefolder/$chiselsericename.service"; then
    # Service file exists
    echo "Removing exising service '$chiselsericename'..."
    sudo systemctl stop $chiselsericename
    sudo systemctl disable $chiselsericename
    sudo rm -f "$servicefolder/$chiselsericename.service"
fi

# Chisel itself
if test -d "$chiseldir"; then
    # Directory exists
    echo "Removing existing directory '$chiseldir'..."
    sudo rm -r $chiseldir
fi

# Download the latest version of chisel
sudo git clone https://github.com/jpillora/chisel.git $chiseldir
cd $chiseldir

# https://farside.link/scribe/geekculture/chisel-network-tunneling-on-steroids-a28e6273c683
go build -ldflags="-s -w" .

# Add chisel directory to path
export PATH=$PATH:$chiseldir
sudo $rootdir/.bashrc

while true; do
    read -p $'\n'"Install client only (1), server only (2), or client and server as a relay (3).  Enter 1, 2, or 3. " yn
    case $yn in
        [1]* ) 
            while true; do
                read -rp $'\n'"Enter the remote server (endpoint) ip address this client will connect to (eg 1.1.1.1): " sip
                if [[ -z "${sip}" ]]; then
                    echo -e "Please enter the remote server (endpoint) ip address this client will connect to (eg 1.1.1.1) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the remote server (endpoint) port this client will connect to (eg 1234): " spt
                if [[ -z "${spt}" ]]; then
                    echo -e "Please enter the remote server (endpoint) port this client will connect to (eg 1234) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the fingerprint for the remote server (endpoint) that this client will connect to (eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B): " sfp
                if [[ -z "${sfp}" ]]; then
                    echo -e "Please enter the fingerprint for remote server (endpoint) that this client will connect to"
                    echo -e "(eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the port that the local client will listen on (eg 4321): " cpt
                if [[ -z "${cpt}" ]]; then
                    echo -e "Please enter the port that the local client will listen on (eg 4321) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the final destination port the remote server (endpoint) will deliver the connection to (eg 22): " ept
                if [[ -z "${ept}" ]]; then
                    echo -e "Please enter the final destination port the remote server (endpoint) will deliver the connection to (eg 22) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            # Remove any existing service script.
            sudo rm -f "$chiseldir/$chiselservicescript"

            # Create the service script
echo -e "#!/bin/bash
while :
do
	echo 'Checking connection...'

	echo quit | telnet 127.0.0.1 $cpt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
	#echo \"Test 1 Output: \$test_output\"

	if [[ \"\$test_output\" != 0 ]]; then
		echo 'Not connected, so connecting now...'
        sudo $chiseldir/chisel client -v --fingerprint '$sfp' $sip:$spt $cpt:127.0.0.1:$ept &
		sleep 2

		echo quit | telnet 127.0.0.1 $cpt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
		#echo \"Test 2 Output: \$test_output\"

		if [[ \"\$test_output\" == 0 ]]; then
			echo 'Connection successful!'
		else
			echo 'Retrying in 60 seconds...'
			sleep 60
		fi
	else
		echo 'Connected!  Will check again in 60 seconds...'
		sleep 60
	fi
done" >> "$chiseldir/$chiselservicescript"

            # Make it executable
            sudo chmod +x "$chiseldir/$chiselservicescript"

            while true; do
                read -rp $'\n'"Would you like to run chisel as a linux service? " yn
                case $yn in
                    [Yy]* )
                        # Create the chisel service

sudo echo "[Unit]
Description=$chiselsericename
After=network.target

[Service]
ExecStart=/bin/bash -c $chiseldir/$chiselservicescript
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" >> "$servicefolder/$chiselsericename.service"

                        sudo systemctl daemon-reload
                        sudo systemctl enable $chiselsericename
                        sudo systemctl start $chiselsericename

                        # Wait few seconds for the chisel service to start...
                        sleep 5

                        echo -e ""
                        echo -e "You can use the following command to check the status of the service:"
                        echo -e "  sudo systemctl status $chiselsericename"
                        echo -e "You can check that the client is listening on port $cpt b running the following command:"
                        echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $cpt | grep $chiselsericename"
                        echo -e ""
                        echo -e "************************************Important***************************************"
                        echo -e "If you are conneting to the remote server using SSH and using a public key, you MUST"
                        echo -e "have the authorized keys located in your ~/.ssh folder."
                        echo -e "If you need to copy them manually, you can use the following command(s) on your local"
                        echo -e "machine, ssuming the name of the authorized key is id_rsa.pub.  If your authorized key"
                        echo -e "uses a different name, make the changes accordingly.  Also, make note of the ssh port"
                        echo -e "22 which may be different for your installation."
                        echo -e "  scp -P 22 ~/.ssh/id_rsa.pub remote_username@$myip:~/.ssh"
                        echo -e ""
                        echo -e "This may require a reboot for the changes to take effect!"
                        echo -e "Youu can check the connection using the following command:"
                        echo -e "  ssh remote_username@localhost -p $cpt"
                        echo -e "You can run ssh as a SOCKS5 proxy tunnel (like a VPN) using the following command"
                        echo -e "(change 9292 to the port you want to use as your local proxy port):"
                        echo -e "  ssh -D 9292 -f -C -q -N -p $cpt remote_username@localhost"

                        break;;

                    [Nn]* ) 
                        echo -e ""
                        echo -e "You have chosen not to run chisel as a linux service.  Manually starting up"
                        echo -e "the client can be accomplised using the following command:"
                        echo -e "  sudo '$chiseldir'/chisel client -v --fingerprint '$sfp' '$sip':'$spt' '$cpt':127.0.0.1:'$ept' &"
                        echo -e "You can check that the client is listening on port $cpt b running the following command:"
                        echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $cpt | grep $chiselsericename"
                        echo -e ""
                        echo -e "************************************Important***************************************"
                        echo -e "If you are conneting to the remote server using SSH and using a public key, you MUST"
                        echo -e "have the authorized keys located in your ~/.ssh folder."
                        echo -e "If you need to copy them manually, you can use the following command(s) on your local"
                        echo -e "machine, assuming the name of the authorized key is id_rsa.pub.  If your authorized key"
                        echo -e "uses a different name, make the changes accordingly.  Also, make note of the ssh port"
                        echo -e "22 which may be different for your installation."
                        echo -e "  scp -P 22 ~/.ssh/id_rsa.pub remote_username@$myip:~/.ssh"
                        echo -e ""
                        echo -e "This may require a reboot for the changes to take effect!"
                        echo -e "Youu can check the connection using the following command:"
                        echo -e "  ssh remote_username@localhost -p $cpt"
                        echo -e ""
                        echo -e "You can run ssh as a SOCKS5 proxy tunnel (like a VPN) using the following command"
                        echo -e "(change 9292 to the port you want to use as your local proxy port):"
                        echo -e "  ssh -D 9292 -f -C -q -N -p $cpt remote_username@localhost"
                    
                        break;;
                    * ) echo -e "Please indicate if you would like to run chisel as a linux service or hit Ctrl+C to exit.";;
                esac
            done

            break;;
 
        [2]* ) 

            while true; do
                read -rp $'\n'"Enter the port you want the server to listen on (eg 1234): " spt
                if [[ -z "${spt}" ]]; then
                    echo -e "Please enter the port you want the server to listen on (eg 1234) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the key which will be used to generate a fingerprint used for client connections (eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B): " sky
                if [[ -z "${sky}" ]]; then
                    echo -e "Please enter the key to be used by the server to generate a fingerprint"
                    echo -e "(eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            # Remove any existing service script.
            sudo rm -f "$chiseldir/$chiselservicescript"

            # Create the service script
echo -e "#!/bin/bash
while :
do
	echo 'Checking connection...'

	echo quit | telnet 127.0.0.1 $spt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
	#echo \"Test 1 Output: \$test_output\"

	if [[ \"\$test_output\" != 0 ]]; then
		echo 'Not running, so starting now...'
        sudo $chiseldir/chisel server -v --port $spt --key '$sky' &
		sleep 2

		echo quit | telnet 127.0.0.1 $spt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
		#echo 'Test 2 Output: \$test_output'

		if [[ \"\$test_output\" == 0 ]]; then
			echo 'Startup successful!'
		else
			echo 'Retrying in 60 seconds...'
			sleep 60
		fi
	else
		echo 'Connected!  Will check again in 60 seconds...'
		sleep 60
	fi
done" >> "$chiseldir/$chiselservicescript"

            # Make it executable
            sudo chmod +x "$chiseldir/$chiselservicescript"

            while true; do
                read -rp $'\n'"Would you like to run chisel as a linux service? " yn
                case $yn in
                    [Yy]* )

                        # Create the chisel service

sudo echo "[Unit]
Description=$chiselsericename
After=network.target

[Service]
ExecStart=/bin/bash -c $chiseldir/$chiselservicescript
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" >> "$servicefolder/$chiselsericename.service"

                        sudo systemctl daemon-reload
                        sudo systemctl enable $chiselsericename
                        sudo systemctl start $chiselsericename

                        # Get the server fingerprint
                        fingerprint=""
                        fingerprint=$(sudo systemctl status $chiselsericename | grep Fingerprint | awk '{print $10}')
                        fingerprint="${fingerprint#Fingerprint:}"
                        fingerprint=$(echo $fingerprint | xargs)
                        while [ -z "${fingerprint}" ]; do
                            echo -e "Waiting on the fingerprint..."
                            sleep 5
                            fingerprint=$(sudo systemctl status $chiselsericename | grep Fingerprint | awk '{print $10}')
                            fingerprint="${fingerprint#Fingerprint:}"
                            fingerprint=$(echo $fingerprint | xargs)
                        done

                        echo -e "Your fingerprint required for client connections is $fingerprint"
                        echo -e "Copy it down!"
                        echo -e "You can use the following command to retieve it if you lose it:"
                        echo -e "  sudo systemctl status $chiselsericename | grep Fingerprint | awk '{print \$10}'"
                        echo -e ""
                        echo -e "Use the following command to connect to the remote server from your local machine"
                        echo -e "(for example, your laptop):"
                        echo -e "  $chiseldir/chisel client -v --fingerprint '$fingerprint' $myip:$spt $spt:127.0.0.1:$spt &"
                        echo -e ""
                        echo -e "You can check that the server is listening on port $spt b running the following command:"
                        echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $spt"

                        break;;

                    [Nn]* ) 
                        echo -e ""
                        echo -e "You have chosen not to run chisel as a linux service.  Manually starting up"
                        echo -e "the server can be accomplised using the following command:"
                        echo -e "  sudo '$chiseldir'/chisel server -v --port '$spt' --key '$sky' &"
                        echo -e "You can check that the client is listening on port $cpt b running the following command:"
                        echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $spt | grep $chiselsericename"
                        echo -e ""
                        echo -e "************************************Important***************************************"
                        echo -e "Any clients connecting to this server using SSH and assuming this server uses only"
                        echo -e "public key authentication MUST have the authorized keys located in their ~/.ssh folder."
                        echo -e "If you need to copy them manually, you can use the following command(s) on your local"
                        echo -e "machine, assuming the name of the authorized key is id_rsa.pub.  If your authorized key"
                        echo -e "uses a different name, make the changes accordingly.  Also, make note of the ssh port"
                        echo -e "22 which may be different for your installation."
                        echo -e "  scp -P 22 ~/.ssh/id_rsa.pub remote_username@$myip:~/.ssh"
                        echo -e ""
                        echo -e "This may require a reboot on the client machine for the changes to take effect!"
                        echo -e "Youu can check the connection from the client machine to this server using the following"
                        echo -e "command. Change remote_user and client_port to those matching your client:"
                        echo -e "  ssh remote_username@localhost -p client_port"
                        ehco -e ""
                        echo -e "You can run ssh as a SOCKS5 proxy tunnel (like a VPN) on your client using the following"
                        echo -e "command (change 9292 to the local port you want to use as your proxy port and client_port"
                        echo -e "to the port chisel is listening on at your remote server):"
                        echo -e "  ssh -D 9292 -f -C -q -N -p client_port remote_username@localhost"
                    
                        break;;
                    * ) echo -e "Please indicate if you would like to run chisel as a linux service or hit Ctrl+C to exit.";;
                esac
            done

            break;;

        [3]* ) 
            while true; do
                read -rp $'\n'"Enter the port you want the local server to listen on (eg 1234): " spt
                if [[ -z "${spt}" ]]; then
                    echo -e "Please enter the port you want the server to listen on (eg 1234) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the key which will be used to generate a fingerprint used for client connections (eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B): " sky
                if [[ -z "${sky}" ]]; then
                    echo -e "Please enter the key to be used by the server to generate a fingerprint"
                    echo -e "(eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the remote server (endpoint) ip address this client will connect to (eg 1.1.1.1): " sip
                if [[ -z "${sip}" ]]; then
                    echo -e "Please enter the remote server (endpoint) ip address this client will connect to (eg 1.1.1.1) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the remote server (endpoint) port this client will connect to (eg 4321): " rpt
                if [[ -z "${rpt}" ]]; then
                    echo -e "Please enter the remote server (endpoint) ip address this client will connect to (eg 1.1.1.1) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the fingerprint for the remote server (endpoint) that this client will connect to (eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B): " sfp
                if [[ -z "${sfp}" ]]; then
                    echo -e "Please enter the fingerprint for remote server (endpoint) that this client will connect to"
                    echo -e "(eg bU76X7NWdBBqHYMhKtDL2GgMS65sD7B) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the port that the local client and server will communicate with each other on (eg 4321): " cpt
                if [[ -z "${cpt}" ]]; then
                    echo -e "Please enter the port that the local client will listen on (eg 4321) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the final destination port the remote server (endpoint) will deliver the connection to (eg 22): " ept
                if [[ -z "${ept}" ]]; then
                    echo -e "Please enter the final destination port the remote server (endpoint) will deliver the connection to (eg 22) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            # Remove any existing service script.
            sudo rm -f "$chiseldir/$chiselservicescript"

            # Create the service script
echo -e "#!/bin/bash
while :
do
	echo 'Checking connection...'

	echo quit | telnet 127.0.0.1 $spt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
	#echo \"Test 1 Output: \$test_output\"

	if [[ \"\$test_output\" != 0 ]]; then
		echo 'Not running, so starting now...'
        sudo $chiseldir/chisel server -v --port $spt --key '$sky' &
		sleep 2

		echo quit | telnet 127.0.0.1 $spt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
		#echo 'Test 2 Output: \$test_output'

		if [[ \"\$test_output\" == 0 ]]; then
			echo 'Startup successful!'
		else
			echo 'Retrying in 60 seconds...'
			sleep 60
		fi
	else
		echo 'Connected!  Will check again in 60 seconds...'
		sleep 60
	fi
done" >> "$chiseldir/$chiselservicescript"

            # Make it executable
            sudo chmod +x "$chiseldir/$chiselservicescript"

            # Create the chisel service

sudo echo "[Unit]
Description=$chiselsericename
After=network.target

[Service]
ExecStart=/bin/bash -c $chiseldir/$chiselservicescript
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target" >> "$servicefolder/$chiselsericename.service"

            sudo systemctl daemon-reload
            sudo systemctl enable $chiselsericename
            sudo systemctl start $chiselsericename

            # Wait few seconds for the chisel service to start...
            sleep 5

            # Get the server fingerprint
            fingerprint=""
            fingerprint=$(sudo systemctl status $chiselsericename | grep Fingerprint | awk '{print $10}')
            fingerprint="${fingerprint#Fingerprint:}"
            fingerprint=$(echo $fingerprint | xargs)
            while [ -z "${fingerprint}" ]; do
                echo -e "Waiting on the fingerprint..."
                sleep 5
                fingerprint=$(sudo systemctl status $chiselsericename | grep Fingerprint | awk '{print $10}')
                fingerprint="${fingerprint#Fingerprint:}"
                fingerprint=$(echo $fingerprint | xargs)
            done

            # Remove any existing service script.
            sudo rm -f "$chiseldir/$chiselservicescript"

            # Create the service script
echo -e "#!/bin/bash
while :
do
	echo 'Checking connection...'

	echo quit | telnet 127.0.0.1 $cpt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
	#echo \"Test 1 Output: \$test_output\"

	if [[ \"\$test_output\" != 0 ]]; then
		echo 'Not connected, so connecting now...'
		sudo $chiseldir/chisel server -v --port $spt --key '$sky' &
		sleep 2
        sudo $chiseldir/chisel client -v --fingerprint '$sfp' $sip:$rpt $cpt:127.0.0.1:$ept &
		sleep 2

        echo quit | telnet 127.0.0.1 $cpt 2>/dev/null | egrep -qi Connected && test_output=$(echo \"\$?\")
        #echo \"Test 2 Output: \$test_output\"

		if [[ \"\$test_output\" != 0 ]]; then
			echo 'Startup successful!'
		else
			echo 'Retrying in 60 seconds...'
			sleep 60
		fi
	else
		echo 'Connected!  Will check again in 60 seconds...'
		sleep 60
	fi
done" >> "$chiseldir/$chiselservicescript"

            # Make it executable
            sudo chmod +x "$chiseldir/$chiselservicescript"

            sudo systemctl stop $chiselsericename
            sudo systemctl daemon-reload
            sudo systemctl enable $chiselsericename
            sudo systemctl start $chiselsericename

            # Wait few seconds for the chisel service to start...
            sleep 5

            echo -e ""
            echo -e "Your fingerprint required for client connections is $fingerprint"
            echo -e "Copy it down!"
            echo -e "You can use the following command to retieve it if you lose it:"
            echo -e "  sudo systemctl status $chiselsericename | grep Fingerprint | awk '{print \$10}'"
            echo -e ""
            echo -e "Use the following command to connect to the remote server from your local machine"
            echo -e "(for example, your laptop):"
            echo -e "  $chiseldir/chisel client -v --fingerprint '$fingerprint' $myip:$spt $cpt:127.0.0.1:$cpt &"
            echo -e ""
            echo -e "You can use the following command to check the status of the service:"
            echo -e "  sudo systemctl status $chiselsericename"
            echo -e ""
            echo -e "You can check that the server is listening on port $spt b running the following command:"
            echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $spt | grep $chiselsericename"
            echo -e "You can check that the client is listening on port $cpt b running the following command:"
            echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $cpt | grep $chiselsericename"
            echo -e " Or just the below for both:"
            echo -e "  sudo lsof -i -P -n | grep LISTEN | grep $chiselsericename"
            echo -e ""
            echo -e "************************************Important***************************************"
            echo -e "If you are conneting to the remote server using SSH and using a public key, you MUST"
            echo -e "have the authorized keys located in your ~/.ssh folder."
            echo -e "If you need to copy them manually, you can use the following command(s) on your local"
            echo -e "machine, ssuming the name of the authorized key is id_rsa.pub.  If your authorized key"
            echo -e "uses a different name, make the changes accordingly.  Also, make note of the ssh port"
            echo -e "22 which may be different for your installation."
            echo -e "  scp -P 22 ~/.ssh/id_rsa.pub remote_username@$myip:~/.ssh"
            echo -e ""
            echo -e "This may require a reboot for the changes to take effect!"
            echo -e "Youu can check the connection using the following command:"
            echo -e "  ssh remote_username@localhost -p $cpt"
            echo -e "You can run ssh as a SOCKS5 proxy tunnel (like a VPN) using the following command"
            echo -e "(change 9292 to the port you want to use as your local proxy port):"
            echo -e "  ssh -D 9292 -f -C -q -N -p $cpt remote_username@localhost"

            break;;
        * ) echo -e "Please enter option 1, 2, or 3.";;
    esac
done

cd $startdir
