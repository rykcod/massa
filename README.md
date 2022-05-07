![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

#### Massa node + Massa-guard ####
**Last build for Massa testnet Episode 10 dans sa release 10.0**

### INFO ###
Build a massa-node container This image include a script named "**/massa-guard/massa-guard.sh**" to:
  * Autobuy 1 roll when your node failed and lost his active rolls
  * Autobuy rolls when your MAS amount greater than 200 MAS
  * Auto refresh massa online bootstrap list - 20220506 UPDATE --> Available for Testnet 10 format
  * Restart node when stuck
  * Autoget MAS faucet on Discord 1 time per day
  * Logs his actions over /massa_mount/logs/
  * Expose port 33035 to allow monitoring with https://paranormal-brothers.com/massa/

### RELEASE NOTES ###
  * 20220508 - Solve issue wallet creation if missing
  * 20220507 - Solve issue bootstrapper feeding for ipv6 node since testnet 10. Now add stay available for ipv4 node but add skip ipv6 nodes.


### TO DO ###
__STEP 1:__
Mount a folder to the /massa_mount path on container and store in this folder your files:
  * wallet.dat
  * config.toml
  * node_privkey.key
  * staking_keys.json
  * [OPTION] bootstrappers.toml
  * [OPTION] config/config.ini

/!\ If the files is not present, massa-guard will create a node_privkey.key and a wallet.dat and stake it for you

__Example:__
  * Container creation:
  **docker run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 -p 33035:33035 --name massa-node rykcod/massa**

  * Container connection:
  ** docker exec -it massa-node /bin/bash **

  * Connect to massa-client after container connection:
  ** screen -x massa-client **
  
  * Exit screen or container
  ** ctrl+a+d **
  
__STEP 2:__
Set your Discord token in /massa_mount/config/config.ini to enable "Autoget MAS faucet" feature

Refer to https://discordhelp.net/discord-token

__STEP 3:__
/!\ Remember to register your node to the testnet program on Discord
  * Go to Discord https://discord.com/channels/828270821042159636/872395473493839913 and follow inscructions.

### HELP ###
  * Massa client is running over a "screen" named "massa-client"
  * Massa node is running over a "screen" named "massa-node"
  * To get your discord token, refer to 

For more informations:
https://github.com/rykcod/massa/

### CONTRIB ###
Thanks to:
  * **Dockyr** because it's my main nickname
  * **GGCOM** for help
  * **Danakane** for features https://gitlab.com/0x6578656376652829/massa_admin :
  * Bootstrap list refresh
  * Autoget faucet