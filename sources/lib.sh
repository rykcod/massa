#############################################################
# FONCTION = WaitBootstrap
# DESCRIPTION = Wait node bootstrapping
#############################################################
WaitBootstrap() {
	# Wait node booststrap
	tail -n +1 -f $PATH_NODE/logs.txt | grep -m 1 -E "Successful bootstrap"\|"seconds remaining to genesis" > /dev/null

	# Log MASSA-GUARD Start
	Events+=('[INFO][START]Massa-node is running')

	sleep 20s
	return 0
}

#############################################################
# FUNCTION = GetWalletAddresses
# DESCRIPTION = Get wallets public addresses
# RETURN = Wallets addresses
#############################################################
GetWalletAddresses() {
	cd $PATH_CLIENT
	WalletAddresses=($($PATH_TARGET/massa-client -p $WALLET_PWD wallet_info | grep "Address" | cut -d " " -f 2))
	echo "${WalletAddresses[@]}"
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
	checkWallet=`$PATH_TARGET/massa-client -p $WALLET_PWD wallet_info | grep -c "Address"`
	if ([ $(ls $PATH_CLIENT/wallets/wallet_* 2> /dev/null | wc -l) -eq 0 ] || [ $checkWallet -lt 1 ])
	then
		# Generate wallet
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLET_PWD wallet_generate_secret_key > /dev/null
                Events+=('[INFO][INIT]Generate wallet.dat')

		# Backup wallet to the mount point as ref
		cp $PATH_CLIENT/wallets/wallet_* $PATH_MOUNT/

		clientPID=$(ps -ax | grep massa-client | grep SCREEN | awk '{print $1}')
		# Kill client SCREEN
		kill $clientPID
		# Re-Launch client
		cd $PATH_CLIENT
		screen -dmS massa-client bash -c './massa-client -p '$WALLET_PWD''

                Events+=('[INFO][BACKUP]Backup wallet.dat')
	fi

	## Stacke if wallet not stacke
	# If staking_keys don't exist
	checkStackingKey=`$PATH_TARGET/massa-client -p $WALLET_PWD node_get_staking_addresses | grep -c -E "[0-z]{51}"`
	if ([ $(ls $PATH_NODE_CONF/staking_wallets/wallet_* 2> /dev/null | wc -l) -eq 0 ] || [ $checkStackingKey -lt 1 ])
	then
		# Get first wallet Address
		walletAddress=$(GetWalletAddresses)
		# Stacke wallet
		$PATH_TARGET/massa-client -p $WALLET_PWD node_start_staking $walletAddress > /dev/null
		Events+=('[INFO][INIT]Stake privKey')
	fi

	## Backup node_privkey if no ref in mount point
	# If node_privkey.key don't exist
	if [ ! -e $PATH_MOUNT/node_privkey.key ]
	then
		# Copy node_privkey.key to mount point as ref
		cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
		Events+=('[INFO][BACKUP]Backup $PATH_NODE_CONF/node_privkey.key to $PATH_MOUNT')
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
	WalletsInfos=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client -p $WALLET_PWD wallet_info)
	# Get candidate roll amount for first Address
	CandidateRolls=$(echo "$WalletsInfos" | grep -A 2 $1 | grep "Rolls" | cut -d "=" -f 4)
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
	WalletsInfos=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client -p $WALLET_PWD wallet_info)
	# Get MAS amount for first Address
	MasAmount=$(echo "$WalletsInfos" | grep -A 1 $1 | grep -E "Balance"." final" | cut -d "=" -f 2 | cut -d "," -f 1 | cut -d "." -f 1)
	# Return MAS amount
	echo "$MasAmount"
	return 0
}

