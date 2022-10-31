#############################################################
# FONCTION = WaitBootstrap
# DESCRIPTION = Wait node bootstrapping
#############################################################
WaitBootstrap() {
	# Wait node booststrap
	tail -n +1 -f $PATH_NODE/logs.txt | grep -m 1 -E "Successful bootstrap"\|"seconds remaining to genesis" > /dev/null

	# Log MASSA-GUARD Start
	echo "[$(date +%Y%m%d-%HH%M)][INFO][START]MASSA-NODE is running" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

	sleep 20s
	return 0
}

#############################################################
# FUNCTION = GetWalletAddress
# DESCRIPTION = Get wallet public address
# RETURN = Wallet address
#############################################################
GetWalletAddress() {
	cd $PATH_CLIENT
	WalletAddress=$($PATH_TARGET/massa-client -p $WALLET_PWD wallet_info | grep "Address" | cut -d " " -f 2)
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
	cd $PATH_CLIENT
	checkWallet=`$PATH_TARGET/massa-client -p $WALLET_PWD wallet_info | grep -c "Secret key"`
	if ([ ! -e $PATH_CLIENT/wallet.dat ] || [ $checkWallet -lt 1 ])
	then
		# Generate wallet
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLET_PWD wallet_generate_secret_key > /dev/null
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Generate wallet.dat" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		# Backup wallet to the mount point as ref
		cp $PATH_CLIENT/wallet.dat $PATH_MOUNT/wallet.dat

		clientPID=$(ps -ax | grep massa-client | grep SCREEN | awk '{print $1}')
		# Kill client SCREEN
		kill $clientPID
		# Re-Launch client
		cd $PATH_CLIENT
		screen -dmS massa-client bash -c './massa-client -p '$WALLET_PWD''

		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup wallet.dat" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	fi

	## Stacke if wallet not stacke
	# If staking_keys don't exist
	checkStackingKey=`$PATH_TARGET/massa-client -p $WALLET_PWD node_get_staking_addresses | grep -c -E "[0-z]{51}"`
	if ([ ! -e $PATH_NODE_CONF/staking_wallet.dat ] || [ $checkStackingKey -lt 1 ])
	then
		# Get private key
		cd $PATH_CLIENT
		privKey=$($PATH_TARGET/massa-client -p $WALLET_PWD wallet_info | grep "Secret key" | cut -d " " -f 3)
		# Stacke wallet
		$PATH_TARGET/massa-client -p $WALLET_PWD node_add_staking_secret_keys $privKey > /dev/null
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Stake privKey" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		# Backup staking_wallet.dat to mount point as ref
		cp $PATH_NODE_CONF/staking_wallet.dat $PATH_MOUNT/staking_wallet.dat
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup staking_wallet.dat" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	fi

	## Backup node_privkey if no ref in mount point
	# If node_privkey.key don't exist
	if [ ! -e $PATH_MOUNT/node_privkey.key ]
	then
		# Copy node_privkey.key to mount point as ref
		cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
		echo "[$(date +%Y%m%d-%HH%M)][INFO][BACKUP]Backup $PATH_NODE_CONF/node_privkey.key to $PATH_MOUNT" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
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
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client -p $WALLET_PWD wallet_info)
	# Select candidate roll amount
	CandidateRolls=$(echo "$get_address" wallet_info | grep "Rolls" | cut -d "=" -f 4)
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
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client -p $WALLET_PWD wallet_info)
	# Get MAS amount
	MasAmount=$(echo "$get_address" | grep -E "Balance"." final" | cut -d "=" -f 2 | cut -d "," -f 1 | cut -d "." -f 1)
	# Return MAS amount
	echo "$MasAmount"
	return 0
}

