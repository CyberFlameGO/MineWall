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
apt -y -qq install curl iptables-persistent ipset conntrack > /dev/null
yum -y install curl iptables-service ipset-service conntrack > /dev/null
echo "Installed required depends."
# The port you want to protect. for ranges, use FROM:TO
protect_port=25565


# Max graylisted connections per second. This can be higher, and ensures an attack won't be too high for the second pass firewall.
graylist_verified=8
graylist_unverified=7
graylist_concurrent=2

# How many bytes before sending the player to the remote checker to check for info. Please don't change if you don't
# know what you're doing as you may get yourself locked out of the API.
#
checker_minconn=26214400

# MISC. THESE VALUES MAY CHANGE IN THE FUTURE
target_chain=DOCKER

country_list="https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/"
safety_list="https://api.entryrise.com/minewall/"

wgetd="wget -q -c --retry-connrefused -t 0"

echo "Preparing clean iptables configuration"
iptables -N MineWall
iptables -F MineWall

echo "Preparing clean ipset configuration"
ipset destroy mw_blacklist
ipset destroy mw_graylist
ipset destroy mw_whitelist
ipset destroy mw_checklist

ipset -N -! mw_blacklist hash:net maxelem 100000 timeout 3600
ipset -N -! mw_graylist hash:net maxelem 100000
ipset -N -! mw_whitelist hash:net maxelem 100000
ipset -N -! mw_checklist hash:net maxelem 30 timeout 300

 
echo "Generating whitelist for the firewall..."
for ip in $(curl -L $safety_list/{wireless,residential,business}.iplist); do
  ipset -A mw_whitelist $ip
done
 # Create the graylist of safer countries. It's really important for the base check.
 echo "Generating graylist for the firewall..."
 for ip in $(curl -L $country_list/{gb,de,fr,ro}.cidr); do
  ipset -A mw_graylist $ip
 done

echo "Generating blacklist for firewall."
for ip in $(curl -L $safety_list/{others}.iplist); do
  ipset -A mw_blacklist $ip
done
#
# The blacklist makes sure any "smart bots" are blocked in time on your server after a while.
 
# Off the table just allow the whitelisted users and drop the blacklisted ones.
iptables -A MineWall -p tcp --dport $protect_port -m set --match-set mw_whitelist src -j ACCEPT
iptables -A MineWall -p tcp --dport $protect_port -m set --match-set mw_blacklist src -j DROP

iptables -A MineWall -p tcp --dport $protect_port --syn -m connlimit --connlimit-above $graylist_concurrent -j DROP

iptables -A MineWall -p tcp --dport $protect_port --syn -m limit --limit $graylist_unverified/s -j ACCEPT
iptables -A MineWall -p tcp --dport $protect_port --syn -m set --match-set mw_graylist src -m limit --limit $graylist_verified/s -j ACCEPT

iptables -A MineWall -p tcp --dport $protect_port --syn -j DROP

# Add MineWall to iptables and remove it just in case it is already there.
iptables -D $target_chain -p tcp -j MineWall
iptables -I $target_chain -p tcp -j MineWall

# REDHAT BASED
iptables-save > /etc/sysconfig/iptables
# DEBIAN BASED
iptables-save > /etc/iptables/rules.v4
# Having 2 files is not ideal but not an issue
# TODO: Check OS and apply specific commands only.

echo "Firewall applied successfully. Please add the whitelister script to crontab (each minute) to finish installation"