#############################################################
# FONCTION = BuyOrSellRoll
# ARGUMENTS = CandidateRollAmount, MasAmount, WalletAddress
# DESCRIPTION = Adjust rolls amount with max rolls settings and if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
#############################################################
BuyOrSellRoll() {
	# Check if RESCUE_MAS_AMOUNT is set into config.ini or set it to 0
	if [ ! -v RESCUE_MAS_AMOUNT ]; then RESCUE_MAS_AMOUNT=0 ; fi
	# Check if day log file already exist or create it
	if [ ! -e $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt ] ; then touch $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt ; fi

	# Check candidate roll > 0 and Mas amount >= 100 to buy first roll
	if ([ $1 -eq 0 ] && [ $2 -ge 100 ])
	then
		Event="[KO][ROLL]Buy 1 ROLL on stacked wallet $3"
		if [ $(tail -n 5 $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | fgrep "$Event" | wc -l) -lt 2 ]
		then
			# Buy roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLET_PWD buy_rolls $3 1 0 > /dev/null
		fi

	# If MAS amount < 100 MAS and Candidate roll = 0
	elif ([ $1 -eq 0 ] && [ $2 -lt 100 ])
	then
                Event="[KO][ROLL]Cannot buy first ROLL on wallet $3 because MAS Amount less than 100. Please get 100 MAS"

	# If MAS amount > $RESCUE_MAS_AMOUNT MAS and no rolls limitation, buy ROLLs
	elif ([ $2 -gt $(($RESCUE_MAS_AMOUNT+100)) ] && [ $TARGET_ROLL_AMOUNT == "NULL" ])
	then
		NbRollsToBuy=$((($2-$RESCUE_MAS_AMOUNT)/100))
		Event="[INFO][ROLL]Autobuy $NbRollsToBuy ROLL because MAS amount equal to $2 for stacked wallet $3"
		if [ $(tail -n 5 $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | fgrep "$Event" | wc -l) -lt 2 ]
		then
			# Buy roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLET_PWD buy_rolls $3 $NbRollsToBuy 0 > /dev/null
		fi

	# If MAS amount > $RESCUE_MAS_AMOUNT MAS and rolls limitation is set
	elif ([ $2 -gt $(($RESCUE_MAS_AMOUNT+100)) ] && [ ! $TARGET_ROLL_AMOUNT == "NULL" ])
	then
		# If max roll limit set in /massa_mount/config/config.ini greater than candidate roll
		if [ $TARGET_ROLL_AMOUNT -gt $1 ]
		then
			# Calculation of max rolls you can buy with all your MAS amount
			NbRollsCanBuyWithMAS=$((($2-$RESCUE_MAS_AMOUNT)/100))
			# Calculation of max rolls you can buy by looking max amount set in /massa_mount/config/config.ini
			NbRollsNeedToBuy=$(($TARGET_ROLL_AMOUNT-$1))
			# If rolls amount you can buy less than max amount, buy all you can buy
			if [ $NbRollsCanBuyWithMAS -le $NbRollsNeedToBuy ]
			then
				NbRollsToBuy=$NbRollsCanBuyWithMAS
			# Else buy max amount you can buy
			else
				NbRollsToBuy=$NbRollsNeedToBuy
			fi
			# Buy roll amount
			Event="[INFO][ROLL]Autobuy $NbRollsToBuy ROLL because $3 MAS amount equal to $2 and ROLL amount of $1 less than target amount of $TARGET_ROLL_AMOUNT"
			if [ $(tail -n 5 $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | fgrep "$Event" | wc -l) -lt 2 ]
			then
				cd $PATH_CLIENT
				$PATH_TARGET/massa-client -p $WALLET_PWD buy_rolls $3 $NbRollsToBuy 0 > /dev/null
			fi
		# If roll target amount less than active roll amount sell exceed rolls
		elif [ $TARGET_ROLL_AMOUNT -lt $1 ]
		then
			NbRollsToSell=$(($1-$TARGET_ROLL_AMOUNT))
			Event="[INFO][ROLL]Autosell $NbRollsToSell ROLL on $3 because ROLL amount of $1 greater than target amount of $TARGET_ROLL_AMOUNT"
			if [ $(tail -n 5 $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | fgrep "$Event" | wc -l) -lt 2 ]
			then
				# Sell roll amount
				cd $PATH_CLIENT
				$PATH_TARGET/massa-client -p $WALLET_PWD sell_rolls $3 $NbRollsToSell 0 > /dev/null
			fi
		fi
	# If rolls limitation is set
	elif [ ! $TARGET_ROLL_AMOUNT == "NULL" ]
	then
		# If roll target amount less than active roll amount sell exceed rolls
		if [ $TARGET_ROLL_AMOUNT -lt $1 ]
		then
			NbRollsToSell=$(($1-$TARGET_ROLL_AMOUNT))
			Event="[INFO][ROLL]Autosell $NbRollsToSell ROLL because $3 ROLL amount of $1 greater than target amount of $TARGET_ROLL_AMOUNT"
			if [ $(tail -n 5 $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt | fgrep "$Event" | wc -l) -lt 2 ]
			then
				# Sell roll amount
				cd $PATH_CLIENT
				$PATH_TARGET/massa-client -p $WALLET_PWD sell_rolls $3 $NbRollsToSell 0 > /dev/null
			fi
		# Else, if max roll target is OK, do nothing
		else
			# Do nothing
			return 0
		fi
	# Else, if MAS amount less to buy 1 roll or if max roll target is OK, do nothing
	else
		# Do nothing
		Event=0
		return 0
	fi
	# Log cycle event
	if ([ ! -z "$Event" ] && [ $(tail -n 5 /massa_mount/logs/massa-guard/$(date +%Y%m%d)-massa_guard.txt | fgrep "$Event" | wc -l) -eq 0 ]) ; then Events+=("$Event") ; fi
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
		Events+=('[KO][NODE]RAM consumption exceed limit - Node will restart')
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
		Events+=('[KO][NODE]Node hang - Node will restart')
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
		if [ -e $PATH_LOGS_MASSANODE/current.txt ]
		then
			# Add node logs to backup logs of the current day
			cat $PATH_LOGS_MASSANODE/current.txt >> $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt
			rm $PATH_NODE/logs.txt 2> /dev/null
			rm $PATH_LOGS_MASSANODE/current.txt 2> /dev/null
		fi
	# If node backup log dont exist, create new node backup logs
	else
		# Create node backup logs of the day
		if [ -e $PATH_LOGS_MASSANODE/current.txt ]; then mv $PATH_LOGS_MASSANODE/current.txt $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt; else touch $PATH_LOGS_MASSANODE/$(date +%Y%m%d)-logs.txt; fi
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
# DESCRIPTION = Change Public IP into config.toml
# RETURN = 0 for ping done 1 for ping already got
#############################################################
RefreshPublicIP() {
	# Get Public IP of node
	myIP=$(GetPublicIP)

	# Check if get IP OK
	if [ ! -z $myIP ]
	then
		# Get Public IP conf for node
		confIP=$(cat $PATH_NODE_CONF/config.toml | grep "routable_ip" | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|([0-9a-z]{4})(:[0-9a-z]{0,4}){1,7}')

		# Update IP in your ref config.toml and restart node
		cat $PATH_NODE_CONF/config.toml | sed 's/'$confIP'/'$myIP'/' > $PATH_MOUNT/config.toml
		CheckAndReloadNode 0 1
	fi
}

#############################################################
# FONCTION = GetPublicIP
# DESCRIPTION = Get public IP
# RETURN = Node Public IP
#############################################################
GetPublicIP() {
	# Get mon IP
	myIP=$(curl -s ident.me)

	# Return my public IP
	echo $myIP
	return 0
}

#############################################################
# FONCTION = BackupNewWallets
# DESCRIPTION = Backup new wallets if exist
# RETURN = 0 NoUpdate 1 UpdateDone
#############################################################
BackupNewWallets () {
	# Backup new wallets if new exist
	if [ $(cp -nv $PATH_CLIENT/wallets/wallet_* $PATH_MOUNT/ | wc -l) -gt 0 ]
	then
		Events+=('[INFO][SAVE]Save your new wallet file to massa_mount')
	fi

	return 0
}

#############################################################
# FONCTION = CheckAndUpdateNode
# DESCRIPTION = Check if node registrered with massabot
# RETURN = 0 NoUpdate 1 UpdateDone
#############################################################
CheckAndUpdateNode () {
	return 0
}

#############################################################
# FONCTION = LogEvents
# DESCRIPTION = Log event
# ARGUMENTS = Events[]
# RETURN = 0 Log done 1 Log error
#############################################################
LogEvents () {
	# Check if RESCUE_MAS_AMOUNT is set into config.ini or set it to 0
	if [ ! -v DISCORD_WEBHOOK ]; then DISCORD_WEBHOOK=0 ; fi
	# Set current date
	Date=$(date +%Y%m%d-%HH%M)
	# For each Event
	MyEvents=("$@")
	for Event in "${MyEvents[@]}"
	do
		# Log into current log file
		echo -e "[$Date]$Event" |& tee -a $PATH_LOGS_MASSAGUARD/$DayDate-massa_guard.txt

		# If discord webhook defined
		if [ $DISCORD_WEBHOOK != 0 ]
		then
			# Push event
			curl -H "Content-Type: application/json" -d '{"username": "massa-node", "content": "'"[$Date]$Event"'"}' "$DISCORD_WEBHOOK" &> /dev/null
		fi
	done
	return 0
}