#############################################################
# FONCTION = BuyOrSellRoll
# ARGUMENTS = CandidateRollAmount, MasAmount, WalletAddress
# DESCRIPTION = Adujst roll amount with max roll settings and if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
#############################################################
BuyOrSellRoll() {
	# Check candidate roll > 0 and Mas amount >= 100 to buy first roll
	if ([ $1 -eq 0 ] && [ $2 -ge 100 ])
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]BUY 1 ROLL" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLET_PWD buy_rolls $3 1 0 > /dev/null

	# If MAS amount < 100 MAS and Candidate roll = 0
	elif ([ $1 -eq 0 ] && [ $2 -lt 100 ])
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]Cannot buy first ROLL because MAS Amount less than 100. Please get 100 MAS on Discord or set your DISCORD_ID on /massa_mount/config/config.ini" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

	# If MAS amount > 200 MAS and no rolls limitation, buy ROLLs
	elif ([ $2 -gt 200 ] && [ $TARGET_ROLL_AMOUNT == "NULL" ])
	then
		NbRollsToBuy=$((($2-100)/100))
		echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $2" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLET_PWD buy_rolls $3 $NbRollsToBuy 0 > /dev/null

	# If MAS amount > 200 MAS and rolls limitation is set
	elif ([ $2 -gt 200 ] && [ ! $TARGET_ROLL_AMOUNT == "NULL" ])
	then
		# If max roll limit set in /massa_mount/config/config.ini greater than candidate roll
		if [ $TARGET_ROLL_AMOUNT -gt $1 ]
		then
			# Calculation of max rolls you can buy with all your MAS amount
			NbRollsCanBuyWithMAS=$((($2-100)/100))
			# Calculation of max rolls you can buy by looking max amount set in /massa_mount/config/config.ini
			NbRollsNeedToBuy=$(($TARGET_ROLL_AMOUNT-$1))
			# If rolls amount you can buy less than max amount, buy all you can buy
			if [ $NbRollsCanBuyWithMAS -le $NbRollsNeedToBuy ]
			then
				NbRollsToBuy=$NbRollsCanBuyWithMAS
				echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $2 and ROLL amount of $1 less than target amount of $TARGET_ROLL_AMOUNT" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			# Else buy max amount you can buy
			else
				NbRollsToBuy=$NbRollsNeedToBuy
				echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $2 and ROLL amount of $1 less than target amount of $TARGET_ROLL_AMOUNT" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			fi
			# Buy roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLET_PWD buy_rolls $3 $NbRollsToBuy 0 > /dev/null
		# If roll target amount less than active roll amount sell exceed rolls
		elif [ $TARGET_ROLL_AMOUNT -lt $1 ]
		then
			NbRollsToSell=$(($1-$TARGET_ROLL_AMOUNT))
			echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOSELL $NbRollsToSell ROLL because ROLL amount of $1 greater than target amount of $TARGET_ROLL_AMOUNT" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			# Sell roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLET_PWD sell_rolls $3 $NbRollsToSell 0 > /dev/null
		fi
	# If rolls limitation is set
	elif [ ! $TARGET_ROLL_AMOUNT == "NULL" ]
	then
		# If roll target amount less than active roll amount sell exceed rolls
		if [ $TARGET_ROLL_AMOUNT -lt $1 ]
		then
			NbRollsToSell=$(($1-$TARGET_ROLL_AMOUNT))
			echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOSELL $NbRollsToSell ROLL because ROLL amount of $1 greater than target amount of $TARGET_ROLL_AMOUNT" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			# Sell roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLET_PWD sell_rolls $3 $NbRollsToSell 0 > /dev/null
		# Else, if max roll target is OK, do nothing
		else
			# Do nothing
			return 0
		fi
	# Else, if MAS amount less to buy 1 roll or if max roll target is OK, do nothing
	else
		# Do nothing
		return 0
	fi
}

