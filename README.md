Initial linux (ubuntu) server setup script.

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
