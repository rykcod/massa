# Massa node + Massa-guard #
**Last build for Massa testnet Episode 19 release 19.3.0**

![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

## Requirements

### Testnet reward program registration

  Register your discord account to the testnet program:
  Go to Massa Discord channel https://discord.com/channels/828270821042159636/872395473493839913 and follow instructions.


## How to use

  * Install docker and docker-compose on your system
  * Create a docker-compose.yml file and copy the following content and fill it with your environment variables.
  * WALLETPWD is mandatory, DISCORD is optionnal. See Help section to find your Discord token
  

```bash
version: '3'
services:

  massa-core:
    image: peterjah/massa-core
    container_name: massa-core
    restart: always
    environment:
      - DISCORD=
      - WALLETPWD=
    ports:
     - "31244:31244"
     - "31245:31245"
     - "33035:33035"
    cap_add:
      - SYS_NICE
      - SYS_RESOURCE
      - SYS_TIME
    volumes:
     - ./massa_mount:/massa_mount

volumes:
  massa-core:

```
Available options:

 - ''DISCORD'' - Set with your discord token id (Refer to HELP section) - To enable discord feature (GetFaucet + NodeRegistration + DynamicalIP)
 - ''DYNIP'' - Set with "0" if you host under static public IP or "1" if you host under dynimic public IP to enable update IP feature
 - ''WALLETPWD'' - Set with "YourCustomPassword" if you want to use a custom wallet password.
 - ''NODE_MAX_RAM'' - The app node will auto restart if RAM usage goes over this % treshold. Default to 99%.

Manage your node:

  * Start the container in detached mode:
```console
docker compose up -d
```

  * See the node logs:
```console
docker compose logs
```

  * Filter to get only Massa-guard logs:
```console
docker compose logs | grep Massa-Guard
```

  * To enter your container:
```console
docker exec -it massa-core /bin/bash
```

  * Using massa client:
```console
docker exec massa-core massa-cli get_status
```

### Import existing wallet

Create an empty folder to mount in our container /massa_mount path or store your wallet /nodekey/stacking_key/config.toml into this folder if you have it:
- wallet.dat
- config.toml
- node_privkey.key
- staking_keys.json

/!\ If don't have this file, leave your folder empty, massa-guard will create a wallet and node key and automaticaly stake wallet for you. This files will be backup on your mount point by massa-guard.

## [HELP] ##

### Get your Discord api token
To get your discord token, refer to https://www.androidauthority.com/get-discord-token-3149920/

### Log rotation
  Logs from your running docker will accumulate with the time. To avoid the disk to be full, you can setup log rotation at Docker level.

  Create or edit the file `/etc/docker/daemon.json`
  ```json
  {
    "log-driver": "local",
    "log-opts": {
      "max-size": "15m"
      "max-file": "5"
    }
  }
```

### Automated update
We recommend the use of watchtower to automagically pull the latest version of the docker image when available. Just add it as new service to your docker-compose file: 
```yaml
...
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --stop-timeout 360s massa-core
...
```

### IPV6
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
- 20230210 - Testnet 19 - v20.0.0 - Testnet 19 - v20.0 Ready!
- 20230210 - Testnet 19 - v19.3.0 - Testnet 19 - v19.3 Ready!
- 20230209 - Testnet 19 - v19.2.0 - Testnet 19 - v19.2 Ready!
- 20230201 - Testnet 19 - v19.0.0 - Testnet 19 - v19.0 Ready! Somes modications after massa testnet 19.0 cmd updates.
- 20230103 - Testnet 18 - v18.0.0 - Testnet 18 - v18.0 Ready!
- 20221207 - Testnet 17 - v17.2.0 - Testnet 17 - v17.2 Ready!
- 20221202 - Testnet 17 - v17.1.0 - Testnet 17 - v17.1 Ready!
- 20221123 - Testnet 16 - v16.1.0 - Testnet 16 - v16.1 Ready! Remove deprecated [BOOTSTRAPFINDER] features
- 20221010 - Testnet 15 - v15.1.0 - Testnet 15 - v15.1 Ready!
- 20220921 - Testnet 14 - v14.7.0 - Testnet 14 - v14.7 Ready! Solve MAS amount calculation issue
- 20220919 - Testnet 14 - v14.5.0 - Testnet 14 - v14.5 Ready! + Add MASSAGUARD setting in config.ini to switch on/off massa-guard
- 20220909 - Testnet 14 - v14.0.1 - Solve discord feature issues
- 20220909 - Testnet 14 - v14.0.0 - Testnet 14 Ready! **/!\ Discord features dont work in this version (Faucet spammer / Dyn IP / Resgistration)**




## [THANKS] ##
Thanks to **fsidhoum** for help
