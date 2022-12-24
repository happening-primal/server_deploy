#!/binbash

# This script was written and tested on Ubuntu 20.04

# TBD
    # Check for PermitTunnel yes in sshd_config on linux installs (VPS)
        #sudo nano /etc/ssh/sshd_config
        #PermitTunnel no
        #PermitTunnel yes
        #sudo systemctl restart sshd

    # Finish linux client only installation
    
    # Macbook shadowsocks run as a daemon, now only manual run in CLI

    # Output final configuarion diagram, save to file for future use...

# References:
# https://www.digitalocean.com/community/tutorials/how-to-set-up-an-ssl-tunnel-using-stunnel-on-ubuntu

# Prerun

# Variable declarations
stunnel_conf_name=stunnel.conf
shadowsocks_conf_name=config.json
localhost=127.0.0.1
os_name=$(uname)

case $os_name in
    [Linux]* )
        # Make sure the required dependencies are installed
        sudo apt update && sudo apt -y install curl stunnel4 shadowsocks-libev sslh wget && sudo apt -y upgrade
        sudo systemctl stop sslh
        sudo systemctl stop stunnel4
        sudo systemctl stop shadowsocks
        ;;
    * )
        while true; do
            read -rp $'\n'"Are you running this script on a macbook? " yn
            if [[ -z "${yn}" ]]; then
                echo -e "Please anser y or n or hit Ctrl+C to exit."
                continue
            fi

            echo -e "Macbook, ok"
            brew install shadowsocks-libev
            brew install stunnel

            break
        done;;
esac

sslh_in_port=25110
sslh_http_out_port=24110
sslh_ssh_out_port=24220     # For ssh transport
sslh_anyprot_out_port=22120 # For shadowsocks transport

stunnel_web_client_in_port=$sslh_http_out_port
stunnel_relay_client_in_port=$sslh_ssh_out_port
stunnel_client_only_port=$sslh_http_out_port

nonrootuser=$(who | awk '{print $1}' | awk -v RS="[ \n]+" '!n[$0]++' | grep -v 'root')
rootdir=/home/$nonrootuser

pad2="   "
pad3="  "
pad4=" "
pad5=""

