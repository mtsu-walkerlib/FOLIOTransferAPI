#!/bin/bash
#Script using the accountids file to create the get url with fee/fine information. For each account ID, a json file is created with necessary waive information for the api push call. Each file is named for the account ID. Push api request will use accountids file and off each account ID select appropriate file to make the transfer or waiver go through. 
# 
tenant=$(cat /usr/local/foliodata/tenant)
okapi_url=$(cat /usr/local/foliodata/okapi.url)
okapi_token=$(cat /usr/local/foliodata/okapi.token)

rm /usr/local/foliodata/bursartransferfiles/*
#remove column name line of ids file
echo -e "$(sed '1d' /usr/local/foliodata/accountids)\n" > /usr/local/foliodata/accountids
#read each account ID line
while read -r accountids;do

accountids=$(sed 's/[^0-9a-z\-]//g' <<< $accountids)

recordtype="feefineactions"
query="?query=(accountId=="${accountids}")"
jsonfile="${accountids}.json"

#echo "${okapi_url}/${recordtype}${query}"

apicall=$(curl -s -w '\n' -X GET -D -H "Accept: application/json" -H "X-Okapi-Tenant: ${tenant}" -H "x-okapi-token: ${okapi_token}" "${okapi_url}/${recordtype}${query}")

#for loop. for each account id, make appropriate json file with the .balance used as the amount key for the waive script
for accountid in $accountids 
do
echo $apicall | jq '.feefineactions[] | {amount: .balance, comments: "Bursar Transfer", "paymentMethod" : "Bursar","notifyPatron" : false, "servicePointId" : "176e2f00-aefd-41ad-a79d-fa787dab1776", "userName" : "walker"}' > /usr/local/foliodata/bursartransferfiles/$jsonfile
done
done < /usr/local/foliodata/accountids
