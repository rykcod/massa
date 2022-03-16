#!/bin/bash
#==================== Configuration ========================#
#############################################################
######## Importation de la configuration du script ##########
#############################################################
# Global configuration
. /massa-guard/config/default_config.ini
. $PATH_CONF_MASSAGUARD/config.ini

# Log MASSA-GUARD Start
echo "[$(date +%Y%m%d-%HH%M)][INFO][START]MASSA-GUARD is starting" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

# Get stacking address
# if wallet exist
if [ -e $PATH_CLIENT/wallet.dat ]
then
	cd $PATH_CLIENT
	addresses=$($PATH_TARGET/massa-client wallet_info | grep "Address" | cut -d " " -f 2)
# Create a wallet, stacke and backup
else
	# Generate and backup wallet
	$PATH_TARGET/massa-client wallet_generate_private_key
	echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Generate wallet.dat" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	# Backup wallet
	cp $PATH_CLIENT/wallet.dat $PATH_MOUNT/wallet.dat
	echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup wallet.dat" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi
if [ ! -e $PATH_NODE_CONF/staking_keys.json ]
then
	# Stacke wallet
	privKey=$($PATH_TARGET/massa-client wallet_info | grep "Private key" | cut -d " " -f 3)
	$PATH_TARGET/massa-client node_add_staking_private_keys $privKey
	echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Stacke privKey" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	# Backup staking_keys.json
	cp $PATH_NODE_CONF/staking_keys.json $PATH_MOUNT/staking_keys.json
	echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup staking_keys.json" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
fi

####################################################################
while true
do
	# Wait 10min between check
	sleep 10m

	# Get candidate rolls and MAS amount
	get_addresses=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_addresses $addresses)
	Candidate_rolls=$(echo "$get_addresses" | grep "Candidate rolls" | cut -d " " -f 3)
	Final_balance=$(echo "$get_addresses" | grep "Final balance" | cut -d " " -f 3 | cut -d "." -f 1)

	# Check candidate roll > 0
	if [ $Candidate_rolls -eq 0 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]BUY 1 ROLL" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client buy_rolls $addresses 1 0
	# If MAS amount > 200 MAS, buy ROLLs
	elif [ $Final_balance -gt 200 ]
	then
		NbRollsToBuy=$((($Final_balance-100)/100))
		echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $Final_balance" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client buy_rolls $addresses $NbRollsToBuy 0
	fi

	# Check node status and logs events
	checkGetStatus=$(timeout 2 $PATH_TARGET/massa-client get_status | wc -l)
	if [ $checkGetStatus -lt 10 ]
	then
		# Error log
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]TIMEOUT - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt.txt

		# Stop node
		cd $PATH_CLIENT
		nodePID=$(ps -ax | grep massa-node | grep SCREEN | awk '{print $1}')
		kill $nodePID
		sleep 5s

		# Backup current log file to troobleshoot
		if [ -e $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt ]
		then
			cat $PATH_NODE/logs.txt >> $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
		else
			mv $PATH_NODE/logs.txt $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
		fi

		# Reload conf files
		$PATH_SOURCES/init_copy_host_files.sh

		# Re-Launch node to new massa-node Screen
		cd $PATH_NODE
		screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt'
	else
		# Refresh bootstrap nodes list
		python3 $PATH_SOURCES/bootstrap_finder.py >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		
		# Check faucet
		checkFaucet=$(cat $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | grep "FAUCET" | wc -l)
		# Get faucet
		if [ $DISCORD_TOKEN -eq 0 ]
			if [ ! $checkFaucet -eq 'NULL' ]
			then
				python3 $PATH_SOURCES/faucet_spammer.py $DISCORD_TOKEN >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
				"[$(date +%Y%m%d-%HH%M)][INFO][FAUCET]GET $(date +%Y%m%d) FAUCET on discord" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			fi
		fi
		
		# Refresh bootstrap files and node key if dont exist on repo
		cp $PATH_NODE_CONF/config.toml $PATH_CONF_MASSAGUARD/
		cp $PATH_NODE_CONF/bootstrappers.toml $PATH_CONF_MASSAGUARD/
		if [ ! -e $PATH_MOUNT/node_privkey.key ]
		then
			# Backup node_privkey.key
			cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
			echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup node_privkey.key" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		fi
	fi
done
#######################################################################