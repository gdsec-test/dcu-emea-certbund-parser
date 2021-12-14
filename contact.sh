#!/usr/bin/env bash
### This script is part of the uceprotect-parser, but can also be called as
# stand-alone software together with the xml.sh to get the registered abuse
# contact for ip address at the RIPE RIR database.
# Expected parameter is an IPv4-address.

IP=${1}
if ! curl 2>/dev/null https://rest.db.ripe.net/abuse-contact/${1} | ./xml.sh 2>/dev/null; then
 echo ""
fi
