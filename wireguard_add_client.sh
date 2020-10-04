#!/bin/bash -l
#===============================================================================
#
#	  FILE: wireguard_add_client.sh
#
#	  USAGE: ./wireguard_add_client.sh --help
#
#	  DESCRIPTION: This script will add a new device to your Wireguard server
#
#   INTERACTIVE OPTIONS: --CONFPATH=/root/wg/ --INTERFACE=wg0 --DOMAIN=my.vpn.com
#                        --DEVICENAME=notebook_work --DNS=8.8.8.8
#                       // optional: -h --help --PUBKEY (if none found)
#
#   SCRIPT OPTIONS: LOGPATH, LOGFILE, ERRORLOG
#
#   AUTHOR: Andre Stemmann
#   CREATED: 20.05.2020 21:42
#   REVISION: v0.1
#===============================================================================

#===============================================================================
# BASE VARIABLES
#===============================================================================

# script vars
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
PROGGI=$(basename "$0")
TODAY=$(date +%Y%m%d%H)

# user vars
LOGPATH="/var/log"
LOGFILE="${LOGPATH}/syslog"
ERRORLOG="${LOGPATH}/syslog"

# ===============================================================================
# BASE FUNCTIONS
# ===============================================================================

function log () {
		echo "$PROGGI ; $(date '+%Y%m%d %H:%M:%S') ; $*" | tee -a "${LOGFILE}"
}

function errorlog () {
		echo "${PROGGI}_ERRORLOG ; $(date '+%Y%m%d %H:%M:%S') ; $*" | tee -a "${ERRORLOG}"
}

function folder () {
		if [ ! -d "$1" ]; then
				mkdir -p "$1"
				log "...Create configfolder structure for $PROGGI original configs $1"
		else
				log "...Folder $1 already exists"
		fi
}

function usercheck () {
		if [[ $UID -ne 0 ]]; then
				errorlog "...Become user root and try again"
				exit 1
		fi
}

function distrocheck () {
		if [[ -r /etc/os-release ]]; then
				. /etc/os-release
				if [[ $ID != ubuntu ]]; then
						errorlog "...Not running an debian based distribution. ID=$ID, VERSION=$VERSION"
				fi
		else
				errorlog "...$PROGGI is not running on a distribution with /etc/os-release available"
				errorlog "...Please create user manually"
				exit 1
		fi
}

function usage () {
		echo "                 Create wireguard client                    "
		echo "------------------------------------------------------------"
		echo "                   Mandatory parameter                      "
		echo "------------------------------------------------------------"
		echo "--CONFPATH=<string>       : e.g. /where/to/store/configs/"
		echo "--INTERFACE=<string>      : e.g. wg0"
		echo "--DEVICENAME=<string>     : e.g. phone"
		echo "--DOMAIN=<string>         : e.g. my.fancy.server.com:51820"
		echo "--DNS=<string>            : e.g. 8.8.8.8 or 10.0.0.1"
		if [ ! -f /etc/wireguard/publickey ]; then
				echo "--PUBKEY=<string>     : The wireguard publickey of your server/peer"
				echo "----------------------------------------"
				echo "-h or --help for more information"
				echo ""
		else
				P_PUBKEY=$(cat /etc/wireguard/publickey)
				echo "----------------------------------------"
				echo "-h or --help for more information"
				echo ""
		fi
}

function printHelp () {
    echo ""
		echo "These are the parameters needed to call the script"
		echo "--------------------------------------------------------------------------------------------"
		echo "--CONFPATH=<string>   : The path were your wireguard client configs will be stored"
		echo "                          e.g. /root/wireguard_clients"
		echo ""
		echo "--INTERFACE=<string>  : The wireguard interface for which you will create the new peer"
		echo "                          e.g. wg0"
		echo ""
		echo "--DEVICENAME=<string> : The name of your device will be the name for your created config"
		echo "                          e.g. phone = /root/wireguard_clients/phone/"
		echo ""
		echo "--DOMAIN=<string>     : The external reachable domain of your wireguard server and his port"
		echo "                          e.g. your.fancy.vpn.server.com:51820"
		echo ""
		echo "--DNS=<string>        : The DNS-Server you are going to use for your new wireguard client"
		echo "                          e.g. 8.8.8.8 or 10.0.0.1 (e.g. if using pihole on the same server)"
		echo ""
		if [ ! -f /etc/wireguard/publickey ]; then
				echo "--PUBKEY=<string>     : The wireguard publickey of your server/peer"
				echo "                          e.g. the content of /etc/wireguard/publickey"
		else
				P_PUBKEY=$(cat /etc/wireguard/publickey)
		fi
}

