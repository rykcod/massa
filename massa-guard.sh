#!/bin/bash
#====================== Configuration ==========================#
# Default values
MASSAGUARD=1
# Global configuration
. /massa-guard/config/default_config.ini
# Custom configuration
source <(grep = $PATH_CONF_MASSAGUARD/config.ini)
# Import custom library
. /massa-guard/sources/lib.sh

# Wait node booststrap
WaitBootstrap

#====================== Check and load ==========================#
# Load Wallet and Node key or create it and stake wallet
CheckOrCreateWalletAndNodeKey
# Get stacking addresses
WalletAddresses=($(GetWalletAddresses))

#==================== Massa-guard circle =========================# 
# Infinite check
while true
do
	# If massa-guard features enabled
	if [ $MASSAGUARD -eq 1 ]
	then
		# Check node status
		CheckNodeResponsive
		NodeResponsive=$?
		# Check ram consumption percent in integer
		CheckNodeRam
		NodeRam=$?

		# Restart node if issue
		CheckAndReloadNode "$NodeRam" "$NodeResponsive"
		if [ $? -eq 0 ]
		then
			# For each wallet addresses
			for WalletAddress in "${WalletAddresses[@]}"; do
				# Get candidate rolls
				CandidateRolls=$(GetCandidateRoll "$WalletAddress")
				# Get MAS amount
				MasBalance=$(GetMASAmount "$WalletAddress")
				# Buy max roll or 1 roll if possible when candidate roll amount = 0
				BuyOrSellRoll "$CandidateRolls" "$MasBalance" "$WalletAddress"
			done

			# If logs are disable
			if ([ $NODE_LOGS -eq 0 ] && [ -e $PATH_LOGS_MASSANODE/current.txt ])
			then
				# Delete logs file during container execution
				rm $PATH_LOGS_MASSANODE/current.txt $PATH_NODE/logs.txt > /dev/null 2&>1
			fi

			# If dynamical IP feature enable and public IP is new
			if ([ $DYN_PUB_IP -eq 1 ] && [ $(CheckPublicIP) -eq 1 ])
			then
				# Refresh config.toml + restart node + [Depracated since Mainnet] push new IP to massabot
				RefreshPublicIP
			fi
		fi

		# Check and update node if autoupdate feature is enable and upate available
		if [ $AUTOUPDATE -eq 1 ]
		then
			CheckAndUpdateNode
		fi

		# Backup new wallet if new exist
		BackupNewWallets
	fi
	# Wait before next loop
	sleep 2m
	# Refresh configuration value
	source <(grep = $PATH_CONF_MASSAGUARD/config.ini)
done
