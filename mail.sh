#!/bin/bash
LOG_FILE=/var/log/dcumail.log
FILE=${1}.txt
MODULE=${1}
IPLIST=${1}.iplist
STAGING=false
SENT=0
SKIPPED=0

if [[ ${2} == "stg" ]]; then
  STAGING=true
fi
if [[ ${2} && ${2} != "stg" ]]; then
  echo "second parameter has to be empty or 'stg'"
  exit 25
fi

. .db.conf

function write_log()
{
    while read text; do
        LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
        if [ "$LOG_FILE" == "" ]; then
            echo "$LOGTIME: $text"
        else
            if [ ! -f $LOG_FILE ]; then
                echo "ERROR: $LOG_FILE does not exit. Ask your admin for creating $LOG_FILE. Exiting!"
                exit 127
            fi
            echo "$LOGTIME: $(whoami) - $text" | tee -a $LOG_FILE
        fi
    done
}

function validateIP()
{
         local ip=$1
         local stat=1
         if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                OIFS=$IFS
                IFS='.'
                ip=($ip)
                IFS=$OIFS
                [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
                && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
                stat=$?
        fi
        return $stat
}

function arpa()
# split the ip address and provide the reverted in-addr.arpa-name
{
  local ip=$1
  if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    arpaaddr="${ip[2]}.${ip[1]}.${ip[0]}.in-addr.arpa"
  fi
  echo "$arpaaddr"
}


function send_mail()
{
local IP=${1}
SUBJECT="$(grep $MODULE mail_templates/subject.txt | cut -d'=' -f2) - $IP"
DATESTR=$(LANG=C date +"%a, %d %b %Y %k:%M:%S %z")

ipdb=$(mysql -B -s -h $MY_SERVER -u $MY_USER -p$MY_PWD -e "SELECT count(ip_address) FROM $MY_DB.ip WHERE ip_address = '$IP';")
if [[ $ipdb -eq 0 ]]; then
  # We have not found the ip on intergenia database, so switching to HostEurope
  RCPT="abuse@hosteurope.de"
else # we found the ip at intergenia, so we have to be more specific for whitelabel brands
  CMP=$(mysql -B -s -h $MY_SERVER -u $MY_USER -p$MY_PWD -e "SELECT company_id FROM $MY_DB.ip WHERE ip_address = '$IP';")
  case $CMP in
    002)
      # plusserver
      RCPT="abuse@hosteurope.de"
      ;;
    003|006)
      # BSB/HSI
      RCPT="ig-abuse-72@heg.com"
      ;;
    023)
      # 123reg
      RCPT="abuse@123-reg.co.uk"
      ;;
    024)
      # Heart Internet
      RCPT="abuse@heartinternet.co.uk"
      ;;
    *)
      # fallback
      RCPT="abuse@hosteurope.de"
      ;;
  esac
fi

if [[ "$RCPT" = "ig-abuse-72@heg.com" ]]; then
  # We are here, because ip has been determined as origin intergenia brand.
  #  So, we have to sort the sanction more specific by chosen module
  case $MODULE in
    malware)
      RCPT="ig-abuse-24@heg.com"
      ;;
    emotet)
      RCPT="ig-abuse-72@heg.com"
      ;;
    *)
      RCPT="ig-abuse-info@heg.com"
      ;;
  esac
fi

if [[ "$RCPT" = "abuse@hosteurope.de" ]]; then
# We ended up with a hosteurope-address as fallback, so try to determine more specific
  RIPERCPT=$(./contact.sh $PIP)
  case $RIPERCPT in
    abuse@godaddy.com)
      RCPT="$RIPERCPT"
      ;;
    lir@heartinternet.uk)
      RCPT="abuse@heartinternet.co.uk"
      ;;
    abuse@paragon.co.uk)
      RCPT="$RIPERCPT"
      ;;
    abuse@ispgateway.de)
      RCPT="$RIPERCPT"
      ;;
    abuse@hosteurope.es)
      RCPT="$RIPERCPT"
      ;;
    *)
      RCPT="abuse@hosteurope.de"
      ;;
  esac
fi

if [[ "$RCPT" = "abuse@hosteurope.de" ]]; then
# If RCPT is still HostEurope, we try to determine other responsibility from
#  the SOA record
  PTR=$(arpa $PIP)
  PNS=$(dig in soa $PTR +short | awk '{print $1}')
  case "$PNS" in
    ns1.velia.net.)
      RCPT="abuse@velia.net"
      ;;
    cns1.secureserver.net.)
      RCPT="abuse@godaddy.com"
      ;;
    ns.namespace4you.de.)
      RCPT="abuse@ispgateway.de"
      ;;
  esac
fi

# if we are on staging process, always send to the team
if $STAGING; then
  echo "$PIP would be sent to: $RCPT" # where should the mail go to?
  RCPT="abuse-mgmt@hosteurope.de" # set team address in case of bugs
  return 42 # jump out to avoid sending the mail
fi

MAIL_COMMAND="/usr/sbin/exim4 -bm $RCPT"
  cat << EOF | $MAIL_COMMAND
Subject: $SUBJECT
From: "Abuse Department" <abuse@heg.com>
To: $RCPT
Content-Type: text/plain; charset=utf-8
Mime-Version: 1.0
X-Mailer: Oops-mailer v0.1 by www.kernel-oops.de
Date: $DATESTR

$(echo "$IP")

$(cat mail_templates/$MODULE.txt)
$(echo $input)

EOF
}

echo "START $0 $* by $(whoami)" | write_log
if [ ! -f "mail_templates/$FILE" ]; then
  echo "$FILE is not a valid mail template. Exiting!"
  exit 2
fi

if [ ! -f "$IPLIST" ]; then
  echo "$IPLIST is missing. Nothing to do. Exiting!"
  exit 3
fi

sed -i 's/ /_/g' "$IPLIST"
for input in $(cat "$IPLIST"); do
  PIP=$(echo "$input" | tr -d '"' | sed 's/,/ /g' | awk '{print $2}')
  if validateIP "$PIP"; then
    if ! send_mail "$PIP"; then
      SKIPPED=$(( SKIPPED + 1 ))
    else
      echo "$PIP reported to $RCPT" | write_log
      SENT=$(( SENT + 1 ))
    fi
    sleep 6
  else
    echo "$PIP seems not to be a valid IPv4 address. Skip."
  fi
done

if ! $STAGING; then
# on live, the iplist should be removed after processing - but not on staging
  rm "$IPLIST"
fi

echo "Job summary - sent: $SENT - skipped: $SKIPPED" | write_log
echo "END $0 $* by $(whoami)" | write_log
exit 0

