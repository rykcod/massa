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
# Chemin ou se trouve la version compilee de massa-client
path_target="/massa/target/release"
# How many rolls to buy if "Candidate rolls = 0" ?
nRolls=1
##################################################

# Log MASSA-GUARD Start
echo "[$(date +%Y%m%d-%HH%M)][INFO][START]MASSA-GUARD is starting" >> $path_log/massa_guard-$(date +%F).txt

# Get stacking address
cd $path_client
addresses=$(cargo run -- --wallet wallet.dat wallet_info | grep "Address" | awk '{ print $2}')

####################################################################
#### Check candidate rolls >= 1 and get_status/node responsive ##### 
while true
do
	# Wait 6min between check
	sleep 6m

	# Get candidate rolls and MAS amount
	get_addresses=$(cd $path_client;$path_target/massa-client get_addresses $addresses)
	Candidate_rolls=$(echo "$get_addresses" | grep "Candidate rolls" | cut -d " " -f 3)
	Final_balance=$(echo "$get_addresses" | grep "Final balance" | cut -d " " -f 3 | cut -d "." -f 1)

	# Check candidate roll > 0
	if [ $Candidate_rolls -eq 0 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]BUY $nRolls ROLL" >> $path_log/massa_guard-$(date +%F).txt

		# Buy roll amount
		cd $path_client
		$path_target/massa-client buy_rolls $addresses $nRolls 0
	# If MAS amoutn > 200 MAS, buy ROLLs
	elif [ $Final_balance -gt 200 ]
	then
		NbRollsToBuy=$((($Final_balance-100)/100))
		echo "[$(date +%Y%m%d-%HH%M)][ROLL][OK]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $Final_balance" >> $path_log/massa_guard-$(date +%F).txt

		# Buy roll amount
		cd $path_client
		$path_target/massa-client buy_rolls $addresses $NbRollsToBuy 0
	fi

	# Check node status and logs events
	checkGetStatus=$(timeout 2 $path_target/massa-client get_status | wc -l)

	if [ $checkGetStatus -lt 10 ]
	then
		# Error log
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]TIMEOUT - RESTART NODE" >> $path_log/massa_guard-$(date +%F).txt

		# Stop node
		cd $path_client
		nodePID=$(ps -ax | grep massa-node | grep SCREEN | awk '{print $1}')
		kill $nodePID
		sleep 10s

		# Backup current log file to troobleshoot
		if [ -e $path_log/$(date +%F)-logs.txt ]
		then
			cat $path_node/logs.txt >> $path_log/$(date +%F)-logs.txt
			rm $(date +%F)-logs.txt
		else
			mv $path_node/logs.txt $path_log/$(date +%F)-logs.txt
		fi

		# Re-Launch node to new massa-node Screen
		screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt'
	fi
done
#######################################################################