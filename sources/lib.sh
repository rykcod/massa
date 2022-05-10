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
# FONCTION = CheckCandidateRoll
# DESCRIPTION = Ckeck candidate roll on node
# RETURN = 1 if candidate roll > 1 or 0 if candidate roll < 1
#############################################################
CheckCandidateRoll() {

}

#############################################################
# FONCTION = CheckMASAmount
# DESCRIPTION = Check MAS amount on active wallet
# RETURN = MAS amount
#############################################################
CheckMASAmount() {

}

#############################################################
# FONCTION = BuyRoll
# ARGUMENTS = CandidateRollAmount, MasAmount, WalletAddress
# DESCRIPTION = Buy roll if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
# RETURN = MAS amount bought
#############################################################
BuyRoll() {

}

#############################################################
# FONCTION = CheckRam
# DESCRIPTION = Buy roll if MAS amount > 200 or if candidate roll < 1 and MAS amount >= 100
# RETURN = 0 for OK 1 for KO
#############################################################
CheckRam() {

}

#############################################################
# FONCTION = CheckNodeResponsive
# DESCRIPTION = Check node vitality with get_status timeout
# RETURN = 0 for OK 1 for KO
#############################################################
CheckNodeResponsive() {

}