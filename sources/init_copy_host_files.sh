#!/bin/bash
#==================== Configuration ========================#
# Configuration generale
. /massa-guard/config/default_config.ini
# Import custom library
. /massa-guard/sources/lib.sh


## Check conf file exist
# Create paths and copy default config.ini as ref
if [ ! -d "$PATH_LOGS_MASSAGUARD" ]
then
	mkdir -p $PATH_LOGS_MASSAGUARD
fi
if [ ! -d "$PATH_LOGS_MASSANODE" ]
then
	mkdir -p $PATH_LOGS_MASSANODE
fi
if [ ! -e $PATH_CONF_MASSAGUARD/config.ini ]
then
	mkdir -p $PATH_LOGS_MASSAGUARD
	Events+=('[INFO][INIT]CREATE $PATH_LOGS_MASSAGUARD folder')
	mkdir -p $PATH_LOGS_MASSANODE
	Events+=('[INFO][INIT]CREATE $PATH_LOGS_MASSANODE folder')
	mkdir -p /massa_mount/config
	Events+=('[INFO][INIT]CREATE /massa_mount/config folder')
	cp /massa-guard/config/default_config_template.ini $PATH_CONF_MASSAGUARD/config.ini
	if [ $DYNIP ]; then python3 $PATH_SOURCES/set_config.py "DYN_PUB_IP" "$DYNIP" $PATH_CONF_MASSAGUARD/config.ini ; fi
	if [ $NODEPWD ]; then python3 $PATH_SOURCES/set_config.py "NODE_PWD" \"$NODEPWD\" $PATH_CONF_MASSAGUARD/config.ini ; fi
	if [ $WALLETPWD ]; then python3 $PATH_SOURCES/set_config.py "WALLET_PWD" \"$WALLETPWD\" $PATH_CONF_MASSAGUARD/config.ini ; fi
	if [ $MASSAGUARD ]; then python3 $PATH_SOURCES/set_config.py "MASSAGUARD" \"$MASSAGUARD\" $PATH_CONF_MASSAGUARD/config.ini ; fi
	if [ $AUTOUPDATE ]; then python3 $PATH_SOURCES/set_config.py "AUTOUPDATE" \"$AUTOUPDATE\" $PATH_CONF_MASSAGUARD/config.ini ; fi
	Events+=('[INFO][INIT]COPY default config.ini')
fi
# Load config.ini
source <(grep = $PATH_CONF_MASSAGUARD/config.ini)

# Reset and backup last node log file if exist
BackupLogsNode

## Copy/refresh massa_mount wallet and config files if exists
# Conf node file
if [ -e $PATH_MOUNT/config.toml ]
then
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml
	Events+=("[INFO][LOAD]Load $PATH_MOUNT/config.toml as ref")
# If ref config.toml dont exist in massa_mount
else
	if [ $IP ]
	then
		myIP=$IP
	else
		myIP=$(GetPublicIP)
	fi
	echo "[protocol]" > $PATH_MOUNT/config.toml
	echo "routable_ip = \"$myIP\"" >> $PATH_MOUNT/config.toml
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/config.toml

	Events+=('[INFO][INIT]Create your default config.toml with $myIP as routable IP')
fi
# Wallet to use
if [  $(ls $PATH_MOUNT/wallet_* 2>/dev/null | wc -l) -gt 0 ]
then
	mkdir $PATH_CLIENT/wallets > /dev/null 2&>1
	rm $PATH_CLIENT/wallets/wallet_* > /dev/null 2&>1
	cp $PATH_MOUNT/wallet_* $PATH_CLIENT/wallets/
	Events+=("[INFO][LOAD]Load mounted wallets as ref")
fi
# Node private key to use
if [ -e $PATH_MOUNT/node_privkey.key ]
then
	# Delete default node_privkey and load ref node_privkey
	if [ -e $PATH_NODE_CONF/node_privkey.key ]; then rm $PATH_NODE_CONF/node_privkey.key; fi
	cp $PATH_MOUNT/node_privkey.key $PATH_NODE_CONF/node_privkey.key
	Events+=("[INFO][LOAD]Load $PATH_MOUNT/node_privkey.key as ref")
fi
# Wallet to use to stacke
if [  $(ls $PATH_MOUNT/wallet_* 2>/dev/null | wc -l) -gt 0 ]
then
	mkdir $PATH_NODE_CONF/staking_wallets > /dev/null 2&>1
	rm $PATH_NODE_CONF/staking_wallets/wallet_* > /dev/null 2&>1
	cp $PATH_MOUNT/wallet_* $PATH_NODE_CONF/staking_wallets/
	Events+=("[INFO][LOAD]Load mounted wallets as ref to stacke")
fi

# Log events
if [ ! ${#Events[@]} -eq 0 ]
then
	LogEvents "${Events[@]}"
	unset Events
fi