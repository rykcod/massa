#############################################################
# FONCTION = WaitBootstrap
# DESCRIPTION = Wait node bootstrapping
#############################################################
WaitBootstrap() {
	# Wait node booststrap
	tail -n +1 -f $PATH_NODE/logs.txt | grep -m 1 "Successful bootstrap"
	sleep 5s
	return 0
}

#############################################################
# FUNCTION = GetWalletAddress
# DESCRIPTION = Get wallet public address
# RETURN = Wallet address
#############################################################
GetWalletAddress() {
	cd $PATH_CLIENT
	WalletAddress=$($PATH_TARGET/massa-client wallet_info | grep "Address" | cut -d " " -f 2)
	echo "$WalletAddress"
	return 0
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
	return 0
}

#############################################################
# FONCTION = GetCandidateRoll
# DESCRIPTION = Ckeck candidate roll on node
# ARGUMENTS = WalletAddress
# RETURN = Candidate rolls amount
#############################################################
GetCandidateRoll() {
	# Get address info
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_addresses $1)
	# Select candidate roll amount
	CandidateRolls=$(echo "$get_address" | grep "Candidate rolls" | cut -d " " -f 3)
	# Return candidate roll amount
	echo "$CandidateRolls"
	return 0
}

#############################################################
# FONCTION = GetMASAmount
# DESCRIPTION = Check MAS amount on active wallet
# ARGUMENTS = WalletAddress
# RETURN = MAS amount
#############################################################
GetMASAmount() {
	# Get address info
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client get_addresses $1)
	# Get MAS amount
	MasAmount=$(echo "$get_address" | grep "Final balance" | cut -d " " -f 3 | cut -d "." -f 1)
	# Return candidate roll amount
	echo "$MasAmount"
	return 0
}

#############################################################
# FONCTION = BuyRoll
# ARGUMENTS = CandidateRollAmount, MasAmount, WalletAddress
# DESCRIPTION = Buy roll if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
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
	return 0
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

	# If ram consumption is too high
	if [ $checkRam -gt $NODE_MAX_RAM ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]RAM EXCEED - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		echo 1
		return 1
	# If ram consumption is ok
	else
		echo 0
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

	# If get_status is responsive
	if [ $checkGetStatus -lt 10 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]TIMEOUT - RESTART NODE" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		echo 1
		return 1
	# If get_status hang
	else
		echo 0
		return 0
	fi
}

#############################################################
# FONCTION = BackupLogsNode
# DESCRIPTION = Backup current node logs
# RETURN = 0 for OK, 1 for error
#############################################################
BackupLogsNode() {
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
	return 0
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

		# Backup current log file to troobleshoot
		BackupLogsNode
		# Reload conf files from ref
		$PATH_SOURCES/init_copy_host_files.sh

		# Re-Launch node
		cd $PATH_NODE
		screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt'
		sleep 1s
		# Re-Launch client
		cd $PATH_CLIENT
		screen -dmS massa-client bash -c 'cargo run --release'

		# Wait node booststrap
		WaitBootstrap
		
		# Return restart operation
		return 1
	else
		# Return already ok
		return 0
	fi
}

#############################################################
# FONCTION = PingFaucet
# DESCRIPTION = Ping faucet one time per day
# RETURN = 0 for ping done 1 for ping already got
#############################################################
PingFaucet() {
	# Check faucet
	checkFaucet=$(cat $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | grep "FAUCET" | wc -l)
	# Get faucet
	if ([ $checkFaucet -eq 0 ] && [ ! $DISCORD_TOKEN == "NULL" ])
	then
		# Call python ping faucet script with token discord
		python3 $PATH_SOURCES/faucet_spammer.py $DISCORD_TOKEN >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		
		# Return ping done
		return 0
	fi
	# Return ping already done today
	return 1
}

#############################################################
# FONCTION = RefreshBootstrapNode
# DESCRIPTION = Test and refresh bootstrap node to config.toml
#############################################################
RefreshBootstrapNode() {
	# Refresh bootstrap nodes list and logs returns
	python3 $PATH_SOURCES/bootstrap_finder.py >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

	# Backup config.toml and custom bootstrapper
	cp $PATH_NODE_CONF/config.toml $PATH_MOUNT/
	cp $PATH_NODE_CONF/bootstrappers.toml $PATH_MOUNT/
}