function parseparams () {
		# catch an empty call
		if [ $# -eq 0 ] ; then
				echo ""
				echo "no parameters are given!"
				echo ""
				usage
				exit 1
		fi

	 # print help text
	 if [ "$1" == "-h" ]; then
			 printHelp
			 exit 0
	 fi
	 if [ "$1" == "--help" ]; then
			 printHelp
			 exit 0
	 fi

	 # parse parameters
	 until [[ ! "$*" ]]; do
			 if [[ ${1:0:2} = '--' ]]; then
					 PAIR="${1:2}"
					 PARAMETER=$(echo "${PAIR%=*}" | tr '[:lower:]' '[:upper:]')
					 eval P_"$PARAMETER"="${PAIR##*=}"
			 fi
			 shift
	 done

	 # parameter re-check
	 if   [ -z "$P_CONFPATH" ] ; then
			 errorlog "...ERROR: please specify the CONFPATH - parameter"
			 errorlog "...exiting script..."
			 exit 1
	 elif [ -z "$P_INTERFACE" ] ; then
			 errorlog "...ERROR: please specify the INTERFACE - parameter"
			 errorlog "...exiting script..."
			 exit 1
	 elif [ -z "$P_DEVICENAME" ] ; then
			 errorlog "...ERROR: please specify the DEVICENAME - parameter"
			 errorlog "...exiting script..."
			 exit 1
	 elif [ -z "$P_DNS" ] ; then
			 errorlog "...ERROR: please specify the DNS - parameter"
			 errorlog "...exiting script..."
			 exit 1
	 elif [ -z "$P_DOMAIN" ] ; then
			 errorlog "...ERROR: please specify the DOMAIN - parameter"
			 errorlog "...exiting script..."
			 exit 1
   else
       PORT=$(echo "$P_DOMAIN"|cut -d":" -f2)
       if [ -z "$PORT" ]; then
            errorlog "...ERROR: please specify the DOMAIN - parameter with"
            errorlog "...a given destination Port, e.g. your.fancy.domain.com:51820"
            exit 1
        else
            STRIPPED_DOMAIN=$(echo "$P_DOMAIN"|cut  -d":" -f1)
            if nc -zvw3 -u "$STRIPPED_DOMAIN" "$PORT";then
                log "...wireguard server is reachable"
            else
                log "...wireguard server is unreachable"
                log "...proceeding anyway..."
            fi
        fi
   fi
	 if [ -z "$P_PUBKEY" ] ; then
			 log "...Searching for existing WG-Server Publickey"
		   if [ ! -f /etc/wireguard/publickey ]; then
            errorlog "ERROR: please specify the PUBKEY - parameter"
			      exit 1
        else
            log "...found WG-Server Publickey"
            P_PUBKEY=$(cat /etc/wireguard/publickey)
       fi
	 fi
}

function service_off () {
		if [ -z "$(wg show "$P_INTERFACE")" ]; then
				log "...wireguard interface $P_INTERFACE already stopped"
		else
				log "...stopping wireguard interface $P_INTERFACE"
				wg-quick down "$P_INTERFACE"
				sleep 3
				if [ -z "$(wg show "$P_INTERFACE")" ]; then
						log "...wireguard interface $P_INTERFACE stopped"
				else
						errorlog "...wireguard interface $P_INTERFACE still running"
						errorlog "...please perform a manual stop and try it again"
						exit 1
				fi
		fi
}

function backup () {
		if cp "/etc/wireguard/$P_INTERFACE.conf" "/etc/wireguard/$P_INTERFACE.conf.BAK_$TODAY"; then
				log "...copied your original $P_INTERFACE.conf to /etc/wireguard/$P_INTERFACE.conf.BAK_$TODAY"
		else
				errorlog "...failed to copy /etc/wireguard/$P_INTERFACE.conf to /etc/wireguard/$P_INTERFACE.conf.BAK_$TODAY"
				exit 1
		fi
}

function create_config () {
		CLIENTCONF=$P_CONFPATH/$P_DEVICENAME.conf
		SERVERCONF=$P_CONFPATH/$P_DEVICENAME.peer
		folder "$P_CONFPATH"
		if [ -f "$CLIENTCONF" ]; then
				errorlog "$PROGGI: $CLIENTCONF already exists"
				exit 2
		fi
		PRIVATEKEY=$(wg genkey)
		PUBLICKEY=$(echo "$PRIVATEKEY" | wg pubkey)
		LASTCLIENT=$(grep -A2 "Peer" "/etc/wireguard/$P_INTERFACE.conf"|tail -1|cut -d"." -f4|cut -d"/" -f1)
		if [ -z "$LASTCLIENT" ]; then
				NEWCLIENT="2"
		else
				NEWCLIENT=$((LASTCLIENT +1))
		fi
		SUBNET=$(grep "24" "/etc/wireguard/$P_INTERFACE.conf"|cut -d"=" -f2|cut -d"/" -f1|cut -d"." -f1-3)
		cat > "$CLIENTCONF" <<END
[Interface]
PrivateKey = $PRIVATEKEY
Address = $SUBNET.$NEWCLIENT/32
DNS = $P_DNS

[Peer]
PublicKey = $P_PUBKEY
Endpoint = $P_DOMAIN
AllowedIPs = 0.0.0.0/0
END

		cat "$CLIENTCONF"
		#rm -f "$SERVERCONF"
		(
		echo '[Peer]'
		echo "PublicKey = $PUBLICKEY"
		echo "AllowedIPs = $SUBNET.$NEWCLIENT/32"
		) > "$SERVERCONF"

		log "...adding $SERVERCONF to wireguard $P_INTERFACE.conf"
		echo "" >> "/etc/wireguard/$P_INTERFACE.conf"
		cat "$SERVERCONF" >> "/etc/wireguard/$P_INTERFACE.conf"
		log "...start wireguard interface $P_INTERFACE with new peer $P_DEVICENAME"
		wg-quick up "$P_INTERFACE"
    log "...restarting firewall"
    service ufw restart
		qrencode -t ansiutf8 < "$CLIENTCONF"
    rm -f "$SERVERCONF"
		exit 0
}

# ===============================================================================
# MAIN RUN
# ===============================================================================
usercheck
distrocheck
parseparams "$@"
while true; do
		read -rp "Do you wish to backup your existing $P_INTERFACE.conf [y/n]" yn
		case $yn in
				[Yy]* )
						service_off
						backup
						create_config
						;;
				[Nn]* )
						service_off
						create_config
						;;
				* ) echo "Please answer yes or no.";;
		esac
done
