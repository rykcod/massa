# Massa node + Massa-guard #
**Last build for Massa testnet Episode 11 release 11.3**

![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

## [DESCRIPTION] ##
### [FEATURES] ###
Build a massa-node container wich include some automation features

This image include a script named "**/massa-guard/massa-guard.sh**" to:
- [AUTOBUY/AUTOSELL]
  - Autobuy 1 roll when your node failed and lost his "Active rolls"
  - Autobuy X rolls when your MAS amount greater than 200 MAS and if "Active rolls" dont exceed "TARGET_ROLL_AMOUNT" set in /massa_mount/config/config.ini (If set)
  - Autosell X rolls when "Active rolls" exceed "TARGET_ROLL_AMOUNT" set in /massa_mount/config/config.ini (If set)
- [BOOTSTRAPFINDER]
  - Auto refresh massa online bootstrap list with connected node
  - Filter to only add node which have TCP port 31244&31245 reachable
- [WATCHDOG]
  - Restart node when hang
  - Restart node when ram consumption exceed 90%
  - You host your node under a dynamical IP? massa-guard will watch IP change and update your config.toml and push IP updates to massabot.
  - Push public IP or public IP change to massabot (Need to set discord token in /massa_mount/config/config.ini)
  - Logs his actions over /massa_mount/logs/ and backup node logs before restart if necessary
  - Autoget MAS faucet on Discord 1 time by day (Need to set discord token in /massa_mount/config/config.ini)
- [STARTING]
  - Massa-guard will create wallet + nodekey + stacke privkey
  - Massa-create create your config.toml with your public IP.

### [RELEASE NOTES] ###
- 20220613 - Testnet 11 - v11.3 Ready!
- 20220610 - Testnet 11 - v11.2 Ready!
- 20220610 - Testnet 11 - v11.1 Ready!
- 20220609 - Testnet 11 Ready!
- 20220603 - Add dynamical public IP feature to check IP change and then refresh config.toml --> restart node to reload config.toml --> push new IP to massabot
- 20220520 - Add public IP of the node in config.toml file if ref config.toml don't exist in mountpoint
- 20220519 - One time by day, check if nodes in bootstrap list are responsives on their TCP port 31244 & 31245, or mark it as unreachable and remove it from bootstrap list
- 20220517 - ADD target roll amount feature **/!\ If you already have the "/massa_mount/config/config.ini" file, please add manually ADD this variable ''TARGET_ROLL_AMOUNT="NULL"''**
- 20220511 - Clean code
- 20220508 - Update image to v10.1
- 20220508 - ADD node Ram overload feature **/!\ If you already have the "/massa_mount/config/config.ini" file, please add manually ADD this variable ''NODE_MAX_RAM=90''**
- 20220508 - Solve issue wallet creation if missing
- 20220507 - Solve issue bootstrapper feeding for ipv6 node since testnet 10. Now add stay available for ipv4 node but add skip ipv6 nodes.

## [HOWTO] ##
### [SETUP] ###
__STEP 1:__
Mount a folder to the /massa_mount path on container and store your wallet /nodekey/stacking_key/config.toml if you have it:
- wallet.dat
- config.toml
- node_privkey.key
- staking_keys.json

/!\ If don't have this file, leave your folder empty, massa-guard will create a wallet and node key and automaticaly stake wallet for you. This files will be backup on your mount point by massa-guard.

/!\ __User of one release before the 20220508?__ For the node Ram overload feature **/!\ If you already have the ''/massa_mount/config/config.ini'' file, please add manually ADD this entry ''NODE_MAX_RAM=90'' and ''DYN_PUB_IP=0''in your config file**

### Usecase Example ###
  * Container creation:
```console
docker run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 -p 33035:33035 --name massa-node rykcod/massa
```
  * To connect to your container:
```console
docker exec -it massa-node /bin/bash
```
  * Connect to massa-client after container connection:
```console
screen -x massa-client
```
  * Exit screen or container:
```console
ctrl+a+d
```
  
__[OPTION]STEP 2: to use ping faucet feature__
  * Set your ''DISCORD_TOKEN'' value in /massa_mount/config/config.ini to enable "Autoget MAS faucet" feature and autoregistration node and IP to massabot
  * Set your ''DYN_PUB_IP'' value in /massa_mount/config/config.ini to enable dynamical IP management
  * Set your ''TARGET_ROLL_AMOUNT'' value in /massa_mount/config/config.ini to enable roll amount target to stake for your node

__STEP 3:__
/!\ If you don't set ''DISCORD_TOKEN'' value in /massa_mount/config/config.ini, remember to register your node to the testnet program on Discord
  * Go to Discord https://discord.com/channels/828270821042159636/872395473493839913 and follow inscructions.

## [HELP] ##
- Massa client is running over a "screen" named "massa-client"
- Massa node is running over a "screen" named "massa-node"
- To get your discord token, refer to https://shufflegazine.com/get-discord-token/

### [HELP - Easy beginner way for IPV6 usage] ###
- Create or edit your host /etc/docker/daemon.json to add:
```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00::/80"
}
```
- Restart docker service to reload config setting
- Allow MASQUERADE for ipv6
```console
ip6tables -t nat -A POSTROUTING -s fd00::/80 ! -o docker0 -j MASQUERADE
```
- Create a container which dynamicaly edit your iptables rules for port redirection
```console
docker run -d --restart=always -v /var/run/docker.sock:/var/run/docker.sock:ro --cap-drop=ALL --cap-add=NET_RAW --cap-add=NET_ADMIN --cap-add=SYS_MODULE --net=host --name ipv6nat robbertkl/ipv6nat
```

For more informations and sources - https://github.com/rykcod/massa/

## [VIDEO TUTORIAL][FR] ##
https://youtu.be/IzeRq43DBSQ

## CONTRIB ##
Thanks to:
- **Dockyr** because it's my main nickname
- **GGCOM** & **GNOMUZ** for help
- **Danakane**
