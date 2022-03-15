#!/bin/bash
#==================== Configuration ========================#
#############################################################
######## Importation de la configuration du script ##########
#############################################################
# Configuration generale
. /massa-guard/config/config.ini

##### Copy/refresh massa_mount wallet and config files if exists #####
# Conf node file
if [ -e $PATH_SOURCES/config.toml ]
then
	cp $PATH_SOURCES/config.toml $PATH_NODE_CONF/config.toml
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_SOURCES/config.toml as ref" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi
# Bootstrap list if exist
if [ -e $PATH_SOURCES/bootstrappers.toml ]
then
	cp $PATH_SOURCES/bootstrappers.toml $PATH_NODE_CONF/bootstrappers.toml
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_SOURCES/bootstrappers.toml index" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi
# Wallet to use
if [ -e $PATH_SOURCES/wallet.dat ]
then
	cp $PATH_SOURCES/wallet.dat $PATH_CLIENT/wallet.dat
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_SOURCES/wallet.dat as ref" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi
# Node private key to use
if [ -e $PATH_SOURCES/node_privkey.key ]
then
	cp $PATH_SOURCES/node_privkey.key $PATH_NODE_CONF/node_privkey.key
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_SOURCES/node_privkey.key as ref" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi
# Wallet to use to stacke
if [ -e $PATH_SOURCES/staking_keys.json ]
then
	cp $PATH_SOURCES/staking_keys.json $PATH_NODE_CONF/staking_keys.json
	echo "[$(date +%Y%m%d-%HH%M)][INFO][LOAD]LOAD $PATH_SOURCES/staking_keys.json as ref" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi
