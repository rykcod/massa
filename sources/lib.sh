

green () { echo -e "Massa-Guard \033[01;32m$1\033[0m [$(date +%Y%m%d-%HH%M)] $2"; }

warn () { echo -e "Massa-Guard \033[01;33mWARNING\033[0m [$(date +%Y%m%d-%HH%M)] $1"; }

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

	green "INFO" "Successfully bootstraped"
}

#############################################################
# FUNCTION = GetWalletAddress
# DESCRIPTION = Get wallet public address
# RETURN = Wallet address
#############################################################
GetWalletAddress() {
	massa-cli -j wallet_info | jq -r '.[].address_info.address'
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
		massa-cli wallet_generate_secret_key > /dev/null
		green "INFO" "Generate wallet.dat"

		# Backup wallet to the mount point as ref
		cp $PATH_CLIENT/wallet.dat $PATH_MOUNT/wallet.dat

		green "INFO" "Backup wallet.dat"

	fi

	## Stacke if wallet not stack or staking_keys don't exist
	checkStackingKey=$(massa-cli -j node_get_staking_addresses | jq -r '.[]')

	if ([ ! -e $PATH_NODE_CONF/staking_wallet.dat ] || [ -z "$checkStackingKey" ])
	then
		# Get first wallet Address
		walletAddress=$(GetWalletAddress)
		# Stacke wallet
		massa-cli node_start_staking $walletAddress > /dev/null
		green "INFO" "Stake privKey"

		# Backup staking_wallet.dat to mount point as ref
		cp $PATH_NODE_CONF/staking_wallet.dat $PATH_MOUNT/staking_wallet.dat
		green "INFO" "Backup staking_wallet.dat"

	fi

	## Backup node_privkey if no ref in mount point
	# If node_privkey.key don't exist
	if [ ! -e $PATH_MOUNT/node_privkey.key ]
	then
		# Copy node_privkey.key to mount point as ref
		cp $PATH_NODE_CONF/node_privkey.key $PATH_MOUNT/node_privkey.key
		green "INFO" "Backup $PATH_NODE_CONF/node_privkey.key to $PATH_MOUNT"

	fi
}

#############################################################
# FONCTION = GetCandidateRoll
# DESCRIPTION = Ckeck candidate roll on node
# ARGUMENTS = WalletAddress
# RETURN = Candidate rolls amount
#############################################################
GetCandidateRoll() {
	massa-cli -j wallet_info | jq -r '.[].address_info.candidate_rolls'
}

#############################################################
# FONCTION = GetMASAmount
# DESCRIPTION = Check MAS amount on active wallet
# ARGUMENTS = WalletAddress
# RETURN = MAS amount
#############################################################
GetMASAmount() {
	massa-cli -j wallet_info | jq -r '.[].address_info.final_balance'
}

#############################################################
# FONCTION = BuyOrSellRoll
# ARGUMENTS = CandidateRollAmount, MasAmount, WalletAddress
# DESCRIPTION = Adujst roll amount with max roll settings and if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
#############################################################
BuyOrSellRoll() {
	WalletAddress=$(GetWalletAddress)
	# Get candidate rolls
	CandidateRolls=$(($(GetCandidateRoll "$WalletAddress")))
	# Get MAS amount
	echo $(GetMASAmount "$WalletAddress")
	MasBalance=$(($(GetMASAmount "$WalletAddress")))

	# Check candidate roll > 0 and Mas amount >= 100 to buy first roll
	if (( $CandidateRolls == 0 )); then
		if (( $MasBalance > 100 )); then
			green "INFO" "Buy 1 Roll"

			# Buy roll amount
			massa-cli buy_rolls $WalletAddress 1 0 > /dev/null
		else
			green "INFO" "Cannot buy first ROLL because MAS Amount less than 100."
		fi
	 return 0
	fi
	if [ $TARGET_ROLL_AMOUNT == "NULL" ]; then
		if (( $MasBalance > 200 )); then
			NbRollsToBuy=$((($MasBalance-100)/100))
			green "INFO" "Autobuy $NbRollsToBuy ROLL because MAS amount equal to $MasBalance"

			# Buy roll amount
			massa-cli buy_rolls $WalletAddress $NbRollsToBuy 0 > /dev/null
		fi
	else
		MAX_ROLL_AMOUNT=$(($TARGET_ROLL_AMOUNT))
		if (($MAX_ROLL_AMOUNT > $CandidateRolls)) && (( $MasBalance > 200 )); then
			# Calculation of max rolls you can buy with all your MAS amount
			NbRollsCanBuyWithMAS=$((($MasBalance-100)/100))
			NbRollsNeedToBuy=$(($MAX_ROLL_AMOUNT-$CandidateRolls))
			# If rolls amount you can buy less than max amount, buy all you can buy
			if (($NbRollsCanBuyWithMAS <= $NbRollsNeedToBuy)); then
				NbRollsToBuy=$NbRollsCanBuyWithMAS
			# Else buy max amount you can buy
			else
				NbRollsToBuy=$NbRollsNeedToBuy
			fi
			green "INFO" "Autobuy $NbRollsToBuy ROLL because MAS amount equal to $MasBalance and ROLL amount of $CandidateRolls less than target amount of $TARGET_ROLL_AMOUNT"

			# Buy roll amount
			massa-cli buy_rolls $WalletAddress $NbRollsToBuy 0 > /dev/null
		fi
		# If roll target amount less than active roll amount sell exceed rolls
		if (($MAX_ROLL_AMOUNT < $CandidateRolls)); then
			NbRollsToSell=$(($CandidateRolls-$TARGET_ROLL_AMOUNT))
			green "INFO" "Autosell $NbRollsToSell ROLL because ROLL amount of $CandidateRolls greater than target amount of $TARGET_ROLL_AMOUNT"

			# Sell roll amount
			massa-cli sell_rolls $WalletAddress $NbRollsToSell 0 > /dev/null
		fi
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

	MAX_RAM=${NODE_MAX_RAM:-99}

	# If ram consumption is too high
	if ([ ! -z $checkRam ] && [ $checkRam -gt $MAX_RAM ])
	then
		warn "Max RAM usage treshold hit, restarting node"
		return 1
	fi
}

