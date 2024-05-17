# Massa node + Massa-guard #
**Last build for Massa Mainnet 2.1**

![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

## [DESCRIPTION] ##
### [FEATURES] ###
Build a massa-node container wich include some automation features from a community image with Massalabs agreements

This image include a script named "**/massa-guard/massa-guard.sh**" to:
- [GENERAL]
  - Enable/Disable all massa-guard features (Except keys creations) with the "MASSAGUARD" setting in config.ini
  - Link node storage files to massa_mount
- [AUTOBUY/AUTOSELL]
  - Autobuy 1 roll when your node failed and lost his "Active rolls".
  - Autobuy X rolls when your MAS amount greater than 100 MAS and if "Active rolls" dont exceed "TARGET_ROLL_AMOUNT", if value set in /massa_mount/config/config.ini.
  - Autosell X rolls when "Active rolls" exceed "TARGET_ROLL_AMOUNT", if value set in /massa_mount/config/config.ini.
- [WATCHDOG]
  - Restart node when hang or when ram consumption exceed 90% (Value can be adjust)
  - You host your node under a dynamical IP? massa-guard will watch IP change and update your config.toml and push IP updates to massabot.
  - Logs actions over /massa_mount/logs/ and backup node logs before restart if necessary.
  - Push events over discord Webhook
- [STARTING FROM SCRATCH]
  - Massa-guard will auto create wallet + nodekey + stacke privkey; all with default password "**MassaToTheMoon2022**".
  - Massa-guard auto create your config.toml with your public IP.

### [RELEASE NOTES] ###
- 20240517 - Mainnet    - v2.1.1 - Mainnet      - Add 0.01 MAS for buy and sell rolls action
- 20240124 - Mainnet    - v2.1.0 - Mainnet      - v2.1 Ready + Add multiwallets availability + Discord webhook Push logs feature + Deport node storage to massa_mount
- 20240110 - Mainnet    - v2.0.0 - Mainnet      - v2.0 Ready + Remove useless dependencies + Add multi wallet autobuy features
- 20240105 - Mainnet    - v1.0.0 - Mainnet      - v1.0 Ready !!! + Change [network] label to [protocol] into new config.toml + ADD RESCUE_MAS_AMOUNT setting into config.ini
- 20240103 - Devnet     - v28.2.0 - Devnet     - v28.2 Ready

## [HOWTO] ##
### [SETUP] ###
#### [PREPARE] ####
Just create an empty folder to mount into our container /massa_mount path and run!
Or restore your wallet(s) and/or nodekey and/or config.toml into this folder if you have it:
- wallet_%%%.dat
- config.toml
- node_privkey.key

/!\ If don't have this file, leave your folder empty, massa-guard will create a wallet and node key and automaticaly stake wallet for you. This files will be backup on your mount point by massa-guard.

#### [RUN] Usecase Example ####
/!\ You can define ENV values when you create your container:
 - ''MASSAGUARD'' - Set with 1 to enable all massa-guard features or with 0 to disable all features except keys creations (Enable by default without ENV value)
 - ''DYNIP'' - Set with "0" if you host under static public IP or "1" if you host under dynimic public IP to enable update IP feature
 - ''WALLETPWD'' - Set with "YourCustomPassword" if you want to use a custom wallet password.
 - ''NODEPWD'' - Set with "YourCustomPassword" if you want to use a custom node password.
 - ''IP'' - Set with "YourIPAddress" if your node have differents publics IPs and you want to set your custom selection.
/!\ Please note, this ENV variables have a low priority if a previous config.ini exist in your mount point.

  * __Example N°1:__ Container creation example with ENV variables docker argument to restart container with host:
```console
docker run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 -p 33035:33035 --restart unless-stopped --name massa-node rykcod/massa
```
  * __Example N°2:__ Container creation example with ENV variables to run a basical container without massa-guard automation :
```console
docker run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 -p 33035:33035 -e "MASSAGUARD=0" --name massa-node rykcod/massa
```

#### [INTERACTION] To manually use massa-client of your container ####
  * To connect into your container:
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
#### [MAINTENANCE] After container creation ####
__[OPTION] To enable or update features after container creation just edit /massa_mount/config/config.ini and set__
  * Set your ''DYN_PUB_IP'' value to enable dynamical IP management (0=Disable 1=Enable)
  * Set your ''TARGET_ROLL_AMOUNT'' value to enable roll amount target to stake for your node (Integer value)
  * Set your ''MASSAGUARD'' value to enable or disable massa-guard features 0=Disable 1=Enable (Enable by default)
  * Set your ''NODE_LOGS'' value to disable logs files (0=Disable 1=Enable). Default value 1.
  * Set your ''RESCUE_MAS_AMOUNT'' value to save capacity to buy a roll if your node going to disqualify. Default value 0.
  * Set your ''DISCORD_WEBHOOK'' to push log events to Discord channel with webhook. Default value 0.

### [HELP] ###
- Massa client is running over a "screen" named "massa-client"
- Massa node is running over a "screen" named "massa-node"

#### [LOGS PATH] ####
- Massa-guard actions and events are logs into %MountPoint%/logs/massa-guard/%DATE%-massa_guard.txt
- Massa-node events are archived after every restart into %MountPoint%/logs/massa-guard/%DATE%-logs.txt

#### [HELP - Easy beginner way for IPV6 usage] ####
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

#### [VIDEO TUTORIAL][FR] ####
https://youtu.be/IzeRq43DBSQ

#### [THANKS FOR YOUR SUPPORT] ####
MASSA Address - AU1eNMGrjLTrUoQAhGNqr1ehwhdMCg5L9T3Bjcvfh3D9pswKsDAx