#############################################################
# FONCTION = CheckNodeRam
# DESCRIPTION = Buy roll if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
# RETURN = NodeRamStatus 0 for OK Logs for KO
#############################################################
CheckNodeRam() {
	# Get ram consumption percent in integer
	checkRam=$(ps -u | awk '/massa-node/ && !/awk/' | awk '{print $4}')
	checkRam=${checkRam/.*}

	# If ram consumption is too high
	if ([ ! -z $checkRam ] && [ $checkRam -gt $NODE_MAX_RAM ])
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]RAM EXCEED - NODE WILL RESTART" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		return 1
	# If ram consumption is ok
	else
		return 0
	fi
}

#############################################################
# FONCTION = CheckNodeResponsive
# DESCRIPTION = Check node vitality with get_status timeout
# RETURN = NodeResponsiveStatus 0 for OK Logs for KO
#############################################################
CheckNodeResponsive() {
	# Check node status and logs events
	cd $PATH_CLIENT
	checkGetStatus=$(timeout 2 $PATH_TARGET/massa-client -p $WALLET_PWD get_status | wc -l)

	# If get_status is responsive
	if [ $checkGetStatus -lt 10 ]
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]TIMEOUT - NODE WILL RESTART" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		return 1
	# If get_status hang
	else
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
		# If node logs file exist
		if [ -e $PATH_NODE/logs.txt ]
		then
			# Add node logs to backup logs of the current day
			cat $PATH_NODE/logs.txt >> $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
			rm $PATH_NODE/logs.txt
		fi
	# If node backup log dont exist, create new node backup logs
	else
		# Create node backup logs of the day
		if [ -e $PATH_NODE/logs.txt ]; then mv $PATH_NODE/logs.txt $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt; else touch $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt; fi
	fi
	# Purge last current node log file in mount point
	if [ -e $PATH_LOGS_MASSANODE/current.txt ]
	then
		if [ -e $PATH_LOGS_MASSANODE/current.txt ]; then rm $PATH_LOGS_MASSANODE/current.txt; fi
	fi
	# Create clean node logs file
	if [ ! -e $PATH_NODE/logs.txt ]
	then
		touch $PATH_NODE/logs.txt
		echo "[$(date +%Y%m%d) STARTING]" >  $PATH_NODE/logs.txt
	fi
	return 0
}

#############################################################
# FONCTION = CheckAndReloadNode
# DESCRIPTION = Check node vitality parameters and restart if necessary
# ARGUMENTS = NodeRamStatus, NodeStatus
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
		kill $nodePID > /dev/null
		sleep 1s
		# Get client SCREEN PID
		clientPID=$(ps -ax | grep massa-client | grep SCREEN | awk '{print $1}')
		# Kill client SCREEN
		kill $clientPID > /dev/null
		sleep 5s

		# Reload conf files from ref
		bash $PATH_SOURCES/init_copy_host_files.sh

		# Re-Launch node and client
		bash $PATH_SOURCES/run.sh

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
	checkFaucet=$(cat $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | grep "faucet" | wc -l)
	# Get faucet
	if ([ $checkFaucet -eq 0 ] && [ $(date +%H) -gt 2 ])
	then
		# Call python ping faucet script with token discord
		cd $PATH_CLIENT
		python3 $PATH_SOURCES/faucet_spammer.py $DISCORD_TOKEN $WALLET_PWD |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

		# Return ping done
		return 0
	fi
	# Return ping already done today
	return 1
}

