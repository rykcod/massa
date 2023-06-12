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
# Get stacking address
WalletAddress=$(GetWalletAddress)

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
			# Get candidate rolls
			CandidateRolls=$(GetCandidateRoll "$WalletAddress")
			# Get MAS amount
			MasBalance=$(GetMASAmount "$WalletAddress")
			# Buy max roll or 1 roll if possible when candidate roll amount = 0
			BuyOrSellRoll "$CandidateRolls" "$MasBalance" "$WalletAddress"
			# [Depracated since testnet 16.0] Refresh bootstrap node with community connected and routable nodes
			# RefreshBootstrapNode

			# If logs are disable
			if [ $NODE_LOGS -eq 0 ]
			then
				# Delete logs file during container execution
				rm $PATH_LOGS_MASSANODE/current.txt $PATH_NODE/logs.txt
			fi

			# If Discord feature enable
			if [ ! $DISCORD_TOKEN == "NULL" ]
			then
				# Check and get faucet of current day
				PingFaucet

				# Check and registrer node with massabot if necessary
				CheckTestnetNodeRegistration "$WalletAddress"

				# If dynamical IP feature enable and public IP is new
				if ([ $DYN_PUB_IP -eq 1 ] && [ $(CheckPublicIP) -eq 1 ])
				then
					# Refresh config.toml + restart node + push new IP to massabot
					RefreshPublicIP
				fi
			fi
		fi

		# Check and update node if autoupdate feature is enable and upate available
		if [ $AUTOUPDATE -eq 1 ]
		then
			CheckAndUpdateNode
		fi
	fi
	# Wait before next loop
	sleep 2m
	# Refresh configuration value
	source <(grep = $PATH_CONF_MASSAGUARD/config.ini)
done
