#############################################################
# FONCTION = WaitBootstrap
# DESCRIPTION = Wait node bootstrapping
#############################################################
WaitBootstrap() {
	# Wait node booststrap
	tail -n +1 -f $PATH_NODE/logs.txt | grep -m 1 "Successful bootstrap"
	sleep 2s
	return 0
}

#############################################################
# FUNCTION = GetWalletAddress
# DESCRIPTION = Get wallet address
# RETURN = Wallet address
#############################################################
GetWalletAddress() {
	cd $PATH_CLIENT
	addresses=$($PATH_TARGET/massa-client wallet_info | grep "Address" | cut -d " " -f 2)
}

#############################################################
# FONCTION = CheckOrCreateWalletAndNodeKey
# DESCRIPTION = Load Wallet and Node key or create it and stake wallet
#############################################################
CheckOrCreateWalletAndNodeKey() {
	## Create a wallet, stacke and backup
	# If wallet don't exist
	if [ ! -e $PATH_CLIENT/wallet.dat ]
	then
		# Generate wallet
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client wallet_generate_private_key
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Generate wallet.dat" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		# Backup wallet to the mount point as ref
		cp $PATH_CLIENT/wallet.dat $PATH_MOUNT/wallet.dat
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup wallet.dat" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	fi

	## Stacke if wallet not stacke
	# If staking_keys don't exist
	if [ ! -e $PATH_NODE_CONF/staking_keys.json ]
	then
		# Get private key
		cd $PATH_CLIENT
		privKey=$($PATH_TARGET/massa-client wallet_info | grep "Private key" | cut -d " " -f 3)
		# Stacke wallet
		$PATH_TARGET/massa-client node_add_staking_private_keys $privKey
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Stake privKey" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		# Backup staking_keys.json to mount point as ref
		cp $PATH_NODE_CONF/staking_keys.json $PATH_MOUNT/staking_keys.json
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup staking_keys.json" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	fi

	## Backup node_privkey if no ref in mount point
	# If node_privkey.key don't exist
	if [ ! -e $PATH_MOUNT/node_privkey.key ]
	then
		# Copy node_privkey.key to mount point as ref
		cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
		echo "[$(date +%Y%m%d-%HH%M)][INFO][BACKUP]Backup $PATH_NODE_CONF/node_privkey.key to $PATH_MOUNT" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	fi
}

#############################################################
# FONCTION = GetWalletAddress
# DESCRIPTION = Get wallet public address
# RETURN = public wallet address
#############################################################
CheckCandidateRoll() {
	# Get address info
	address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_address $1)
	# Return wallet address
	return $address
}

#############################################################
# FONCTION = GetCandidateRoll
# DESCRIPTION = Ckeck candidate roll on node
# ARGUMENTS = WalletAddress
# RETURN = > 1 if candidate roll > 1 or 0 if candidate roll < 1
#############################################################
CheckCandidateRoll() {
	# Get address info
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_address $1)
	# Select candidate roll amount
	Candidate_rolls=$(echo "$get_address" | grep "Candidate rolls" | cut -d " " -f 3)
	# Return candidate roll amount
	return $Candidate_rolls
}

#############################################################
# FONCTION = GetMASAmount
# DESCRIPTION = Check MAS amount on active wallet
# ARGUMENTS = WalletAddress
# RETURN = MAS amount
#############################################################
GetMASAmount() {
	# Get address info
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_address $1)
	# Get MAS amount
	Final_balance=$(echo "$get_address" | grep "Final balance" | cut -d " " -f 3 | cut -d "." -f 1)
	# Return candidate roll amount
	return $Candidate_rolls
}

#############################################################
# FONCTION = BuyRoll
# ARGUMENTS = CandidateRollAmount, MasAmount, WalletAddress
# DESCRIPTION = Buy roll if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
# RETURN = MAS amount bought
#############################################################
BuyRoll() {
	# Check candidate roll > 0
	if [ $1 -eq 0 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]BUY 1 ROLL" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client buy_rolls $3 1 0
	# If MAS amount > 200 MAS, buy ROLLs
	elif [ $2 -gt 200 ]
	then
		NbRollsToBuy=$((($2-100)/100))
		echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $Final_balance" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client buy_rolls $3 $NbRollsToBuy 0
	fi
}

#############################################################
# FONCTION = CheckNodeRam
# DESCRIPTION = Buy roll if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
# RETURN = NodeRamStatus 0 for OK 1 for KO
#############################################################
CheckNodeRam() {
	# Get ram consumption percent in integer
	checkRam=$(ps -u | awk '/massa-node/ && !/awk/' | awk '{print $4}')
	checkRam=${checkRam/.*}

	if [ $checkRam -gt $NODE_MAX_RAM ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]RAM EXCEED - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		return 1
	else
		return 0
	fi
}

#############################################################
# FONCTION = CheckNodeResponsive
# DESCRIPTION = Check node vitality with get_status timeout
# RETURN = NodeResponsiveStatus 0 for OK 1 for KO
#############################################################
CheckNodeResponsive() {
	# Check node status and logs events
	checkGetStatus=$(timeout 2 $PATH_TARGET/massa-client get_status | wc -l)
	
	if [ $checkGetStatus -lt 10 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]TIMEOUT - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		return 1
	else
		return 0
	fi
}

#############################################################
# FONCTION = CheckAndReloadNode
# DESCRIPTION = Check node vitality parameters and restart if necessary
# ARGUMENTS = NodeRamStatus, NodeResponsiveStatus
# RETURN = 0 for OK Continu 1 for KO Restart
#############################################################
CheckAndReloadNode() {
	if( [ $1 -eq 1 ] || [ $2 -eq 1 ] )
	then
		## Stop node and client
		cd $PATH_CLIENT
		# Get node SCREEN PID
		nodePID=$(ps -ax | grep massa-node | grep SCREEN | awk '{print $1}')
		# Kill node SCREEN
		kill $nodePID
		sleep 1s
		# Get client SCREEN PID
		clientPID=$(ps -ax | grep massa-client | grep SCREEN | awk '{print $1}')
		# Kill client SCREEN
		kill $clientPID
		sleep 5s

		## Backup current log file to troobleshoot
		# If node backup log exist, add new current logs
		if [ -e $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt ]
		then
			# Add node logs to backup logs of the current day
			cat $PATH_NODE/logs.txt >> $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
		# If node backup log dont exist, create new node backup logs
		else
			# Create node backup logs of the day
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

		# Wait 8min before next check to lets node delay to bootstrap
		sleep 8m
	fi
}