#############################################################
# FONCTION = CheckNodeResponsive
# DESCRIPTION = Check node vitality with get_status timeout
# RETURN = NodeResponsiveStatus 0 for OK Logs for KO
#############################################################
CheckNodeResponsive() {
	# Check node status and logs events
	checkGetStatus=$(timeout 2 massa-cli get_status | wc -l)

	# If get_status is responsive
	if [ $checkGetStatus -lt 10 ]
	then
		return 1
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
	fi
}

#############################################################
# FONCTION = PingFaucet
# DESCRIPTION = Ping faucet one time per day
# RETURN = 0 for ping done 1 for ping already got
#############################################################
PingFaucet() {
	python3 $PATH_SOURCES/faucet_spammer.py $DISCORD $WALLETPWD &
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
	CONF_IP=$(toml get --toml-path $PATH_NODE_CONF/config.toml network.routable_ip 2>/dev/null)

	# Check if configured IP equal to real IP
	if [ "$myIP" == "$confIP" ]
	then
		# Return no change
		echo 0
	else
		# Return IP change
		echo 1
	fi
}

#############################################################
# FONCTION = RefreshPublicIP
# DESCRIPTION = Change Public IP into config.toml + push it to massabot if TOKEN Discord is set
# RETURN = 0 for ping done 1 for ping already got
#############################################################
RefreshPublicIP() {
	# Get Public IP of node
	myIP=$(GetPublicIP)
	echo Check if get IP OK myIP=$myIP

	# Check if get IP OK
	if [ -n "$myIP" ]; then
		# Get Public IP conf for node
		CONF_IP=$(toml get --toml-path $PATH_NODE_CONF/config.toml network.routable_ip 2>/dev/null)
		if [ "$myIP" != "$CONF_IP" ]; then
			# Push new IP to massabot
			timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $myIP > $PATH_MASSABOT_REPLY
			# Check massabot return
			if grep -q "IP address: $myIP" "$PATH_MASSABOT_REPLY"; then
				green "INFO" "Dynamique public IP changed, updated for $1 in config.toml and with massabot"
			elif grep -q "wait for announcements!" "$PATH_MASSABOT_REPLY"; then
                warn "Unable to update registered IP with Massabot because the testnet has not started yet"
			else
                warn "Unable to update registered IP with Massabot because Massabot is not responsive or responding incorrectly"
			fi

			# Update IP in your ref config.toml and restart node
			toml set --toml-path $PATH_MOUNT/config.toml network.routable_ip $myIP
			CheckAndReloadNode 0 1
		fi
	fi
}

#############################################################
# FONCTION = GetPublicIP
# DESCRIPTION = Get public IP
# RETURN = Node Public IP
#############################################################
GetPublicIP() {
	# Get mon IP
	myIP=$(curl -s checkip.amazonaws.com)

	# Return my public IP
	echo $myIP
}

#############################################################
# FONCTION = RegisterNodeWithMassabot
# DESCRIPTION = Register node with massabot
# ARGUMENTS = Address, Massa Discord ID
#############################################################
RegisterNodeWithMassabot() {
	# Get registration hash
	registrationHash=$(massa-cli -j node_testnet_rewards_program_ownership_proof $1 $2 | jq -r)

	# Push defaut request to massabot
	timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $registrationHash > $PATH_MASSABOT_REPLY

	if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord account \`[0-9]{18}\` has been associated with this node ID"
	then
		green "INFO" "Node is now register with discord ID $2 and massabot"
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
	if [ "$NODE_TESTNET_REGISTRATION" != "OK" ]
	then
		# Push new IP to massabot
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD "info" > $PATH_MASSABOT_REPLY

		# Check massabot return
		if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord user_id \`[0-9]{18}\` is not registered yet"\|"but not associated to any node ID and staking address"
		then
			# Get Massa Discord ID
			massaDiscordID=$(cat $PATH_MASSABOT_REPLY | grep -o -E [0-9]{18})

			WalletAddress=$(GetWalletAddress)
			# Register node with massaBot
			sleep 5s
			RegisterNodeWithMassabot $WalletAddress $massaDiscordID
		else
			green "INFO" "Discord user is already registered for tesnet rewards program"
			export NODE_TESTNET_REGISTRATION=OK
		fi
	fi
}
