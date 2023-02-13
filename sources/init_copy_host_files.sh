#!/bin/bash
#==================== Configuration ========================#
# Configuration generale
. /massa-guard/config/default_config.ini
# Import custom library
. /massa-guard/sources/lib.sh

## Check conf file exist
# Create paths and copy default config.ini as ref
if [ ! -e $PATH_CONF_MASSAGUARD/config.ini ]
then
	mkdir -p /massa_mount/config
	echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]CREATE /massa_mount/config folder"
	cp /massa-guard/config/default_config_template.ini $PATH_CONF_MASSAGUARD/config.ini
fi
# Load config.ini
source <(grep = $PATH_CONF_MASSAGUARD/config.ini)

## Copy/refresh massa_mount wallet and config files if exists
# Conf node file
if [ -e $PATH_MOUNT/config.toml ]
then
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_MOUNT/config.toml as ref"
# If ref config.toml dont exist in massa_mount
else
	if [ $IP ]
	then
		myIP=$IP
	else
		myIP=$(GetPublicIP)
	fi
	echo "[network]" > $PATH_MOUNT/config.toml
	echo "routable_ip = \"$myIP\"" >> $PATH_MOUNT/config.toml
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml

	if [ ! $DISCORD == "NULL" ]
	then
		# Push IP to massabot
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $myIP > $PATH_MASSABOT_REPLY
	fi

	echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Create your default config.toml with $myIP as routable IP"
fi
# Wallet to use
if [ -e $PATH_MOUNT/wallet.dat ]
then
	cp $PATH_MOUNT/wallet.dat $PATH_CLIENT/wallet.dat
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_MOUNT/wallet.dat as ref"
fi
# Node private key to use
if [ -e $PATH_MOUNT/node_privkey.key ]
then
	# Delete default node_privkey and load ref node_privkey
	if [ -e $PATH_NODE_CONF/node_privkey.key ]; then rm $PATH_NODE_CONF/node_privkey.key; fi
	cp $PATH_MOUNT/node_privkey.key $PATH_NODE_CONF/node_privkey.key
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_MOUNT/node_privkey.key as ref"
fi
# Wallet to use to stacke
if [ -e $PATH_MOUNT/staking_wallet.dat ]
then
	cp $PATH_MOUNT/staking_wallet.dat $PATH_NODE_CONF/staking_wallet.dat
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_MOUNT/staking_wallet.dat as ref"
fi
