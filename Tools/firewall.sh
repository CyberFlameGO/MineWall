#!/bin/bash
#
#  __  __ _         __          __   _ _ 
# |  \/  (_) by     \ \ENTRYRISE /  | | |
# | \  / |_ _ __   __\ \  /\  / /_ _| | |
# | |\/| | | '_ \ / _ \ \/  \/ / _` | | |
# | |  | | | | | |  __/\  /\  / (_| | | |
# |_|  |_|_|_| |_|\___| \/  \/ \__,_|_|_|
#
# Minewall provides a firewall-based implementation for mitigating attacks in Minecraft.
# Unlike layer 7 antibots, MineWall uses a novel approach combining both Layer 3 checks with Layer 7 traffic analysis and
# categorization to provide a better, more accurate solution for finding, and tackling bots
#
#
# FAQ:
#
# 1) How does the whitelisting system work? Usually, volumetric attacks rely on dumb bots that are not capable of joining your
#    subserver or taking actions that normally your players would take. By leveraging this activity, this antibot can automatically
#    whitelist your actual players (or highly probable players) while leaving bots blocked.
#
# 2) How does the country whitelist system work? By using the fact that most bots come from high risk countries, we can often run
#    statistical decisions to help us allow a majority of players while blocking high risk ones. This is highly useful in production,
#    and can have great effects on the effectiveness of the firewall.
#
# 3) How does the cloud system work? Cloudflare allows us to host a decentralized platform to optionally enhance the way that the firewall
#    works with self updated proxy lists. It automatically pulls proxies from multiple proxy lists, prepares them from blocking and provides
#    them in an ipset compatible format.
#
#    (!): You can also set it to share your found proxies so they can be blocked later mainstream.

echo "Installing required dependencies: curl, iptables-persistent, ipset"
apt -y -qq install curl iptables-persistent ipset > /dev/null
echo "Installed required depends."
# The port you want to protect. for ranges, use FROM:TO
protect_port=25565


# Max graylisted connections per second. This can be higher, and ensures an attack won't be too high for the second pass firewall.
graylist_verified=100
graylist_unverified=15

# MISC. THESE VALUES MAY CHANGE IN THE FUTURE


country-list="https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/"

wgetd="wget -q -c --retry-connrefused -t 0"

echo "Preparing clean iptables configuration"
iptables -N MineWall
iptables -F MineWall

echo "Preparing clean ipset configuration"
ipset -F mw_blacklist
ipset -F mw_graylist
ipset -F mw_whitelist
ipset -N -! mw_blacklist hash:net maxelem 1500000 timeout $timeout
ipset -N -! mw_graylist hash:net maxelem 10000
ipset -N -! mw_whitelist hash:net maxelem 10000


 # Create the graylist of safer countries. It's really important for the base check.
 echo "Generating graylist for the firewall..."
 for ip in $(curl $country-list/{ro,ua,tr,nl,de}.cidr); do
  ipset -A mw_graylist $ip
 done
 echo "Graylist finished generating."
 
# Off the table just allow the whitelisted users and drop the blacklisted ones.
$iptables -A MineWall -p tcp --dport $protect_port -m set --match-set mw_whitelist src -j ACCEPT
$iptables -A MineWall -p tcp --dport $protect_port -m set --match-set mw_blacklist src -j DROP

$iptables -A MineWall -p tcp --dport $protect_port --syn -m set --match-set mw_graylist -m limit --limit $graylist_verified/s src -j ACCEPT
$iptables -A MineWall -p tcp --dport $protect_port --syn -m limit --limit $graylist_unverified/s -j ACCEPT
$iptables -A MineWall -p tcp --dport $protect_port --syn -j DROP

# Add MineWall to iptables and remove it just in case it is already there.
$iptables -D INPUT -p tcp -j MineWall
$iptables -A INPUT -p tcp -j MineWall
echo "Firewall applied successfully."