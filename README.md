![MineWall Explanation Schema](/Img/minewall.png)

MineWall is a Layer 3 mitigation toolset for protocol specifications like Minecraft. It uses forensic data from multiple providers and experience working with 4 figure player Minecraft networks.

It is mainly targeted at Minecraft servers, or applications having a similar networking footprint as the former. However, it may work well for other applications where proxies are the main tool used for attacks. It is highly recommended to test pre-deployment, and to take proper measures to optimize for your own end use-case.

# A 3 layered approach
The application is comprised of 3 different layers of mitigation, depending on the validity of the source user:
- The whitelist is used for IPs that are already validated as safe users.
- The graylist is based on low risk countries that rarely are the source of bots. The behavior is to limit the connection speed with a permissive ratelimit.
- The graylist (default) behavior is to strongly limit incoming connections via strict ratelimit.

![Cloudflare Radar by Country](/Img/radar-country.png)


# Sources
We believe transparency in our forensic research is key to replicability and the effectiveness of our solution. We've appended our sources below:

https://radar.cloudflare.com/
https://github.com/herrbischoff/country-ip-blocks

# Explanatory Schema

![MineWall Explanation Schema](/Img/drawio.png)