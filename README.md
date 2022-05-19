# Massa node + Massa-guard #
**Last build for Massa testnet Episode 10 release 10.1**

![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

## DESCRIPTION ##
### FEATURES ###
Build a massa-node container This image include a script named "**/massa-guard/massa-guard.sh**" to:
- Autobuy 1 roll when your node failed and lost his active rolls
- Autobuy rolls when your MAS amount greater than 200 MAS
- Buy or sell rolls to going to ROLL target amount set in config.ini with the "TARGET_ROLL_AMOUNT" value (Not set by default)
- Auto refresh massa online bootstrap list
- Restart node when stuck or ram consumption exceed 90%
- Autoget MAS faucet on Discord 1 time per day
- Logs his actions over /massa_mount/logs/
- Expose port 33035 to allow monitoring with https://paranormal-brothers.com/massa/

### RELEASE NOTES ###
- 20220517 - ADD target roll amount feature **/!\ If you already have the "/massa_mount/config/config.ini" file, please add manually ADD this variable ''TARGET_ROLL_AMOUNT="NULL"''**
- 20220511 - Clean code
- 20220508 - Update image to v10.1
- 20220508 - ADD node Ram overload feature **/!\ If you already have the "/massa_mount/config/config.ini" file, please add manually ADD this variable ''NODE_MAX_RAM=90''**
- 20220508 - Solve issue wallet creation if missing
- 20220507 - Solve issue bootstrapper feeding for ipv6 node since testnet 10. Now add stay available for ipv4 node but add skip ipv6 nodes.


## HOWTO ##
### SETUP ###
__STEP 1:__
Mount a folder to the /massa_mount path on container and store your wallet /nodekey/stacking_key/config.toml if you have it:
- wallet.dat
- config.toml
- node_privkey.key
- staking_keys.json
- [OPTION] bootstrappers.toml
- [OPTION] config/config.ini

/!\ If don't have this file, leave your folder empty, massa-guard will create a wallet and node key and automaticaly stake wallet for you. This files will be backup on your mount point by massa-guard.

/!\ __User of one release before the 20220508?__ For the node Ram overload feature **/!\ If you already have the ''/massa_mount/config/config.ini'' file, please add manually ADD this entry ''NODE_MAX_RAM=90'' in your config file**

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
Set your Discord token in /massa_mount/config/config.ini to enable "Autoget MAS faucet" feature

Refer to https://discordhelp.net/discord-token

__STEP 3:__
/!\ Remember to register your node to the testnet program on Discord
  * Go to Discord https://discord.com/channels/828270821042159636/872395473493839913 and follow inscructions.

## HELP ##
- Massa client is running over a "screen" named "massa-client"
- Massa node is running over a "screen" named "massa-node"
- To get your discord token, refer to https://shufflegazine.com/get-discord-token/
- A easy way for beginner to enable ipv6 on your container
### HELP - Easy beginner way for IPV6 usage ###
- Create or edit your /etc/docker/daemon.json to add:
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

## TUTORIAL VIDEO ##
https://youtu.be/IzeRq43DBSQ

## CONTRIB ##
Thanks to:
- **Dockyr** because it's my main nickname
- **GGCOM** & **GNOMUZ** for help
- **Danakane** for "Autoget faucet" and "Bootstrap list refresh" features https://gitlab.com/0x6578656376652829/massa_admin :
