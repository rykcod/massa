#!/bin/bash
#==================== Configuration ========================#
# Global configuration
. /massa-guard/config/default_config.ini
# Custom configuration
. $PATH_CONF_MASSAGUARD/config.ini
# Import custom library
. /massa-guard/sources/lib.sh

# Wait node booststrap
WaitBootstrap

#====================== Log begin ==========================#
# Log MASSA-GUARD Start
echo "[$(date +%Y%m%d-%HH%M)][INFO][START]MASSA-GUARD is starting" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

# Load Wallet and Node key or create it and stake wallet
CheckOrCreateWalletAndNodeKey

# Get stacking address
WalletAddress=$(GetWalletAddress)

####################################################################
# Infinite check
while true
do
	# Get candidate rolls and MAS amount
	CandidateRolls=$(GetCandidateRoll $Address)
	# Get MAS amount
	MasBalance=$(GetMASAmount $Address)
	# Buy max roll or 1 roll if possible when candidate roll amount = 0
	BuyRoll $CandidateRolls $MasBalance $WalletAddress

	# Check node status
	NodeResponsive=$(CheckNodeResponsive)
	# Check ram consumption percent in integer
	NodeRam=$(CheckNodeRam)

	ReloadNode=$(CheckAndReloadNode $NodeRam $NodeResponsive)

	if [ ReloadNode -eq 0 ]
	then
		# Refresh bootstrap nodes list
		python3 $PATH_SOURCES/bootstrap_finder.py >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Check faucet
		checkFaucet=$(cat $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | grep "faucet" | wc -l)
		# Get faucet
		if [ $checkFaucet -eq 0 ]
		then
			if [ ! $DISCORD_TOKEN == "NULL" ]
			then
				python3 $PATH_SOURCES/faucet_spammer.py $DISCORD_TOKEN >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
				"[$(date +%Y%m%d-%HH%M)][INFO][FAUCET]GET $(date +%Y%m%d) FAUCET on discord" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			fi
		fi

		# Refresh bootstrap file and node key if dont exist on repo
		cp $PATH_NODE_CONF/config.toml $PATH_MOUNT/
		cp $PATH_NODE_CONF/bootstrappers.toml $PATH_MOUNT/
		if [ ! -e $PATH_MOUNT/node_privkey.key ]
		then
			# Backup node_privkey.key
			cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
			echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup node_privkey.key" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		fi
	fi
	# Wait 2min before next check
	sleep 2m
done
#######################################################################
