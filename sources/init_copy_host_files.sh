#!/bin/bash
#==================== Configuration ========================#
# Configuration generale
. /massa-guard/config/default_config.ini
# Import custom library
. /massa-guard/sources/lib.sh

## Copy/refresh massa_mount wallet and config files if exists
if [ $IP ]; then
	myIP=$IP
else
	myIP=$(GetPublicIP)
fi
# Conf node file
if [ -e $PATH_MOUNT/config.toml ]
then
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml
	green "INFO" "Load $PATH_MOUNT/config.toml"

# If ref config.toml dont exist in massa_mount
else

	echo "[protocol]" > $PATH_MOUNT/config.toml
	echo "routable_ip = \"$myIP\"" >> $PATH_MOUNT/config.toml
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml

	green "INFO" "Create your default config.toml with $myIP as routable IP"
fi

# Custom node config
if [ -e $PATH_MOUNT/node_config_$VERSION.toml ]
then
	cp $PATH_MOUNT/node_config_$VERSION.toml $PATH_NODE/base_config/config.toml
	green "INFO" "Load $PATH_MOUNT/node_config_$VERSION.toml"
else
	# Set bootstrap mode to ipv4 only
	toml set --toml-path $PATH_NODE/base_config/config.toml bootstrap.bootstrap_protocol "IPv4"
	cp $PATH_NODE/base_config/config.toml $PATH_MOUNT/node_config_$VERSION.toml
fi

# Wallet to use
if [ -z $WALLET_PRIVATE_KEY ]
then
	warn "ERROR" "Secret key is not set, please set WALLET_PRIVATE_KEY in your docker-compose.yml. A new wallet will be created"
else
	green "INFO" "Loading wallet from private key"
	massa-cli -j wallet_add_secret_keys $WALLET_PRIVATE_KEY
fi