#!/bin/bash

# (optional) You might need to set your PATH variable at the top here
# depending on how you run this script
#PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Hosted Zone ID e.g. BJBK35SKMM9OE
ZONEID="enter zone id here"

# The CNAME you want to update e.g. hello.example.com
RECORDSET="enter cname here"

# More advanced options below
# The Time-To-Live of this recordset
TTL=300
# Change this if you want
COMMENT="Auto updating @ `date`"
# Change to AAAA if using an IPv6 address
TYPE="AAAA"

# Get the external IP address from OpenDNS (more reliable than other providers)
IP=`curl -s "http://v6.ipv6-test.com/api/myip.php"`


# Get current dir
# (from http://stackoverflow.com/a/246128/920350)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGFILE="$DIR/updateroute53v6.log"
IPFILE="$DIR/updateroute53v6.ip"


# Check if the IP has changed
if [ ! -f "$IPFILE" ]
    then
    touch "$IPFILE"
fi

if grep -Fxq "$IP" "$IPFILE"; then
    # code if found
    echo "`date`: IP is still $IP. Exiting" >> "$LOGFILE"
    exit 0
else
    echo "`date`: IP has changed to $IP" >> "$LOGFILE"
    # Fill a temp file with valid JSON
    TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

    # Update the Hosted Zone record
    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://"$TMPFILE" \
        --query '[ChangeInfo.Comment, ChangeInfo.Id, ChangeInfo.Status, ChangeInfo.SubmittedAt]' \
        --output text >> "$LOGFILE"
    echo "" >> "$LOGFILE"

    # Clean up
    rm $TMPFILE
fi

# All Done - cache the IP address for next time
echo "$IP" > "$IPFILE"