#!/bin/bash
#====================== Configuration ==========================#
# Global configuration
. /massa-guard/config/default_config.ini
# Import custom library
. /massa-guard/sources/lib.sh

WaitBootstrap

#====================== Check and load ==========================#
# Load Wallet and Node key or create it and stake wallet
CheckOrCreateWalletAndNodeKey

IS_ACTIVATED="${MASSAGUARD:-1}"
DYNIP="${DYNIP:-0}"
NODE_TESTNET_REGISTRATION="${NODE_TESTNET_REGISTRATION:-KO}"
TARGET_ROLL_AMOUNT="${TARGET_ROLL_AMOUNT:-2}"

#==================== Massa-guard circle =========================# 
# Infinite check
while true
do
	# If massa-guard features enabled
	if [ "$IS_ACTIVATED" == "1" ]
	then

		# Check node status
		CheckNodeResponsive
		NodeResponsive=$?

		# Check ram consumption percent in integer
		CheckNodeRam
		ramCheck=$?

		# Restart node if issue
		if [[ $NodeResponsive -eq 1 || $ramCheck -eq 1 ]]; then
			RestartNode
			return
		fi

		# Buy max roll or 1 roll if possible when candidate roll amount = 0
		BuyOrSellRoll

		# If dynamical IP feature enable and public IP is new
		if [[ "$DYNIP" == "1" ]]; then

			CheckPublicIP
			publicIpChanged=$?
			if [[ $publicIpChanged -eq 1 ]]; then
				# Refresh config.toml + restart node + push new IP to massabot
				RefreshPublicIP
			fi
		fi
		
		
	fi
	# Wait before next loop
	sleep 2m
done