#############################################################
# FONCTION = RefreshUnreachableBootstrap
# DESCRIPTION = Check bootstrappers.toml connected [OTHERS] nodes list and set unavailable if unreacheble
#############################################################
RefreshUnreachableBootstrap() {
	# If bootstrappers_unreachable.txt dont exist
	if [ ! -e $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt ]
	then
		# Create bootstrappers_unreachable.txt
		touch $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt
	# Else recheck availability to bootstrap of this node
	else
		# Get bootstrapper tag as unreachable
		hostUnreachableListToRecheck=$(cat $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt)
		# Check port again for Unreachable hosts
		for hostUnreachable in $hostUnreachableListToRecheck
		do
			# If node is responsive
			if (( timeout 0.2 nc -z -v $hostUnreachable 31244 ) && ( timeout 0.2 nc -z -v $hostUnreachable 31245 ))
			then
				# Remove node of unreachable list
				grep -v $hostUnreachable $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt > $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.tmp
				mv $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.tmp $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt
			fi
		done
	fi
	# If bootstrappers list exist
	if [ -e $PATH_CONF_MASSAGUARD/bootstrappers.toml ]
	then
		# Load Others bootstrappers list
		hostListToCheck=$(cat $PATH_CONF_MASSAGUARD/bootstrappers.toml |sed '1,/^\[others\]$/d' | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|([0-9a-z]{4})(:[0-9a-z]{0,4}){1,7}')
		# Check availability to bootstrap on all bootstrappers
		for host in $hostListToCheck
		do
			# If node is unreachable on TCP port 31244 or 31245
			if (( ! timeout 0.2 nc -z -v $host 31244 ) || ( ! timeout 0.2 nc -z -v $host 31245 ))
			then
				# If unreachable node dont exist in unreachable node list
				if  ! cat $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt | grep "$host"
				then
					# Add node in unreachable node list
					echo "$host" >> $PATH_CONF_MASSAGUARD/bootstrappers_unreachable.txt
				fi
			fi
		done
	fi
	return 0
}

#############################################################
# FONCTION = RefreshBootstrapNode
# DESCRIPTION = Test and refresh bootstrap node to config.toml
#############################################################
RefreshBootstrapNode() {
	# Check RefreshUnreachableBootstrap to excecute only one time per day
	checkUnreachableNode=$(cat $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | grep "Refresh" | wc -l)
	if ([ $checkUnreachableNode -eq 0 ] && [ $(date +%H) -gt 4 ])
	then
		# Refresh bootstrap nodes list and logs returns
		RefreshUnreachableBootstrap
		echo "[$(date +%Y%m%d-%HH%M)][INFO][BOOTSTRAP]Refresh availability of connected node to bootstrap" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
	fi

	# Refresh bootstrap nodes list and logs returns
	cd $PATH_CLIENT
	python3 $PATH_SOURCES/bootstrap_finder.py $WALLET_PWD |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt

	# Copy config.toml
	cp $PATH_MOUNT/config.toml $PATH_NODE_CONF/
}

#############################################################
# FONCTION = CheckPublicIP
# DESCRIPTION = Check if public IP is change and set it into config.toml
# RETURN = 0 for no change 1 for IP change
#############################################################
CheckPublicIP() {
	# Get Public IP of node
	myIP=$(GetPublicIP)

	# Get Public IP conf for node
	confIP=$(cat $PATH_NODE_CONF/config.toml | grep "routable_ip" | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|([0-9a-z]{4})(:[0-9a-z]{0,4}){1,7}')

	# Check if configured IP equal to real IP
	if [ $myIP == $confIP ]
	then
		# Return no change
		echo 0
	else
		# Return IP change
		echo 1
	fi
	return 0
}

#############################################################
# FONCTION = RefreshPublicIP
# DESCRIPTION = Change Public IP into config.toml + push it to massabot if TOKEN Discord is set
# RETURN = 0 for ping done 1 for ping already got
#############################################################
RefreshPublicIP() {
	# Get Public IP of node
	myIP=$(GetPublicIP)

	# Check if get IP OK
	if [ ! -z $myIP ]
	then
		then
		# Get Public IP conf for node
		confIP=$(cat $PATH_NODE_CONF/config.toml | grep "routable_ip" | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|([0-9a-z]{4})(:[0-9a-z]{0,4}){1,7}')

		# Push new IP to massabot
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD_TOKEN $myIP > $PATH_MASSABOT_REPLY
		# Check massabot return
		if ($(cat $PATH_MASSABOT_REPLY | grep -q -e "IP address: $myIP"))
		then
			echo "[$(date +%Y%m%d-%HH%M)][INFO][IP]Dynamique public IP changed, updated for $1 in config.toml and with massabot" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		elif ($(cat $PATH_MASSABOT_REPLY | grep -q -e "wait for announcements!"))
		then
			echo "[$(date +%Y%m%d-%HH%M)][WARN][IP]Unable to update registrered IP with massabot because testnet not start for now" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		else
			echo "[$(date +%Y%m%d-%HH%M)][ERROR][IP]Unable to update registrered IP with massabot because massabot not or wrong responsive" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		fi
	fi

	# Update IP in your ref config.toml and restart node
	cat $PATH_NODE_CONF/config.toml | sed 's/'$confIP'/'$myIP'/' > $PATH_MOUNT/config.toml
	CheckAndReloadNode 0 1
}

#############################################################
# FONCTION = GetPublicIP
# DESCRIPTION = Get public IP
# RETURN = Node Public IP
#############################################################
GetPublicIP() {
	# Get mon IP
	myIP=$(curl -s ifconfig.co)

	# Return my public IP
	echo $myIP
	return 0
}

#############################################################
# FONCTION = RegisterNodeWithMassabot
# DESCRIPTION = Register node with massabot
# ARGUMENTS = Address, Massa Discord ID
#############################################################
RegisterNodeWithMassabot() {
	# Get registration hash
	cd $PATH_CLIENT
	registrationHashReturn=$($PATH_TARGET/massa-client -p $WALLET_PWD "node_testnet_rewards_program_ownership_proof" $1 $2)
	registrationHash=$(echo $registrationHashReturn | sed -r 's/^Enter the following in discord: //')

	# Push defaut request to massabot
	timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD_TOKEN $registrationHash > $PATH_MASSABOT_REPLY

	if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord account \`[0-9]{18}\` has been associated with this node ID"
	then
		echo "[$(date +%Y%m%d-%HH%M)][INFO][REGISTRATION]Node is now register with discord ID $2 and massabot" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
		python3 $PATH_SOURCES/set_config.py "NODE_TESTNET_REGISTRATION" \"OK\" $PATH_CONF_MASSAGUARD/config.ini
		return 0
	else
		return 1
	fi
}

#############################################################
# FONCTION = CheckTestnetNodeRegistration
# DESCRIPTION = Check if node registrered with massabot
# ARGUMENTS = Address
# RETURN = 0 Registered 1 NotRegistered
#############################################################
CheckTestnetNodeRegistration() {
	if [ $NODE_TESTNET_REGISTRATION == "KO" ]
	then
		# Push new IP to massabot
		cd $PATH_CLIENT
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD_TOKEN "info" > $PATH_MASSABOT_REPLY

		# Check massabot return
		if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord user_id \`[0-9]{18}\` is not registered yet"\|"but not associated to any node ID and staking address"
		then
			# Get Massa Discord ID
			massaDiscordID=$(cat $PATH_MASSABOT_REPLY | grep -o -E [0-9]{18})

			# Register node with massaBot
			sleep 5s
			RegisterNodeWithMassabot $1 $massaDiscordID

			# Return bot registration KO
			return 0
		else
			# Return bot registration OK
			echo "[$(date +%Y%m%d-%HH%M)][INFO][REGISTRATION]Node already associated with and massabot or registration is not already open" |& tee -a $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
			python3 $PATH_SOURCES/set_config.py "NODE_TESTNET_REGISTRATION" \"OK\" $PATH_CONF_MASSAGUARD/config.ini
			return 0
		fi
	# If node set as registrered in config.ini
	elif [ $NODE_TESTNET_REGISTRATION == "OK" ]
	then
		return 0
	else
		return 1
	fi
}

#############################################################
# FONCTION = CheckAndUpdateNode
# DESCRIPTION = Check if node registrered with massabot
# RETURN = 0 NoUpdate 1 UpdateDone
#############################################################
CheckAndUpdateNode () {
	return 0
}