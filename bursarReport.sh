#!/bin/bash
#Bursar Reporting and Transfer Loan Script
#set -e
##Step 1
tenant=$(cat /usr/local/foliodata/tenant)
okapi_url=$(cat /usr/local/foliodata/okapi.url)
okapi_token=$(cat /usr/local/foliodata/okapi.token)


#Step 2
#Get all accounts

echo "GETting first 10000 accounts"

recordtype="accounts?"
limit="limit=10000"
offset="&offset=10000"

apicall=$(curl -w '\n' -X GET -D -H "Accept: application/json" -H "X-Okapi-Tenant: ${tenant}" -H "x-okapi-token: ${okapi_token}" "${okapi_url}/${recordtype}${limit}")
echo $apicall > /usr/local/foliodata/step2_10000Accounts.json

#GETting offset 10000 accounts
echo "getting offset accounts"
apicall=$(curl -w '\n' -X GET -D -H "Accept: application/json" -H "X-Okapi-Tenant: ${tenant}" -H "x-okapi-token: ${okapi_token}" "${okapi_url}/${recordtype}${limit}${offset}")
echo $apicall > /usr/local/foliodata/step2_10000offset.json

#Step 3
##use jq to just get open accounts with balance over $25
echo "jq work for open with balance over 25"
cat /usr/local/foliodata/step2_10000Accounts.json | jq '.accounts[] | select(.status[] == "Open" and .remaining >= 25 and .ownerId == "be3e978d-ff04-4fe4-85f9-7c0557b4e4e4")' > /usr/local/foliodata/step2_first10000filtered.json

cat /usr/local/foliodata/step2_10000offset.json | jq '.accounts[] | select(.status[] == "Open" and .remaining >= 25 and .ownerId == "be3e978d-ff04-4fe4-85f9-7c0557b4e4e4")' > /usr/local/foliodata/step2_offset10000filtered.json

#Step 4
### Send to csv and append both ofthe json files
echo "csv creation"
jq  -r '[.userId, .remaining, .feeFineType, .ownerId, .id] | @csv' /usr/local/foliodata/step2_first10000filtered.json > /usr/local/foliodata/step4_BursarWork.csv
jq  -r '[.userId, .remaining, .feeFineType, .ownerId, .id] | @csv' /usr/local/foliodata/step2_offset10000filtered.json >> /usr/local/foliodata/step4_BursarWork.csv

#Step 5
### Grab userIDs to retrieve username and patrongroups
echo "jq userId for username and patgroup GET"
jq -r '.userId' /usr/local/foliodata/step2_first10000filtered.json > /usr/local/foliodata/step5_BursarUserforUsername
jq -r '.userId' /usr/local/foliodata/step2_offset10000filtered.json >> /usr/local/foliodata/step5_BursarUserforUsername

#Step 6
### Get username and patron group to isolate students
rm /usr/local/foliodata/step6_BursarUsernamePatInfo.csv
echo "GETting username and patGroup"
recordtype="users/"
while read -r uuid;do

uuid=$(sed 's/[^0-9a-z\-]//g' <<< $uuid)

recordtype="users/"
apicall=$(curl -w '\n' -X GET -D -H "Accept: application/json" -H "X-Okapi-Tenant: ${tenant}" -H "x-okapi-token: ${okapi_token}" "${okapi_url}/${recordtype}${uuid}")
echo $apicall | jq -r '[.username, .patronGroup]| @csv' >> /usr/local/foliodata/step6_BursarUsernamePatInfo.csv
done < /usr/local/foliodata/step5_BursarUserforUsername

#Step 7
### compare BursarWork.csv wc-l output to BursarUsernamePatInfo.csv. If match, use paste command. If not, send email of issue
echo "Comparing files for merge"

bwork=$(wc -l < /usr/local/foliodata/step4_BursarWork.csv)
buser=$(wc -l < /usr/local/foliodata/step6_BursarUsernamePatInfo.csv)

if [ $bwork -eq $buser ]; then
   paste -d ',' /usr/local/foliodata/step6_BursarUsernamePatInfo.csv /usr/local/foliodata/step4_BursarWork.csv > /usr/local/foliodata/step7_MergedBursarInfo.csv
else
   mail -s "csv no match" an email address here < /usr/local/foliodata/mismatch.txt
   exit 1
fi

#Step 8
### grep csv by undergraduate and graduate patron type Ids to BursarReport
echo "grepping students out of merged"
grep 6ff1694c-bc16-4f55-ae13-66e8ca9a148e /usr/local/foliodata/step7_MergedBursarInfo.csv > /usr/local/foliodata/step8_StudentBursarInfo.csv
grep 1730ebe8-56f5-4a30-8e97-b6e8d0159f1a /usr/local/foliodata/step7_MergedBursarInfo.csv >> /usr/local/foliodata/step8_StudentBursarInfo.csv 

#test for empty file
if [[ -s /usr/local/foliodata/step8_StudentBursarInfo.csv ]]; then
  echo "students found"
else
 mail -s "no transfers found" an email address here < /usr/local/foliodata/notransfers.txt
 exit 1 
fi
#add IF statement. If step8 csv size > 0, true. else "send no fees eligible for transfer" email and quit 
#Step 9
### add column headers
echo "adding columns"
sed -i '1s/^/"mnumber","patrontype","userid","amount","fee type", "ownerId", "accountId"\n/' /usr/local/foliodata/step8_StudentBursarInfo.csv

#Step 10
### cut columns not needed by Bursar
echo "remaining columns bursar doesn't need"
cut -d, -f1,4 < /usr/local/foliodata/step8_StudentBursarInfo.csv > /usr/local/foliodata/BursarReport.csv 

#Step 11
### Batch transfer work in FOLIO, source out to transfer scripting
###1 cut accountids out of studenbursar file to flatfile
cut -d, -f7 < /usr/local/foliodata/step8_StudentBursarInfo.csv > /usr/local/foliodata/accountids 
##ensure no blank lines in accountids
sed -i '/^$/d' /usr/local/foliodata/accountids
###2
##3 run jsonify script sending the body for post work for each fine/fee
source /usr/local/sbin/get_bursarTransJsonify.sh
echo "Getting Balances and Creating JSON files"
##4 run transfer bulk script
source /usr/local/sbin/post_finesTransfers.sh
echo "Running Bulk Transfer in FOLIO"
#Step 12
### email report
echo "email report"
echo "See attached. Needs pivot table by username and index/account information" | mutt -s "Report for transfer of fines to Bursar" -b an email address here -a /usr/local/foliodata/BursarReport.csv

