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

cd $PATH_MOUNT

# Conf node file
if [ -e config.toml ]
then
	cp config.toml $PATH_NODE_CONF/config.toml
	green "INFO" "Load config.toml"

# If ref config.toml dont exist in massa_mount
else

	echo "[protocol]" > config.toml
	echo "routable_ip = \"$myIP\"" >> config.toml
	cp config.toml $PATH_NODE_CONF/config.toml

	green "INFO" "Create your default config.toml with $myIP as routable IP"
fi

# Custom node config
if [ -e node_config_$VERSION.toml ]
then
	cp node_config_$VERSION.toml $PATH_NODE/base_config/config.toml
	green "INFO" "Load node_config_$VERSION.toml"
else
	# Set bootstrap mode to ipv4 only
	toml set --toml-path $PATH_NODE/base_config/config.toml bootstrap.bootstrap_protocol "IPv4"
	cp $PATH_NODE/base_config/config.toml node_config_$VERSION.toml
fi

# Wallet to use
if [ -e wallet_*.yaml ]
then
	walletFile=$(basename wallet_*.yaml)
	green "INFO" "Loading wallet $walletFile from massa_mount to client"
	mkdir -p $PATH_CLIENT/wallets
	cp $walletFile $PATH_CLIENT/wallets/
elif [ "$?" = 2 ]
then
	warn "ERROR" "Several wallets found in massa_mount. Please keep only one wallet in massa_mount"
	exit 1
elif [ -n $WALLET_PRIVATE_KEY ]
then
	green "INFO" "Loading wallet from environement private key"
	massa-cli -j wallet_add_secret_keys $WALLET_PRIVATE_KEY
else
	warn "ERROR" "No wallet found in massa_mount and no WALLET_PRIVATE_KEY provided. A new wallet will be created"
fi
