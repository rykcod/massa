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
if [ -e $PATH_CLIENT/wallet.dat)-logs.txt ]
then
	cd $PATH_CLIENT
	addresses=$(cargo run -- --wallet wallet.dat wallet_info | grep "Address" | awk '{ print $2}')
# Create a wallet
else
	# Generate wallet
	$PATH_TARGET/massa-client wallet_generate_private_key
	# Backup wallet
	cp $PATH_CLIENT/wallet.dat $PATH_MOUNT/wallet.dat
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
		python3 $PATH_SOURCES/bootstrap_finder.py
		
		# Check faucet
		checkFaucet=$(cat $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | grep "FAUCET" | wc -l)
		# Get faucet
		if [ $checkFaucet -ge 1 ]
		then
			python3 $PATH_SOURCES/faucet_spammer.py $DISCORD_TOKEN
			"[$(date +%Y%m%d-%HH%M)][INFO][FAUCET]GET $(date +%Y%m%d) FAUCET on discord" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		fi
		
		# Refresh bootstrap files
		cp $PATH_NODE_CONF/config.toml $PATH_CONF_MASSAGUARD/
		cp $PATH_NODE_CONF/bootstrappers.toml $PATH_CONF_MASSAGUARD/
	fi
done
#######################################################################