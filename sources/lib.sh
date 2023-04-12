

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
# RETURN = Candidate rolls amount
#############################################################
GetCandidateRoll() {
	massa-cli -j wallet_info | jq -r '.[].address_info.candidate_rolls'
}

#############################################################
# FONCTION = GetRollBalance
# DESCRIPTION = Ckeck final roll on node
# RETURN = final rolls amount
#############################################################
GetRollBalance() {
	massa-cli -j wallet_info | jq -r '.[].address_info.final_rolls'
}

#############################################################
# FONCTION = GetActiveRolls
# DESCRIPTION = Ckeck active roll on node
# RETURN = active rolls amount
#############################################################
GetActiveRolls() {
	massa-cli -j wallet_info | jq -r '.[].address_info.active_rolls'
}

#############################################################
# FONCTION = GetMASAmount
# DESCRIPTION = Check MAS amount on active wallet
# RETURN = MAS amount
#############################################################
GetMASAmount() {
	massa-cli -j wallet_info | jq -r '.[].address_info.final_balance'
}

#############################################################
# FONCTION = BuyOrSellRoll
# DESCRIPTION = Adujst roll amount with max roll settings and if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
#############################################################
BuyOrSellRoll() {
	WalletAddress=$(GetWalletAddress)
	# Get rolls
	CandidateRolls=$(($(GetCandidateRoll $WalletAddress)))
	ActiveRolls=$(($(GetActiveRolls $WalletAddress)))
	Rolls=$(($(GetRollBalance $WalletAddress)))

	# Get MAS amount and keep integer part
	MasBalance=$(GetMASAmount $WalletAddress)
	MasBalanceInt=$(echo $MasBalance | awk -F '.' '{print $1}')
	MasBalanceInt="${MasBalanceInt:-0}"

	targetRollAmount=$(($TARGET_ROLL_AMOUNT))

	green "DEBUG" "MAS Balance = $MasBalance"
	green "DEBUG" "Rolls: Candidate: $CandidateRolls, Final: $Rolls, Active: $ActiveRolls, Target: $targetRollAmount"

	# Constants
	ROLL_COST=100

	# Functions
	function buy_rolls {
		local rolls_to_buy=$1
		green "INFO" "Buying $rolls_to_buy roll(s)..."
		# Call massa-cli command to buy rolls
		massa-cli buy_rolls $WalletAddress $rolls_to_buy 0 > /dev/null
	}

	function sell_rolls {
		local rolls_to_sell=$1
		green "INFO"  "Selling $rolls_to_sell roll(s)..."
		# Call massa-cli command to sell rolls
		massa-cli sell_rolls $WalletAddress $rolls_to_sell 0 > /dev/null
	}

	if (( $targetRollAmount == 0 )); then
		# Buy as many rolls as possible with available balance
		if (( $MasBalanceInt >= $ROLL_COST )); then
			rolls_to_buy=$(($MasBalanceInt / $ROLL_COST))
			buy_rolls $rolls_to_buy
		else
			if (( $CandidateRolls == 0 )) && (( $ActiveRolls == 0 )); then
				warn "Insuficient MAS balance to buy first ROLL. (current balance is $MasBalance MAS)"
			fi
		fi
	else
		# Calculate number of rolls needed to reach target
		rolls_needed=$(($targetRollAmount - $CandidateRolls))

		if (( $rolls_needed > 0 )); then
			# Buy rolls to reach target
			max_rolls_to_buy=$(($MasBalanceInt / $ROLL_COST))
			rolls_to_buy=$(($rolls_needed > $max_rolls_to_buy ? $max_rolls_to_buy : $rolls_needed))
			buy_rolls $rolls_to_buy
		elif (( $rolls_needed < 0 )); then
			# Sell rolls to reach target
			rolls_to_sell=$(($rolls_needed * -1))
			sell_rolls $rolls_to_sell
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
		warn "Max RAM usage treshold hit, restarting..."
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
# FONCTION = RestartNode
# DESCRIPTION = restartNode

#############################################################
RestartNode() {
	pkill massa-node
}

#############################################################
# FONCTION = PingFaucet
# DESCRIPTION = Ping faucet one time per day
# RETURN = 0 for ping done 1 for ping already got
#############################################################
PingFaucet() {
	WalletAddress=$(GetWalletAddress)
	python3 $PATH_SOURCES/faucet_spammer.py $DISCORD $WalletAddress &
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
	if [ "$myIP" != "$confIP" ]; then
		# Return no change
		return 1
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

	# Check if get IP OK
	if [ -n "$myIP" ]; then
		# Push new IP to massabot
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $myIP > $PATH_MASSABOT_REPLY
		# Check massabot return
		if grep -q "IP address: $myIP" $PATH_MASSABOT_REPLY; then
			green "INFO" "Public IP changed, updated for $myIP in config.toml and with massabot"
		elif grep -q "wait for announcements!" $PATH_MASSABOT_REPLY; then
			warn "Unable to update registered IP with Massabot because the testnet has not started yet"
			return
		else
			warn "Unable to update registered IP with Massabot because Massabot is not responsive or responding incorrectly"
			return
		fi

		# Update IP in your ref config.toml and restart node
		toml set --toml-path $PATH_MOUNT/config.toml network.routable_ip $myIP
		RestartNode
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

	WalletAddress=$(GetWalletAddress)

	# Get registration hash
	registrationHash=$(massa-cli -j node_testnet_rewards_program_ownership_proof $WalletAddress $2 | jq -r)

	# Push defaut request to massabot
	timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $registrationHash > $PATH_MASSABOT_REPLY

	if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord account \`[0-9]{18}\` has been associated with this node ID"
	then
		green "INFO" "Node is now register with discord ID $2 and massabot"
		sleep 1
		timeout 2 python3 $PATH_SOURCES/push_command_to_discord.py $DISCORD $myIP > $PATH_MASSABOT_REPLY
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
		if cat $PATH_MASSABOT_REPLY | grep -q -E "Your discord user_id \`[0-9]{18}\` is not registered yet"\|"You haven't registered your staking key and node ID"
		then
			# Get Massa Discord ID
			massaDiscordID=$(cat $PATH_MASSABOT_REPLY | grep -o -E [0-9]{18})

			# Register node with massaBot
			sleep 5s
			RegisterNodeWithMassabot $massaDiscordID
		else
			green "INFO" "Discord user is already registered for testnet rewards program"
			export NODE_TESTNET_REGISTRATION=OK
		fi
	fi
}
