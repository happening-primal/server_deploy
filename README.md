Initial linux (ubuntu) server setup scripts.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

deploy.sh

   What does this script do?

   1.  Perform an initial update.
   2.  Install some recommended software
      a.  nano
      b.  wget
      c.  curl
      d.  libpam-google-authenticator
      e.  tmux
      f.  bleachbit
      g.  iptables-persistent
      h.  fail2ban
   3.  Remove some unused or unsafe applications
      a.  postfix
      b.  telnet
      c.  tcpdump
      d.  nmap-ncat
      e.  wpa_supplicant
      f.  avahi-deamon
   4. Add a cron job to run bleachbit monthly
   5. Add some important firewall rules to limit ddos attacks and dns amplification attacks
   6. Create a new user to be used from here on out rather than using the root user
   7. Change the root users password and then lock the root account

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

install.sh

   This script was created from instructions detailed on Wolfgan's Channel (youtube)
   How to Make Your Own VPN (And Why You Would Want to) - https://youtu.be/gxpX_mubz2A
   

    What does this script do?
    
    1.  Updates the system
    2.  Copies ssh keys - you can see here for instructions on createing ssh keys on your system - https://www.ssh.com/academy/ssh/copy-id
    3.  Change the ssh port (if you want to)
    4.  Harden ssh config by requiring ssh key, prohibiting root login, prohibiting password login
    5.  Sets up TOTP login for ssh using google-authenticator
    6.  Ensures firewall rules are in place to limit ddos and dns amplification attacks
    7.  Installs docker
    8.  Cleans up the system using bleachbit
    
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

