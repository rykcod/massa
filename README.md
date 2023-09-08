# Massa node + Massa-guard #
**Last build for Massa testnet Episode 26 release 26.1.0**

![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

## [DESCRIPTION] ##
### [FEATURES] ###
Build a massa-node container wich include some automation features from a community image with Massalabs agreements

This image include a script named "**/massa-guard/massa-guard.sh**" to:
- [GENERAL]
  - Enable/Disable all massa-guard features (Except keys creations) with the "MASSAGUARD" setting in config.ini
- [AUTOBUY/AUTOSELL]
  - Autobuy 1 roll when your node failed and lost his "Active rolls".
  - Autobuy X rolls when your MAS amount greater than 200 MAS and if "Active rolls" dont exceed "TARGET_ROLL_AMOUNT" set in /massa_mount/config/config.ini (If set).
  - Autosell X rolls when "Active rolls" exceed "TARGET_ROLL_AMOUNT" set in /massa_mount/config/config.ini (If set).
- [BOOTSTRAPFINDER] **Deprecated since testnet 16**. From now and by default comminity node unable to bootstrap on other community nodes.
  - Auto refresh massa online bootstrap list with connected node.
  - Filter to only add node which have TCP port 31244 & 31245 reachable.
- [WATCHDOG]
  - Restart node when hang or when ram consumption exceed 90% (Value can be adjust)
  - You host your node under a dynamical IP? massa-guard will watch IP change and update your config.toml and push IP updates to massabot.
  - Push public IP or public IP change to massabot (Need to set discord token in /massa_mount/config/config.ini)
  - Logs his actions over /massa_mount/logs/ and backup node logs before restart if necessary.
  - Autoget MAS faucet on Discord 1 time by day (Need to set discord token in /massa_mount/config/config.ini)
- [STARTING]
  - Massa-guard will auto register your node with massabot.
  - Massa-guard will auto create wallet + nodekey + stacke privkey; all with default password "**MassaToTheMoon2022**".
  - Massa-guard auto create your config.toml with your public IP.
  - Massa-guard auto get faucet to buy your first roll.

### [RELEASE NOTES] ###
- 20230908 - Testnet 26 - v26.1.0 - Testnet 26 - v26.1 Ready
- 20230907 - Testnet 26 - v26.0.0 - Testnet 26 - v26.0 Ready
- 20230804 - Testnet 25 - v25.2.0 - Testnet 25 - v25.2 Ready
- 20230803 - Testnet 25 - v25.1.0 - Testnet 25 - v25.1 Ready
- 20230802 - Testnet 25 - v25.0.0 - Testnet 25 - v25.0 Ready
- 20230705 - Testnet 24 - v24.1.0 - Testnet 24 - v24.1 Ready
- 20230616 - Testnet 23 - v23.2.0 - Testnet 23 - Add disable logs Feature with NODE_LOGS settings.
- 20230609 - Testnet 23 - v23.1.0 - Testnet 23 - v23.1 Ready!
- 20230509 - Testnet 22 - v22.2.0 - Testnet 22 - v22.2 Ready!
- 20230309 - Testnet 21 - v21.0.0 - Testnet 21 - v21.0 Ready!
- 20230309 - Testnet 20 - v20.2.0 - Testnet 20 - v20.2 Ready! Please note you will need to create a new wallet for this Testnet.
- 20230210 - Testnet 19 - v19.3.0 - Testnet 19 - v19.3 Ready! Somes modications after massa testnet 19.0 cmd updates.
- 20230103 - Testnet 18 - v18.0.0 - Testnet 18 - v18.0 Ready!
- 20221123 - Testnet 16 - v16.1.0 - Testnet 16 - v16.1 Ready! Remove deprecated [BOOTSTRAPFINDER] features

## [HOWTO] ##
### [SETUP] ###
#### [PREPARE] ####
__STEP 1:__
/!\ Register your discord account to the testnet program
  * Go to Massa Discord channel https://discord.com/channels/828270821042159636/872395473493839913 and follow inscructions.

__STEP 2:__
Create an empty folder to mount in our container /massa_mount path or store your wallet /nodekey/stacking_key/config.toml into this folder if you have it:
- wallet.dat
- config.toml
- node_privkey.key
- staking_keys.json

/!\ If don't have this file, leave your folder empty, massa-guard will create a wallet and node key and automaticaly stake wallet for you. This files will be backup on your mount point by massa-guard.

#### [RUN] Usecase Example ####
/!\ You can define ENV values when you create your container:
 - ''MASSAGUARD'' - Set with 1 to enable all massa-guard features or with 0 to disable all features except keys creations (Enable by default without ENV value)
 - ''DISCORD'' - Set with your discord token id (Refer to HELP section) - To enable discord feature (GetFaucet + NodeRegistration + DynamicalIP)
 - ''DYNIP'' - Set with "0" if you host under static public IP or "1" if you host under dynimic public IP to enable update IP feature
 - ''WALLETPWD'' - Set with "YourCustomPassword" if you want to use a custom wallet password.
 - ''NODEPWD'' - Set with "YourCustomPassword" if you want to use a custom node password.
 - ''IP'' - Set with "YourIPAddress" if your node have differents publics IPs and you want to set your custom selection.
/!\ Please note, this ENV variables have a low priority if a previous config.ini exist in your mount point.

  * __Example N°1:__ Container creation example with ENV variables to define Dicord token :
```console
docker run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 -p 33035:33035 -e "DISCORD=OTc2MDkyTgP0OTU4NCXsNTIy.G5jqAc.b+rV4MgEnMvo48ICeGg6E_QPg4dHjlSBJA06CA" --name massa-node rykcod/massa
```
  * __Example N°2:__ Container creation example with ENV variables to define Dicord token and run a basical container without massa-guard automation :
```console
docker run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 -p 33035:33035 -e "DISCORD=OTc2MDkyTgP0OTU4NCXsNTIy.G5jqAc.b+rV4MgEnMvo48ICeGg6E_QPg4dHjlSBJA06CA" -e "MASSAGUARD=0" --name massa-node rykcod/massa
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
  * Set your ''DISCORD_TOKEN'' value to enable "Autoget MAS faucet" feature and autoregistration node and IP to massabot (Refer to HELP section)
  * Set your ''DYN_PUB_IP'' value to enable dynamical IP management (0=Disable 1=Enable)
  * Set your ''TARGET_ROLL_AMOUNT'' value to enable roll amount target to stake for your node (Integer value)
  * Set your ''NODE_TESTNET_REGISTRATION'' value to enable node registration with massabot (KO=Enable OK=AlreadyDone)
  * Set your ''MASSAGUARD'' value to enable or disable massa-guard features 0=Disable 1=Enable (Enable by default)
  * Set your ''NODE_LOGS'' value to disable logs files (0=Disable 1=Enable). Default value 1.

### [HELP] ###
- Massa client is running over a "screen" named "massa-client"
- Massa node is running over a "screen" named "massa-node"
- To get your discord token, refer to https://shufflegazine.com/get-discord-token/

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

## [THANKS] ##
Thanks to **fsidhoum** for help
