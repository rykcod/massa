#!/bin/bash
##################################################
##### A executer dans un screen massa-guard ######
##################################################
####### Configuration du script massa-guard ######
# Chemin de base
path="/massa"
# Logs path
path_log="/massa_mount"
# Chemin ou se trouve les sources de massa-client
path_client="/massa/massa-client"
# Chemin ou se trouve les sources de massa-client
path_node="/massa/massa-node"
##################################################

##### Copy/refresh massa_mount wallet and config files if exists #####
# Conf node file
if [ -e $path_log/config.toml ]
then
	cp $path_log/config.toml $path_node/config/config.toml
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $path_log/config.toml as ref" >> $path_log/massa_guard-$(date +%F).txt
fi
# Bootstrap list if exist
if [ -e $path_log/bootstrappers.toml ]
then
	cp $path_log/bootstrappers.toml $path_node/config/bootstrappers.toml
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $path_log/bootstrappers.toml index" >> $path_log/massa_guard-$(date +%F).txt
fi
# Wallet to use
if [ -e $path_log/wallet.dat ]
then
	cp $path_log/wallet.dat $path_client/wallet.dat
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $path_log/wallet.dat as ref" >> $path_log/massa_guard-$(date +%F).txt
fi
# Node private key to use
if [ -e $path_log/node_privkey.key ]
then
	cp $path_log/node_privkey.key $path_node/config/node_privkey.key
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $path_log/node_privkey.key as ref" >> $path_log/massa_guard-$(date +%F).txt
fi
# Wallet to use to stacke
if [ -e $path_log/staking_keys.json ]
then
	cp $path_log/staking_keys.json $path_node/config/staking_keys.json
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $path_log/staking_keys.json as ref" >> $path_log/massa_guard-$(date +%F).txt
fi