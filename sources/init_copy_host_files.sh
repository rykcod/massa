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

	echo "[network]" > $PATH_MOUNT/config.toml
	echo "routable_ip = \"$myIP\"" >> $PATH_MOUNT/config.toml
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml

	green "INFO" "Create your default config.toml with $myIP as routable IP"
fi

if [ ! $DISCORD == "NULL" ]
then
	# Push IP to massabot
	green "INFO" "Push IP to massabot:"
	timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $myIP
fi

# Custom node config
if [ -e $PATH_MOUNT/node_config.toml ]
then
	cp $PATH_MOUNT/node_config.toml $PATH_NODE/base_config/config.toml
	green "INFO" "Load $PATH_MOUNT/node_config.toml"
else
	# Set bootstrap mode to ipv4 only
	toml set --toml-path $PATH_NODE/base_config/config.toml bootstrap.bootstrap_protocol "IPv4"
	cp $PATH_NODE/base_config/config.toml $PATH_MOUNT/node_config.toml
fi

# Wallet to use
if [ -e $PATH_MOUNT/wallet.dat ]
then
	cp $PATH_MOUNT/wallet.dat $PATH_CLIENT/wallet.dat
	green "INFO" "Load $PATH_MOUNT/wallet.dat"
fi
# Node private key to use
if [ -e $PATH_MOUNT/node_privkey.key ]
then
	# Delete default node_privkey and load ref node_privkey
	if [ -e $PATH_NODE_CONF/node_privkey.key ]; then rm $PATH_NODE_CONF/node_privkey.key; fi
	cp $PATH_MOUNT/node_privkey.key $PATH_NODE_CONF/node_privkey.key
	green "INFO" "Load $PATH_MOUNT/node_privkey.key"

fi
# Wallet to use to stacke
if [ -e $PATH_MOUNT/staking_wallet.dat ]
then
	cp $PATH_MOUNT/staking_wallet.dat $PATH_NODE_CONF/staking_wallet.dat
	green "INFO" "Load $PATH_MOUNT/staking_wallet.dat"
fi