while true; do
    read -p $'\n'"Install server (endpoint) only (1), client / server as a relay (2), or client only (3)?  Enter 1, 2, or 3. " install_type
    case $install_type in
        [1]* )

            ##############################################################################################################
            ########################################### Server Only (Endpoint) ###########################################
            ##############################################################################################################

            case $os_name in
                [Linux]* )
                    echo -e ""
                    echo -e "Seems to be a linux box so continuing..."
                    continue
                    ;;
                * )
                    echo -e ""
                    echo -e "Expecting linux but it's not so aborting!"
                    exit;;
            esac

            echo -e ""
            echo -e "Server (endpoint) setup:"
            echo -e ""
            echo -e "  The server is the endpoint that all traffic will flow to. If you want to fully mask the"
            echo -e "  traffic between your client and this server, use port 443.  The resuling transmissions will"
            echo -e "  appear as legitimate HTTP(S) traffic to an outside observer.  Masking your traffic in this"
            echo -e "  manner will leave an outside observer with no idea that you are not making legitimate connections"
            echo -e "  to the server.  In addition, specifying an external or internally hosted web site adds further"
            echo -e "  protection by displaying a web site to anyone attempting to make a standard HTTP connection to"
            echo -e "  this server.  In other words, you can hide in plain sight."
            echo -e ""
            echo -e "The recommended setup is shown below."
            echo -e ""
            echo -e "   Upstream client/server relay"
            echo -e "            (option 2)"
            echo -e "                 |443"
            echo -e "                 |                                                                                           "
            echo -e "                 |                                                                                           "
            echo -e "   ==============|========================================================================================== "
            echo -e "  ║              |                                                                                          ║"
            echo -e "  ║              |443                                                                                       ║"
            echo -e "  ║   ___________v___________               _______________________               _______________________   ║"
            echo -e "  ║  |                       |             |                       |             |                       |  ║"
            echo -e "  ║  |   Stunnel or Chisel   |25110   25110|         SSLH          |24110   24110|   Stunnel or Chisel   |  ║"
            echo -e "  ║  |       (server)        |------------>|    (de-multiplexer)   |------------>|       (client)        |  ║"
            echo -e "  ║  |        0.0.0.0        |┌            |       127.0.0.1       |   --http    |       127.0.0.1       |  ║"
            echo -e "  ║  |_______________________| \           |_______________________|             |_______________________|  ║"
            echo -e "  ║                             \              |22     |22120                   ┐            |8443          ║"
            echo -e "  ║                       Self signed cert ok  |       |                       /             |              ║"
            echo -e "  ║               _____________________________|       | --anyprot    Use cert and key       |              ║"
            echo -e "  ║              |           --ssh                     |              from letsencrypt       |              ║"
            echo -e "  ║              |22                                   |22120                                |8443          ║"
            echo -e "  ║  ____________V__________                ___________V___________               ___________V___________   ║"
            echo -e "  ║ |                       |              |                       |             |                       |  ║"
            echo -e "  ║ |       SSH Daemon      |              |      Shadowsocks      |             |       Web Server*     |  ║"
            echo -e "  ║ |         (SSHD)        |              |      (ss-server)      |             | (Apache, Nginx, SWAG) |  ║"
            echo -e "  ║ |       127.0.0.1       |              |       127.0.0.1       |             |       127.0.0.1       |  ║"
            echo -e "  ║ |_______________________|              |_______________________|             |_______________________|  ║"
            echo -e "  ║              |                                     |                                                    ║"
            echo -e "  ║              V                                     V                                                    ║"
            echo -e "  ║    Final Destination(s)                  Final Destination(s)                                           ║"
            echo -e "  ║                                                                                                         ║"
            echo -e "   ========================================================================================================= "
            echo -e ""

            while true; do
                # 443 if you want to hide your traffic in plain site
                read -rp $'\n'"Enter the port that the upstream client will connect to, stunnel server will listen on (eg 443): " stunnel_server_listen_port
                if [[ -z "${stunnel_server_listen_port}" ]]; then
                    echo -e "Please enter the port that the stunnel server will listen on (eg 443) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\n'"Enter the port that sshd is listening on (eg 22): " sshd_listen_port
                if [[ -z "${sshd_listen_port}" ]]; then
                    echo -e "Please enter the port that sshd is listening on (eg 22) or hit Ctrl+C to exit."
                    continue
                fi

                sslh_ssh_out_port=$sshd_listen_port     # For ssh transport

                break
            done

            while true; do
                read -rp $'\n'"Enter the password you want to use to connect to the shadowsocks server (eg 9smLqjz77serN5k3hii): " shadowsocks_password
                if [[ -z "${shadowsocks_password}" ]]; then
                    echo -e "Please enter the password you want to use to connect to the shadowsocks server (eg 9smLqjz77serN5k3hii) or hit Ctrl+C to exit."
                    continue
                fi

                break
            done

            while true; do
                read -rp $'\nIs there a web server running on this machine or a web page outside this box that you would like to direct\nlegitimate http traffic to (y/n)? ' web_client
                if [[ -z "${web_client}" ]]; then
                    echo -e 'Please indicate whether there is a web server running on this machine or a web page outside this box that'
                    echo -e 'you would like to direct legitimate http traffic to (y/n)? or hit Ctrl+C to exit.'
                    continue
                fi

                case $web_client in
                    [y]* )
                        read -rp $'\n'"What is the IP or domain name of the web server (eg google.com or 127.0.0.1)? " stunnel_web_client_destination
                        if [[ -z "${stunnel_web_client_destination}" ]]; then
                            echo -e "Please indicate the IP or domain name of the web server (eg google.com or 127.0.0.1) or hit Ctrl+C to exit."
                            continue
                        fi

                        read -rp $'\n'"What port is the web server listeing on (eg 443 for external web site or 8443 for internal)? " stunnel_web_client_out_port
                        if [[ -z "${stunnel_web_client_out_port}" ]]; then
                            echo -e "Please indicate what port the web server listeing on (eg 443 for external web site or 8443 for"
                            echo -e "internal) or hit Ctrl+C to exit."
                            continue
                        fi

                        echo -e ""

                        check_web_client=$(curl --silent http://$stunnel_web_client_destination:$stunnel_web_client_out_port)
                        check_web_client+=$(curl --silent https://$stunnel_web_client_destination:$stunnel_web_client_out_port)

                        # Check that the destination exists and exit if it does not
                        if [ -z "$check_web_client" ]; then
                            echo -e "Check if the web server exists...the web server does not seem to exist!"
                        else
                            echo -e "Check if the web server exists...web server exists so continuing."
                            break;
                        fi;;

                    [n]* )

                    break;;

                    * ) echo -e "Please enter y or n.";;

                esac

            done

            # Check for existing tls certificates generated by swag
            domain_name=$(find $rootdir/docker/swag/etc/letsencrypt/archive/* -type d)

            if [ ! -z ${domain_name} ]
            then
                fullchain=$domain_name/$(ls -lt $domain_name | grep 'fullc' | head -1 | awk '{print $9}')
                cert=$domain_name/$(ls -lt $domain_name | grep 'privk' | head -1 | awk '{print $9}')
                while true; do
                    read -rp $'\nLooks like you\'ve got some .pem files located at the following locations:\n\n    '$fullchain$'\n    '$cert$'\n\nDo you want to use them for stunnel (y/n)? ' yn
                    case $yn in
                        [y]* )
                            break;;
                        [n]* )
                            while true; do
                                read -rp $'\n'"Please enter the full path to the keyfile: " fullchain
                                if [[ -z "${fullchain}" ]]; then
                                    echo -e "Please enter the port on full path to the keyfile or hit Ctrl+C to exit."
                                    continue
                                fi
                                break
                            done

                            while true; do
                                read -rp $'\n'"Please enter the full path to the cert: " cert
                                if [[ -z "${cert}" ]]; then
                                    echo -e "Please enter the port on full path to the cert or hit Ctrl+C to exit."
                                    continue
                                fi
                                break
                            done
                            break;;
                        * )  echo -e "Please indicate y or n or hit Ctrl+C to exit.";;
                     esac
                done
            fi

            # Check if any of the required ports are already in use
            port_check=$(sudo lsof -i -P -n | grep LISTEN | grep ":$stunnel_server_listen_port \|:$sslh_in_port \|:$stunnel_web_client_in_port \|:$stunnel_relay_client_in_port")

            if [[ ! -z "${port_check}" ]]; then
                echo -e "Looks like some of the required ports are already in use!  Please clear that up and try again."
                echo -e ""
                echo -e "      "$port_check
                echo -e ""
                echo -e "You can kill the offending process by executing:"
                echo -e ""
                echo -e "      sudo kill -9 process_id_number"
                exit
            fi

            # Create the shadowsocks service
            sudo rm -rf /etc/systemd/system/shadowsocks.service && sudo touch /etc/systemd/system/shadowsocks.service
            sudo chmod u=rw,og=rw /etc/systemd/system/shadowsocks.service

            echo -e "[Unit]" >> /etc/systemd/system/shadowsocks.service
            echo -e "Description=Shadowsocks proxy server" >> /etc/systemd/system/shadowsocks.service
            echo -e "" >> /etc/systemd/system/shadowsocks.service
            echo -e "[Service]" >> /etc/systemd/system/shadowsocks.service
            echo -e "User=root" >> /etc/systemd/system/shadowsocks.service
            echo -e "Group=root" >> /etc/systemd/system/shadowsocks.service
            echo -e "Type=simple" >> /etc/systemd/system/shadowsocks.service
            echo -e "ExecStart=/usr/bin/ss-server -c /etc/shadowsocks/$shadowsocks_conf_name -v start" >> /etc/systemd/system/shadowsocks.service
            echo -e "ExecStop=/usr/bin/ss-server -c /etc/shadowsocks/$shadowsocks_conf_name -v stop" >> /etc/systemd/system/shadowsocks.service
            echo -e "" >> /etc/systemd/system/shadowsocks.service
            echo -e "[Install]" >> /etc/systemd/system/shadowsocks.service
            echo -e "WantedBy=multi-user.target" >> /etc/systemd/system/shadowsocks.service

            sudo chmod u=rw,og=r /etc/systemd/system/shadowsocks.service

            # Configure shadowsocks
            sudo mkdir /etc/shadowsocks 2>/dev/null || true

            sudo rm -rf /etc/shadowsocks/$shadowsocks_conf_name && sudo touch /etc/shadowsocks/$shadowsocks_conf_name
            sudo chmod u=rw,og=rw /etc/shadowsocks/$shadowsocks_conf_name

            echo -e '{' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"server":"127.0.0.1",' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"server_port":'$sslh_anyprot_out_port',' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"password":"'$shadowsocks_password'",' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"timeout":300,' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"method":"aes-256-cfb",' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"workers":1,' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '"nameserver":"127.0.0.1:53"' >> /etc/shadowsocks/$shadowsocks_conf_name
            echo -e '}' >> /etc/shadowsocks/$shadowsocks_conf_name

            sudo chmod u=rw,og=r /etc/shadowsocks/$shadowsocks_conf_name

            sudo systemctl daemon-reload
            sudo systemctl enable shadowsocks
            sudo systemctl start shadowsocks

            # Configure stunnel
            sudo rm -rf /etc/stunnel/$stunnel_conf_name && sudo touch /etc/stunnel/$stunnel_conf_name

            sudo chmod u=rw,og=rw /etc/stunnel/$stunnel_conf_name

            echo -e "[server]" >> /etc/stunnel/$stunnel_conf_name
            echo -e "client = no" >> /etc/stunnel/$stunnel_conf_name
            echo -e "cert = $fullchain" >> /etc/stunnel/$stunnel_conf_name
            echo -e "key = $cert" >> /etc/stunnel/$stunnel_conf_name
            echo -e "accept = 0.0.0.0:$stunnel_server_listen_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "connect = $localhost:$sslh_in_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "" >> /etc/stunnel/$stunnel_conf_name
            echo -e "[web_client]" >> /etc/stunnel/$stunnel_conf_name
            echo -e "client = yes" >> /etc/stunnel/$stunnel_conf_name
            echo -e "cert = $fullchain" >> /etc/stunnel/$stunnel_conf_name
            echo -e "key = $cert" >> /etc/stunnel/$stunnel_conf_name
            echo -e "accept = $localhost:$stunnel_web_client_in_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "connect = $stunnel_web_client_destination:$stunnel_web_client_out_port" >> /etc/stunnel/$stunnel_conf_name

            sudo chmod u=rw,og=r /etc/stunnel/$stunnel_conf_name

            sudo systemctl enable stunnel4
            sudo systemctl start stunnel4

            sudo rm -rf /etc/default/sslh.new

            $(cat /etc/default/sslh | grep -v DAEMON_OPTS | sudo tee -a /etc/default/sslh.new) 2>/dev/null

            # --anyprot is used to shuttle the shadowsocks traffic
            $(echo "DAEMON_OPTS=\"--user sslh --listen $localhost:$sslh_in_port --http $localhost:$sslh_http_out_port --ssh $localhost:$sslh_ssh_out_port --anyprot $localhost:$sslh_anyprot_out_port --pidfile /var/run/sslh/sslh.pid" | sudo tee -a /etc/default/sslh.new) 2>/dev/null

            sudo rm -rf /etc/default/sslh

            sudo mv /etc/default/sslh.new /etc/default/sslh

            sudo systemctl enable sslh
            sudo systemctl restart sslh

            echo -e "We're all finished.  Your server (enpoiint) is set up."
            echo -e ""
            echo -e "By default, sslh installs apache2 web server, which you may not need.  If that is the case"
            echo -e "you can uninstall it with the following command:"
            echo -e ""
            echo -e "         sudo apt purge apache2"
            echo -e ""
            echo -e "Also, if you have an existing web server that was listening on 0.0.0.0:port, you can now move it"
            echo -e "to 127.0.0.1:port as sslh will handle traffic routing and there is no need to expose the service"
            echo -e "globally.  If you are running a web server reverse proxy, and you have other services running on"
            echo -e "0.0.0.0:port, you can liklely bring these inside to 127.0.0.1:port to limit exposure."

        break;;
 
        [2]* ) 

            ##############################################################################################################
            ########################################## Client / Server (Relay) ###########################################
            ##############################################################################################################

            case $os_name in
                [Linux]* )
                    echo -e ""
                    echo -e "Seems to be a linux box so continuing..."
                    continue
                    ;;
                * )
                    echo -e ""
                    echo -e "Expecting linux but it's not so aborting!"
                    exit;;
            esac

            # Variable declarations
            sslh_anyprot_out_port=$sslh_ssh_out_port

            echo -e ""
            echo -e "Client server setup as a relay:"
            echo -e ""
            echo -e "  The server is the entry point that traffic will flow through. If you want to fully mask the"
            echo -e "  traffic between your client and this server, use port 443.  The resuling transmissions will"
            echo -e "  appear as legitimate HTTP(S) traffic to an outside observer.  Masking your traffic in this"
            echo -e "  manner will leave an outside observer with no idea that you are not making legitimate connections"
            echo -e "  to the server.  In addition, specifying an external or internally hosted web site adds further"
            echo -e "  protection by displaying a web site to anyone attempting to make a standard HTTP connection to"
            echo -e "  this server.  In other words, you can hide in plain sight."
            echo -e ""
            echo -e "The recommended setup is shown below."
            echo -e ""
            echo -e "        Upstream Client"
            echo -e "           (option 3)"
            echo -e "               |443                                                                                        "
            echo -e "               |                                                                                           "
            echo -e "               |                                                                                           "
            echo -e " ==============|========================================================================================== "
            echo -e "║              |     Self signed cert ok                                                                  ║"
            echo -e "║              |443         /                                                                             ║"
            echo -e "║   ___________V___________└              _______________________               _______________________   ║"
            echo -e "║  |                       |             |                       |             |                       |  ║"
            echo -e "║  |   Stunnel or Chisel   |25110   25110|          SSLH         |24110   24110|   Stunnel or Chisel   |  ║"
            echo -e "║  |       (server)        |------------>|    (de-multiplexer)   |------------>|       (client)        |  ║"
            echo -e "║  |       0.0.0.0         |             |       127.0.0.1       |   --http    |       127.0.0.1       |  ║"
            echo -e "║  |_______________________|             |_______________________|             |_______________________|  ║"
            echo -e "║                                            |24220  |24220                   ┐             |8443         ║"
            echo -e "║               _____________________________|       |                       /              |             ║"
            echo -e "║              |           --ssh                     | --anyprot    Use cert and key        |             ║"
            echo -e "║              |24220               _________________|              from letsencrypt        |8443         ║"
            echo -e "║   ___________V___________        |                                            ____________V__________   ║"
            echo -e "║  |                       |       |   *Running a web sever as an endpoint     |                       |  ║"
            echo -e "║  |  Stunnel or Chisel    |24220  |   here ensures that it is impossible      |       Web Server*     |  ║"
            echo -e "║  |    (relay client)     |<------┘   to tell if you are tunneling non-HTTP   | (Apache, Nginx, SWAG) |  ║"
            echo -e "║  |       127.0.0.1       |┌          on port 443, as 'real' HTTP requests    |       127.0.0.1       |  ║"
            echo -e "║  |_______________________| \         will be answered correctly. Optional.   |_______________________|  ║"
            echo -e "║              |443           \                                                                           ║"
            echo -e "║              |        Self signed cert ok                                                               ║"
            echo -e " ==============|========================================================================================== "
            echo -e "               |                                                                                           "
            echo -e "               |                                                                                           "
            echo -e "               |443                                                                                        "
            echo -e "               V                                                                                           "
            echo -e "      Downstream server IP"
            echo -e "        or domain name"
            echo -e ""

            while true; do
                # 443 if you want to hide your traffic in plain site
                read -rp $'\n'"Enter the port that the upstream client will connect to, stunnel server will listen on (eg 443): " stunnel_server_listen_port
                if [[ -z "${stunnel_server_listen_port}" ]]; then
                    echo -e "Please enter the port that the stunnel server will listen on (eg 443) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                read -rp $'\nIs there a web server running on this machine or a web page outside this box that you would like to direct\nlegitimate http traffic to (y/n)? ' web_client
                if [[ -z "${web_client}" ]]; then
                    echo -e 'Please indicate whether there is a web server running on this machine or a web page outside this box that'
                    echo -e 'you would like to direct legitimate http traffic to (y/n)? or hit Ctrl+C to exit.'
                    continue
                fi

                case $web_client in
                    [y]* )
                        read -rp $'\n'"What is the IP or domain name of the web server (eg google.com or 127.0.0.1)? " stunnel_web_client_destination
                        if [[ -z "${stunnel_web_client_destination}" ]]; then
                            echo -e "Please indicate the IP or domain name of the web server (eg google.com or 127.0.0.1) or hit Ctrl+C to exit."
                            continue
                        fi

                        read -rp $'\n'"What port is the web server listeing on (eg 443 for external web site or 8443 for internal)? " stunnel_web_client_out_port
                        if [[ -z "${stunnel_web_client_out_port}" ]]; then
                            echo -e "Please indicate what port the web server listeing on (eg 443 for external web site or 8443 for"
                            echo -e "internal) or hit Ctrl+C to exit."
                            continue
                        fi

                        echo -e ""

                        check_web_client=$(curl --silent http://$stunnel_web_client_destination:$stunnel_web_client_out_port)
                        check_web_client+=$(curl --silent https://$stunnel_web_client_destination:$stunnel_web_client_out_port)

                        # Check that the destination exists and exit if it does not
                        if [ -z "$check_web_client" ]; then
                            echo -e "Check if the web server exists...the web server does not seem to exist!"
                        else
                            echo -e "Check if the web server exists...web server exists so continuing."
                            break;
                        fi;;

                    [n]* )

                    break;;

                    * ) echo -e "Please enter y or n.";;

                esac

            done

            while true; do
                read -rp $'\n'"Enter the ip address of the destination for the relay client (eg 1.1.1.1): " stunnel_relay_destination_ip
                if [[ -z "${stunnel_relay_destination_ip}" ]]; then
                    echo -e "Please enter the ip address of the destination for the relay client (eg 1.1.1.1) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            while true; do
                # 443 if you want to hide your traffic in plain site
                read -rp $'\n'"Enter the port on $stunnel_relay_destination_ip that the relay client will connect to (eg 443): " stunnel_relay_client_out_port
                if [[ -z "${stunnel_relay_client_out_port}" ]]; then
                    echo -e "Please enter the port on $stunnel_relay_destination_ip that the relay client will connect to (eg 443) or hit Ctrl+C to exit."
                    continue
                fi
                break
            done

            # Check for existing tls certificates generated by swag
            domain_name=$(find $rootdir/docker/swag/etc/letsencrypt/archive/* -type d)

            if [ ! -z ${domain_name} ]
            then
                fullchain=$domain_name/$(ls -lt $domain_name | grep 'fullc' | head -1 | awk '{print $9}')
                cert=$domain_name/$(ls -lt $domain_name | grep 'privk' | head -1 | awk '{print $9}')
                while true; do
                    read -rp $'\nLooks like you\'ve got some .pem files located at the following locations:\n\n    '$fullchain$'\n    '$cert$'\n\nDo you want to use them for stunnel (y/n)? ' yn
                    case $yn in
                        [y]* )
                            break;;
                        [n]* )
                            while true; do
                                read -rp $'\n'"Please enter the full path to the keyfile: " fullchain
                                if [[ -z "${fullchain}" ]]; then
                                    echo -e "Please enter the port on full path to the keyfile or hit Ctrl+C to exit."
                                    continue
                                fi
                                break
                            done

                            while true; do
                                read -rp $'\n'"Please enter the full path to the cert: " cert
                                if [[ -z "${cert}" ]]; then
                                    echo -e "Please enter the port on full path to the cert or hit Ctrl+C to exit."
                                    continue
                                fi
                                break
                            done
                            break;;
                        * )  echo -e "Please indicate y or n or hit Ctrl+C to exit.";;
                     esac
                done
            fi

            # Check if any of the required ports are already in use
            port_check=$(sudo lsof -i -P -n | grep LISTEN | grep ":$stunnel_server_listen_port \|:$sslh_in_port \|:$stunnel_web_client_in_port \|:$stunnel_relay_client_in_port")

            if [[ ! -z "${port_check}" ]]; then
                echo -e "Looks like some of the required ports are already in use!  Please clear that up and try again."
                echo -e ""
                echo -e "      "$port_check
                echo -e ""
                echo -e "You can kill the offending process by executing:"
                echo -e ""
                echo -e "      sudo kill -9 process_id_number"
                exit
            fi

            sudo rm -rf /etc/stunnel/$stunnel_conf_name && sudo touch /etc/stunnel/$stunnel_conf_name

            sudo chmod u=rw,og=rw /etc/stunnel/$stunnel_conf_name

            echo -e "[server]" >> /etc/stunnel/$stunnel_conf_name
            echo -e "client = no" >> /etc/stunnel/$stunnel_conf_name
            echo -e "cert = $fullchain" >> /etc/stunnel/$stunnel_conf_name
            echo -e "key = $cert" >> /etc/stunnel/$stunnel_conf_name
            echo -e "accept = 0.0.0.0:$stunnel_server_listen_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "connect = $localhost:$sslh_in_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "" >> /etc/stunnel/$stunnel_conf_name
            echo -e "[web_client]" >> /etc/stunnel/$stunnel_conf_name
            echo -e "client = yes" >> /etc/stunnel/$stunnel_conf_name
            echo -e "cert = $fullchain" >> /etc/stunnel/$stunnel_conf_name
            echo -e "key = $cert" >> /etc/stunnel/$stunnel_conf_name
            echo -e "accept = $localhost:$stunnel_web_client_in_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "connect = $stunnel_web_client_destination:$stunnel_web_client_out_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "" >> /etc/stunnel/$stunnel_conf_name
            echo -e "[relay_client]" >> /etc/stunnel/$stunnel_conf_name
            echo -e "client = yes" >> /etc/stunnel/$stunnel_conf_name
            echo -e "cert = $fullchain" >> /etc/stunnel/$stunnel_conf_name
            echo -e "key = $cert" >> /etc/stunnel/$stunnel_conf_name
            echo -e "accept = $localhost:$stunnel_relay_client_in_port" >> /etc/stunnel/$stunnel_conf_name
            echo -e "connect = $stunnel_relay_destination_ip:$stunnel_relay_client_out_port" >> /etc/stunnel/$stunnel_conf_name

            sudo chmod u=rw,og=r /etc/stunnel/$stunnel_conf_name

            sudo systemctl enable stunnel4
            sudo systemctl start stunnel4

            sudo rm -rf /etc/default/sslh.new

            $(cat /etc/default/sslh | grep -v DAEMON_OPTS | sudo tee -a /etc/default/sslh.new) 2>/dev/null

            $(echo "DAEMON_OPTS=\"--user sslh --listen $localhost:$sslh_in_port --http $localhost:$sslh_http_out_port --ssh $localhost:$sslh_ssh_out_port --anyprot $localhost:$sslh_anyprot_out_port --pidfile /var/run/sslh/sslh.pid" | sudo tee -a /etc/default/sslh.new) 2>/dev/null

            sudo rm -rf /etc/default/sslh

            sudo mv /etc/default/sslh.new /etc/default/sslh

            sudo systemctl enable sslh
            sudo systemctl restart sslh

            echo -e "We're all finished.  Your relay is set up."
            echo -e ""
            echo -e "By default, sslh installs apache2 web server, which you may not need.  If that is the case"
            echo -e "you can uninstall it with the following command:"
            echo -e ""
            echo -e "         sudo apt purge apache2"
            echo -e ""
            echo -e "Also, if you have an existing web server that was listening on 0.0.0.0:port, you can now move it"
            echo -e "to 127.0.0.1:port as sslh will handle traffic routing and there is no need to expose the service"
            echo -e "globally.  If you are running a web server reverse proxy, and you have other services running on"
            echo -e "0.0.0.0:port, you can liklely bring these inside to 127.0.0.1:port to limit exposure."

        break;;

        [3]* ) 

            ##############################################################################################################
            ################################################ Client Only #################################################
            ##############################################################################################################

            echo -e ""
            echo -e "Client setup (laptop, desktop, router, etc):"
            echo -e ""
            echo -e "  The client is the starting point. If you want to fully mask the traffic between your client and"
            echo -e "  the server / relay server, use port 443.  The resuling transmissions will appear as legitimate"
            echo -e "  HTTP(S) traffic to an outside observer.  Masking your traffic in this way will leave an outside"
            echo -e "  observer with no idea that you are not making legitimate connections to a web server."
            echo -e ""
            echo -e "The recommended setup is shown below."
            echo -e ""
            echo -e " ========================================================================================================= "
            echo -e "║                                                                                                         ║"
            echo -e "║   _______________________               _______________________               _______________________   ║"
            echo -e "║  |                       |             |                       |             |                       |  ║"
            echo -e "║  |     Secure shell      |24110   24110|   Stunnel or Chisel   |24110   24110|      Shadowsocks      |  ║"
            echo -e "║  |    ssh -D option      |------------>|       (client)        |<------------|       (client)        |  ║"
            echo -e "║  |      127.0.0.1        |             |       127.0.0.1       |┌            |       127.0.0.1       |  ║"
            echo -e "║  |_______________________|             |_______________________| \           |_______________________|  ║"
            echo -e "║                                                    |443           \                                     ║"
            echo -e "║               _____________________________________|     Self signed cert ok                            ║"
            echo -e "║              |                                                                                          ║"
            echo -e " ==============|========================================================================================== "
            echo -e "               |                                                                                           "
            echo -e "               |                                                                                           "
            echo -e "               |443                                                                                        "
            echo -e "               V                                                                                           "
            echo -e "  Downstream server/relay server"
            echo -e "        (option 1 or 2)"    
            echo -e ""

            case $os_name in
                [Linux]* )
                    # Stunnel


                    # Shadowsocks





                    ;;
                * )
                    while true; do
                        read -rp $'\n'"Are you running this script on a macbook? " yn
                        if [[ -z "${yn}" ]]; then
                            echo -e "Please anser y or n or hit Ctrl+C to exit."
                            continue
                            break
                        fi

                        # Stunnel
                        while true; do
                            read -rp $'\n'"Enter the ip address of the destination for the client (eg 1.1.1.1): " stunnel_destination_ip
                            if [[ -z "${stunnel_destination_ip}" ]]; then
                                echo -e "Please enter the ip address of the destination for the client (eg 1.1.1.1) or hit Ctrl+C to exit."
                                continue
                            fi
                            break
                        done

                        while true; do
                            # 443 if you want to hide your traffic in plain site
                            read -rp $'\n'"Enter the port on $stunnel_rdestination_ip that the relay client will connect to (eg 443): " stunnel_relay_client_out_port
                            if [[ -z "${stunnel_client_out_port}" ]]; then
                                echo -e "Please enter the port on $stunnel_destination_ip that the relay client will connect to (eg 443) or hit Ctrl+C to exit."
                                continue
                            fi
                            break
                        done

                        while true; do
                            read -rp $'\n'"Please enter the name you want to use for the stunnel config file (eg stunnel.conf): " stunnel_conf_name
                            if [[ -z "${stunnel_conf_name}" ]]; then
                                echo -e "Please enter the name you want to use for the shadowsocks json config file (eg shadowsocks.json) or hit Ctrl+C to exit."
                                continue
                            fi
                            break
                        done

                        stunnel_pem_name=$(echo "${stunnel_conf_name/.conf/.pem}")

                        # Generate the self signed key and create the .pem file
                        openssl genrsa -out key.pem 4096
                        openssl req -new -x509 -key key.pem -out cert.pem -days 10095
                        touch $stunnel_pem_name
                        cat key.pem cert.pem >> /opt/homebrew/etc/stunnel/$stunnel_pem_name
                        
                        # Make the stunnel .conf file
                        echo -e "[tunnel]" >> /opt/homebrew/etc/stunnel/$stunnel_conf_name
                        echo -e "client = yes" >> /opt/homebrew/etc/stunnel/$stunnel_conf_name
                        echo -e "cert = /opt/homebrew/etc/stunnel/cert.pem" >> /opt/homebrew/etc/stunnel/$stunnel_conf_name
                        echo -e "key = /opt/homebrew/etc/stunnel/key.pem" >> /opt/homebrew/etc/stunnel/$stunnel_conf_name
                        echo -e "accept = 127.0.0.1:$stunnel_client_only_port" >> /opt/homebrew/etc/stunnel/$stunnel_conf_name
                        echo -e "connect = $stunnel_rdestination_ip:$stunnel_client_out_port" >> /opt/homebrew/etc/stunnel/$stunnel_conf_name

                        brew services restart stunnel

                        # Shadowsocks
                        while true; do
                            read -rp $'\n'"Please enter the name you want to use for the shadowsocks json config file (eg shadowsocks.json): " shadowsocks_json_name
                            if [[ -z "${shadowsocks_json_name}" ]]; then
                                echo -e "Please enter the name you want to use for the shadowsocks json config file (eg shadowsocks.json) or hit Ctrl+C to exit."
                                continue
                            fi
                            break
                        done

                        while true; do
                            read -rp $'\n'"Please enter the server (endpoint) shadowsocks key (eg uKXad4PgTB5A6HBfWbB6mpHyGVrK27Pq): " shadowsocks_key
                            if [[ -z "${shadowsocks_key}" ]]; then
                                echo -e "Please enter the server (endpoint) shadowsocks key (eg uKXad4PgTB5A6HBfWbB6mpHyGVrK27Pq) or hit Ctrl+C to exit."
                                continue
                            fi
                        done

                        sudo mkdir /opt/homebrew/etc/shadowsocks
                        sudo rm -rf /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name || true
                        sudo touch /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name

                        echo -e '{' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "local_address":"127.0.0.1",' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "local_port":21120,' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "comment2":"127.0.0.1:24110 is the local stunnel server",' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "server":"127.0.0.1",' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "server_port":24110,' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "password":"'$shadowsocks_key'",' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "timeout":600,' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '    "method":"aes-256-cfb"' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name
                        echo -e '}' >> /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name

                        ss-local -c /opt/homebrew/etc/shadowsocks/$shadowsocks_json_name start

                        # GUI for macbook
                        # https://github.com/shadowsocks/ShadowsocksX-NG

                        break
                    done;;
            esac

        break;;

        * ) echo -e "Please enter option 1, 2, or 3.";;
    esac
done
