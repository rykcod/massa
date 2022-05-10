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
address=$(GetWalletAddress)

####################################################################

while true
do
	# Get candidate rolls and MAS amount
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_address $address)
	Candidate_rolls=$(echo "$get_address" | grep "Candidate rolls" | cut -d " " -f 3)
	Final_balance=$(echo "$get_address" | grep "Final balance" | cut -d " " -f 3 | cut -d "." -f 1)

	# Check candidate roll > 0
	if [ $Candidate_rolls -eq 0 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]BUY 1 ROLL" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client buy_rolls $address 1 0
	# If MAS amount > 200 MAS, buy ROLLs
	elif [ $Final_balance -gt 200 ]
	then
		NbRollsToBuy=$((($Final_balance-100)/100))
		echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $Final_balance" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client buy_rolls $address $NbRollsToBuy 0
	fi

	# Check node status and logs events
	checkGetStatus=$(timeout 2 $PATH_TARGET/massa-client get_status | wc -l)

	# Get ram consumption percent in integer
	checkRam=$(ps -u | awk '/massa-node/ && !/awk/' | awk '{print $4}')
	checkRam=${checkRam/.*}

	if( [ $checkGetStatus -lt 10 ] || [ $checkRam -gt $NODE_MAX_RAM ] )
	then
		# Error log if Get_Status error
		if [ $checkGetStatus -lt 10 ]; then echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]TIMEOUT - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt ; fi

		# Error log if Ram node consumption overload error
		if [ $checkRam -gt $NODE_MAX_RAM ]; then echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]RAM EXCEED - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt ; fi

		# Stop node and client
		cd $PATH_CLIENT
		nodePID=$(ps -ax | grep massa-node | grep SCREEN | awk '{print $1}')
		kill $nodePID
		sleep 1
		clientPID=$(ps -ax | grep massa-client | grep SCREEN | awk '{print $1}')
		kill $clientPID
		sleep 5s

		# Backup current log file to troobleshoot
		if [ -e $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt ]
		then
			cat $PATH_NODE/logs.txt >> $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
		else
			cp $PATH_NODE/logs.txt $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
		fi

		# Reload conf files
		$PATH_SOURCES/init_copy_host_files.sh

		# Re-Launch node and client
		cd $PATH_NODE
		screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt'
		sleep 1
		cd $PATH_CLIENT
		screen -dmS massa-client bash -c 'cargo run --release'

		# Wait 8min before next check to lets node bootstrap
		sleep 8m
	else
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

		# Refresh bootstrap files and node key if dont exist on repo
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