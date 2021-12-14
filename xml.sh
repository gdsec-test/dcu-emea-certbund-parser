#!/bin/bash
### It's part of the uceprotect-parser and can not run as stand-alone.
# This script is being invoked by contact.sh for getting the abuse-contact
# out of the xml-result of the RIPE-API.

read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
    local ret=$?
    TAG_NAME=${ENTITY%% *}
    ATTRIBUTES=${ENTITY#* }
    return $ret
}
parse_dom () {
    if [[ $TAG_NAME = "abuse-contacts" ]] ; then
        eval local $ATTRIBUTES
        echo "$email"
        if [[ $email == "" ]]; then
          exit 1
        fi
    fi
}

while read_dom; do
  parse_dom
done

