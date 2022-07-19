#!/bin/bash
echo ""

if [ $# -eq 0 ]
  then echo "Script Usage : $0 <domain_name>"; exit 1
fi

domain=$1

# Creating directories
if [ ! -d $domain ]
  then mkdir $domain
fi

if [ ! -d $domain/assetfinder ]
  then mkdir $domain/assetfinder
fi

if [ ! -d $domain/amass ]
  then mkdir $domain/amass
fi

# assetfinder
echo "[+] Getting sub-domains for [$domain] using Assetfinder ...."
assetfinder $domain | grep $domain | sort > ./$domain/assetfinder/sub_domains.txt
count1=$(wc -l ./$domain/assetfinder/sub_domains.txt | awk '{ print $1 }')
echo "    Added $count1 sub-domains"

# amass		(set use_amass=0 to disable)
use_amass=1
echo ""
echo "[+] Getting sub-domains for [$domain] using Amass ...."
if [ $use_amass -eq 0 ]
then
    echo "    [Amass is DISABLED]";
    echo -n "" > ./$domain/amass/sub_domains.txt;
else
    echo "    (could take a few minutes)";
    amass enum -d $domain 2>/dev/null | sort > ./$domain/amass/sub_domains.txt;
fi
count2=$(wc -l ./$domain/amass/sub_domains.txt | awk '{ print $1 }')
echo "    Added $count2 sub-domains"

# Remove duplicates
echo ""
echo "[-] Removing duplicate entries ...."
cat ./$domain/assetfinder/sub_domains.txt ./$domain/amass/sub_domains.txt | sort -u > ./$domain/sub_domains.txt
count=$(($count1+$count2))
total=$(wc -l ./$domain/sub_domains.txt | awk '{ print $1 }')
echo "    $(($count-$total)) duplicates found"

echo ""
echo "File : ./$domain/sub_domains.txt"
echo "Total : $total sub-domains"

# Check for active / alive sub-domains using Httprobe
echo ""
echo "[*] Probing for Active sub-domains (http & https) ...."
cat ./$domain/sub_domains.txt | httprobe -s -p http:80 | sort -u > ./$domain/active.txt
cat ./$domain/sub_domains.txt | httprobe -s -p https:443 | sort -u >> ./$domain/active.txt
cat ./$domain/active.txt | grep "http://" | cut -d: -f2 | cut -d/ -f3 | sort > ./$domain/active_http.txt
cat ./$domain/active.txt | grep "https://" | cut -d: -f2 | cut -d/ -f3 | sort > ./$domain/active_https.txt
cat ./$domain/active_http.txt ./$domain/active_https.txt | sort -u > ./$domain/active.txt
active_http=$(wc -l ./$domain/active_http.txt | awk '{ print $1 }')
active_https=$(wc -l ./$domain/active_https.txt | awk '{ print $1 }')

echo ""
echo "File : ./$domain/active.txt"
echo "File : ./$domain/active_http.txt  | $active_http Active HTTP sub-domains"
echo "File : ./$domain/active_https.txt | $active_https Active HTTPS sub-domains"

# Grab screenshots using GoWitness
if [ -d ./$domain/screenshots ]
  then rm -rf ./$domain/screenshots
fi
echo ""
echo "[*] Grabbing Screenshots of Active sub-domains (http & https) ...."
echo "    Approx. wait time : $((2*($active_http + $active_https))) seconds"
cat ./$domain/active_http.txt | awk '{print "http://"$0}' | gowitness -D ./$domain/gowitness.sqlite3 -P ./$domain/screenshots --delay 2 file -f - 2>/dev/null
cat ./$domain/active_https.txt | awk '{print "https://"$0}' | gowitness -D ./$domain/gowitness.sqlite3 -P ./$domain/screenshots --delay 2 file -f - 2>/dev/null
screenshots=$(ls ./$domain/screenshots | wc -l)
echo "    $screenshots screenshots stored in Directory : ./$domain/screenshots"

exit 0
