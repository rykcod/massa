![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

#### Massa node + Massa-guard ####
Last build for Massa testnet Episode 8

### INFO ###
Build a massa-node container This image include a script named "/massa-guard.sh" to:
  * Autobuy roll when your node failed and lost his active roll
  * Restart node when stuck
  * Log his actions

### TO DO ###
Mount a folder to the /massa_mount path on container Store in this folder your files:
  * wallet.dat
  * config.toml
  * node_privkey.key
  * staking_keys.json
All of this files is need start run a container --> You must genrate it before using this image.
This folder will store the massa-guard log file.

__Example:__

  **run -d -v /%MY_PATH%/massa_mount:/massa_mount -p 31244-31245:31244-31245 --name massa-node rykcod/massa**

### HELP ###
  * Massa client is running over a "screen" named "massa-client"
  * Massa node is running over a "screen" named "massa-node"

For more informations:

https://github.com/rykcod/massa/
