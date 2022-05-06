#!/bin/bash

#post API for transfer fee/fines in batch. 
# 
tenant=$(cat /usr/local/foliodata/tenant)
okapi_url=$(cat /usr/local/foliodata/okapi.url)
okapi_token=$(cat /usr/local/foliodata/okapi.token)
#read each line of accountids files
while read -r accountids;do

accountids=$(sed 's/[^0-9a-z\-]//g' <<< $accountids)
recordtype="accounts"
finedata="/usr/local/foliodata/bursartransferfiles/${accountids}.json"

#echo $finedata

#echo "${okapi_url}/${recordtype}/${accountids}/transfer"

apicall=$(curl -s -w --location --request POST "${okapi_url}/${recordtype}/${accountids}/transfer" --header "x-okapi-tenant:${tenant}" --header "x-okapi-token: ${okapi_token}" --header "Content-type: application/json" --data @${finedata})

echo $apicall

done < /usr/local/foliodata/accountids

