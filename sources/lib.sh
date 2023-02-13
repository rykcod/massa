#############################################################
# FONCTION = WaitBootstrap
# DESCRIPTION = Wait node bootstrapping
#############################################################
WaitBootstrap() {
	# Wait node booststrap
	while true; do
		CheckNodeResponsive
		[ $? -eq 0 ] && break

		sleep 5s
	done

	echo "[$(date +%Y%m%d-%HH%M)][INFO][START]MASSA-NODE Successfully bootstraped"

	return 0
}

#############################################################
# FUNCTION = GetWalletAddress
# DESCRIPTION = Get wallet public address
# RETURN = Wallet address
#############################################################
GetWalletAddress() {
	cd $PATH_CLIENT
	WalletAddress=$($PATH_TARGET/massa-client -p $WALLETPWD wallet_info | grep "Address" | cut -d " " -f 2 | head -n 1)
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
	checkWallet=`$PATH_TARGET/massa-client -p $WALLETPWD wallet_info | grep -c "Address"`
	if ([ ! -e $PATH_CLIENT/wallet.dat ] || [ $checkWallet -lt 1 ])
	then
		# Generate wallet
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLETPWD wallet_generate_secret_key > /dev/null
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Generate wallet.dat"
		# Backup wallet to the mount point as ref
		cp $PATH_CLIENT/wallet.dat $PATH_MOUNT/wallet.dat

		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup wallet.dat"
	fi

	## Stacke if wallet not stacke
	# If staking_keys don't exist
	checkStackingKey=`$PATH_TARGET/massa-client -p $WALLETPWD node_get_staking_addresses | grep -c -E "[0-z]{51}"`
	if ([ ! -e $PATH_NODE_CONF/staking_wallet.dat ] || [ $checkStackingKey -lt 1 ])
	then
		# Get first wallet Address
		walletAddress=$(GetWalletAddress)
		# Stacke wallet
		$PATH_TARGET/massa-client -p $WALLETPWD node_start_staking $walletAddress > /dev/null
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Stake privKey"
		# Backup staking_wallet.dat to mount point as ref
		cp $PATH_NODE_CONF/staking_wallet.dat $PATH_MOUNT/staking_wallet.dat
		echo "[$(date +%Y%m%d-%HH%M)][INFO][INIT]Backup staking_wallet.dat"
	fi

	## Backup node_privkey if no ref in mount point
	# If node_privkey.key don't exist
	if [ ! -e $PATH_MOUNT/node_privkey.key ]
	then
		# Copy node_privkey.key to mount point as ref
		cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
		echo "[$(date +%Y%m%d-%HH%M)][INFO][BACKUP]Backup $PATH_NODE_CONF/node_privkey.key to $PATH_MOUNT"
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
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client -p $WALLETPWD wallet_info)
	# Get candidate roll amount for first Address
	CandidateRolls=$(echo "$get_address" wallet_info | grep "Rolls" | cut -d "=" -f 4 | head -n 1)
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
	get_address=$(cd $PATH_CLIENT;$PATH_TARGET/massa-client -p $WALLETPWD wallet_info)
	# Get MAS amount for first Address
	MasAmount=$(echo "$get_address" | grep -E "Balance"." final" | cut -d "=" -f 2 | cut -d "," -f 1 | cut -d "." -f 1 | head -n 1)
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
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]BUY 1 ROLL"

		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLETPWD buy_rolls $3 1 0 > /dev/null

	# If MAS amount < 100 MAS and Candidate roll = 0
	elif ([ $1 -eq 0 ] && [ $2 -lt 100 ])
	then
		echo "[$(date +%Y%m%d-%HH%M)][KO][ROLL]Cannot buy first ROLL because MAS Amount less than 100. Please get 100 MAS on Discord or set your DISCORD_ID on /massa_mount/config/config.ini"

	# If MAS amount > 200 MAS and no rolls limitation, buy ROLLs
	elif ([ $2 -gt 200 ] && [ $TARGET_ROLL_AMOUNT == "NULL" ])
	then
		NbRollsToBuy=$((($2-100)/100))
		echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $2"
		# Buy roll amount
		cd $PATH_CLIENT
		$PATH_TARGET/massa-client -p $WALLETPWD buy_rolls $3 $NbRollsToBuy 0 > /dev/null

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
				echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $2 and ROLL amount of $1 less than target amount of $TARGET_ROLL_AMOUNT"
			# Else buy max amount you can buy
			else
				NbRollsToBuy=$NbRollsNeedToBuy
				echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOBUY $NbRollsToBuy ROLL because MAS amount equal to $2 and ROLL amount of $1 less than target amount of $TARGET_ROLL_AMOUNT"
			fi
			# Buy roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLETPWD buy_rolls $3 $NbRollsToBuy 0 > /dev/null
		# If roll target amount less than active roll amount sell exceed rolls
		elif [ $TARGET_ROLL_AMOUNT -lt $1 ]
		then
			NbRollsToSell=$(($1-$TARGET_ROLL_AMOUNT))
			echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOSELL $NbRollsToSell ROLL because ROLL amount of $1 greater than target amount of $TARGET_ROLL_AMOUNT"
			# Sell roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLETPWD sell_rolls $3 $NbRollsToSell 0 > /dev/null
		fi
	# If rolls limitation is set
	elif [ ! $TARGET_ROLL_AMOUNT == "NULL" ]
	then
		# If roll target amount less than active roll amount sell exceed rolls
		if [ $TARGET_ROLL_AMOUNT -lt $1 ]
		then
			NbRollsToSell=$(($1-$TARGET_ROLL_AMOUNT))
			echo "[$(date +%Y%m%d-%HH%M)][INFO][ROLL]AUTOSELL $NbRollsToSell ROLL because ROLL amount of $1 greater than target amount of $TARGET_ROLL_AMOUNT"
			# Sell roll amount
			cd $PATH_CLIENT
			$PATH_TARGET/massa-client -p $WALLETPWD sell_rolls $3 $NbRollsToSell 0 > /dev/null
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
		echo "[$(date +%Y%m%d-%HH%M)][KO][NODE]RAM EXCEED - NODE WILL RESTART"
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
	checkGetStatus=$(timeout 2 $PATH_TARGET/massa-client -p $WALLETPWD get_status | wc -l)

	# If get_status is responsive
	if [ $checkGetStatus -lt 10 ]
	then
		return 1
	# If get_status hang
	else
		return 0
	fi
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
			# This will stop the whole container the container
		pkill massa-node

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
		python3 $PATH_SOURCES/faucet_spammer.py $DISCORD $WALLETPWD

		# Return ping done
		return 0
	fi
	# Return ping already done today
	return 1
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
		# Get Public IP conf for node
		confIP=$(cat $PATH_NODE_CONF/config.toml | grep "routable_ip" | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|([0-9a-z]{4})(:[0-9a-z]{0,4}){1,7}')

		# Push new IP to massabot
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $myIP > $PATH_MASSABOT_REPLY
		# Check massabot return
		if ($(cat $PATH_MASSABOT_REPLY | grep -q -e "IP address: $myIP"))
		then
			echo "[$(date +%Y%m%d-%HH%M)][INFO][IP]Dynamique public IP changed, updated for $1 in config.toml and with massabot"
		elif ($(cat $PATH_MASSABOT_REPLY | grep -q -e "wait for announcements!"))
		then
			echo "[$(date +%Y%m%d-%HH%M)][WARN][IP]Unable to update registrered IP with massabot because testnet not start for now"
		else
			echo "[$(date +%Y%m%d-%HH%M)][ERROR][IP]Unable to update registrered IP with massabot because massabot not or wrong responsive"
		fi

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
	registrationHashReturn=$($PATH_TARGET/massa-client -p $WALLETPWD "node_testnet_rewards_program_ownership_proof" $1 $2)
	registrationHash=$(echo $registrationHashReturn | sed -r 's/^Enter the following in discord: //')

	# Push defaut request to massabot
	timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $registrationHash > $PATH_MASSABOT_REPLY

	if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord account \`[0-9]{18}\` has been associated with this node ID"
	then
		echo "[$(date +%Y%m%d-%HH%M)][INFO][REGISTRATION]Node is now register with discord ID $2 and massabot"
		export NODE_TESTNET_REGISTRATION=OK
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
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD "info" > $PATH_MASSABOT_REPLY

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
			echo "[$(date +%Y%m%d-%HH%M)][INFO][REGISTRATION]Node already associated with and massabot or registration is not already open"
			export NODE_TESTNET_REGISTRATION=OK
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