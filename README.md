# Massa node + Massa-guard #
**Last build for Massa testnet Episode 27 release 27.6.0**

![alt text](https://d33wubrfki0l68.cloudfront.net/7df7d7a57a8dda3cc07aab16121b3e3990cf0893/16ccd/portfolio/massa.png)

## Requirements


## How to use

  * Install docker and docker-compose on your system
  * Create a docker-compose.yml file and copy the following content and fill it with your environment variables.
  * WALLETPWD is mandatory. It is the password to unlock your wallet. If you are importing wallet from private key, this password will be used to encrypt wallet backup file
    * WALLET_PRIVATE_KEY is mandatory. It is the private key of the wallet you want to use. It will be loaded at node startup.

```bash
version: '3'
services:

  massa-core:
    image: peterjah/massa-core
    container_name: massa-core
    restart: always
    environment:
      - WALLETPWD=
      - WALLET_PRIVATE_KEY=
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

 - ''DYNIP'' - Set with "0" if you host under static public IP or "1" if you host under dynimic public IP to enable update IP feature
 - ''WALLETPWD'' - Password used to encrypt wallet yaml file.
 - ''NODE_MAX_RAM'' - The app node will auto restart if RAM usage goes over this % threshold. Default to 99%.
 - ''TARGET_ROLL_AMOUNT'' - The max number of rolls you want to hold. It will buy or sell rolls according your MAS balance and the targeted amount. Disabled by default.

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

## [HELP] ##

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
We recommend the use of watchtower to automagically pull the latest version of the docker image when available. Just add the following lines to add a new service in your docker-compose file:
```yaml
...
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --stop-timeout 360s --interval 300 massa-core
...
```

### IPV6

IPV6 is disabled by default.
To enable it in massa node edit the `massa_mount/node_config.toml` file. Set the `bootstrap_protocol` field under bootstrap section to "Both"

This part is higly experimental and has not been actively tested.

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
  - Set your local ip in config
- [STARTING]
  - Massa-guard will load your wallet from provided private key.
  - Massa-guard auto create your config.toml with your public IP.

## [THANKS] ##
Thanks to **fsidhoum** for help
