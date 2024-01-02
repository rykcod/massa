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

	# Set storage path to massa_mount
	toml set --toml-path $PATH_NODE/base_config/config.toml execution.hd_cache_path "/massa_mount/storage/cache/rocks_db"
	toml set --toml-path $PATH_NODE/base_config/config.toml ledger.disk_ledger_path "/massa_mount/storage/ledger/rocks_db"

	cp $PATH_NODE/base_config/config.toml node_config_$VERSION.toml
fi

# check only one wallet in massa_mount
nbWallet=$(ls -l | grep 'wallet_.*.yaml' | wc -l)
if (($nbWallet > 1))
then
	warn "ERROR" "Several wallets found in massa_mount. Please keep only one wallet in massa_mount"
	exit 1
fi

# Wallet to use
if [ -e wallet_*.yaml ]
then
	walletFile=$(basename wallet_*.yaml)
	green "INFO" "Loading wallet $walletFile from massa_mount to client"
	mkdir -p $PATH_CLIENT/wallets
	cp $walletFile $PATH_CLIENT/wallets/
elif [ -n $WALLET_PRIVATE_KEY ]
then
	green "INFO" "Loading wallet from environement private key"
	massa-cli -j wallet_add_secret_keys $WALLET_PRIVATE_KEY
else
	warn "ERROR" "No wallet found in massa_mount and no WALLET_PRIVATE_KEY provided. A new wallet will be created"
fi
