#!/bin/bash

safety_list="https://api.entryrise.com/minewall/"

# Make sure to change protect port to your own protect port.
# $6 > X means the packet count before validating user.
# Recommending a value for X between 10k (~100 seconds) and 50k (~500 seconds) for validation)
command_check=$(conntrack -L | awk '{if ($6 > 300000 && $4 == "ESTABLISHED" && $8 == "dport=20003") print $5}');
#command_check=$(conntrack -L | awk '{if ($6 > PACKETS_TO_WHITELIST && $4 == "CONNECTION FULLY RUNNING" && $8 == "dport=PORT OF SERVER") print $5}');

echo "Updating blacklist for firewall."
for ip in $(curl -L $safety_list/{others}.iplist); do
  ipset -A mw_blacklist $ip
done

echo "Updating whitelist for the firewall."
for ip in $(curl -L $safety_list/{wireless,residential,business}.iplist); do
  ipset -A mw_whitelist $ip
done

echo "Sending actual players to remote database."
for data in $command_check; do
  if [[ $data == "src="* ]]
  then
    curl -X POST -d 'ip='$(echo $data | cut -c 5-) $safety_list
  fi
done



echo "Done"


#
#
#
#
#
# PUT THIS ON A CRONTAB TO RUN EACH 5 MINUTES!!!!