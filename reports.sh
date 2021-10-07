#!/bin/bash
# 
# This file is part of the certbund-parser project by abuse-emea-org@godaddy.com
#  and can be found at https://github.com/gdcorp-infosec/dcu-emea-certbund-parser
# Place this file at /usr/local/bin/ and make sure, it's executable.
# Intentionally after monthly logrotation the log of the previous month is being
#  analyzed for how many mails have been reported and which GoDaddy ip addresses
#  are the most offending onces. Report is being mailed to $RCPT.

RCPT="abuse-mgmt@hosteurope.de"

COUNT=$(zgrep -c reported /var/log/dcumail.log.1.gz)
TOP=$(zgrep reported /var/log/dcumail.log.1.gz | awk '{print $5}' | sort -h | uniq -c | sort -n | tail -n 10)

echo "Reportete CERTBund Issues: $COUNT

Top 10 Abusers:
$TOP" | mail -E -s "CERTBund Statistik" "$RCPT"

exit 0
