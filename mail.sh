#!/bin/bash
FILE=${1}.txt
MODULE=${1}
IPLIST=${1}.iplist
STAGING=false
if [[ ${2} == "stg" ]]; then
  STAGING=true
fi

. .db.conf

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

function send_mail()
{
local IP=${1}
SUBJECT="$(grep $MODULE mail_templates/subject.txt | cut -d'=' -f2) - $IP"
DATESTR=$(LANG=C date +"%a, %d %b %Y %k:%M:%S %z")
RCPT="ig-abuse-info@heg.com"
if $STAGING; then
  RCPT="abuse-mgmt@hosteurope.de"
fi
if [ "$MODULE" = "malware" ]; then
  RCPT="ig-abuse-24@heg.com"
fi
if [ "$MODULE" = "malware" ] && $STAGING; then
  RCPT="abuse-mgmt@hosteurope.de"
fi
ipdb=$(mysql -B -s -h $MY_SERVER -u $MY_USER -p$MY_PWD -e "SELECT count(ip_address) FROM $MY_DB.ip WHERE ip_address = '$IP';")
if [[ $ipdb -eq 0 ]]; then
  echo "$IP not found in Database. Skipping"
  return 7
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

"asn","ip","timestamp"
$(echo $input)

EOF
}

if [ ! -f "mail_templates/$FILE" ]; then
  echo "$FILE is not a valid mail template. Exiting!"
  exit 2
fi

if [ ! -f "$IPLIST" ]; then
  echo "$IPLIST is missing. Nothing to do. Exiting!"
  exit 3
fi

sed -i 's/ /_/g' "$IPLIST"
for input in $(cat $IPLIST); do
  PIP=$(echo $input | tr -d '"' | sed 's/,/ /g' | awk '{print $2}')
  if validateIP $PIP; then
    if ! send_mail "$PIP"; then
      echo "$PIP has been skipped."
    else
      echo "$PIP reported to $RCPT"
    fi
    sleep 6
  else
    echo "$PIP seems not to be a valid IPv4 address. Skip."
  fi
done

