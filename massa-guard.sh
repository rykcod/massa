#!/bin/bash
#====================== Configuration ==========================#
# Global configuration
. /massa-guard/config/default_config.ini
# Import custom library
. /massa-guard/sources/lib.sh

# Wait node booststrap
WaitBootstrap

#====================== Check and load ==========================#
# Load Wallet and Node key or create it and stake wallet
CheckOrCreateWalletAndNodeKey
# Get stacking address
WalletAddress=$(GetWalletAddress)

export NODE_TESTNET_REGISTRATION=KO

if [ ! $DISCORD == "NULL" ]; then
	# Check and get faucet of current day
	PingFaucet
fi

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

			# If Discord feature enable
			if [ ! $DISCORD == "NULL" ]
			then
				# Check and registrer node with massabot if necessary
				CheckTestnetNodeRegistration "$WalletAddress"

				# If dynamical IP feature enable and public IP is new
				if ([ $DYNIP -eq 1 ] && [ $(CheckPublicIP) -eq 1 ])
				then
					# Refresh config.toml + restart node + push new IP to massabot
					RefreshPublicIP
				fi
			fi
		fi
	fi
	# Wait before next loop
	sleep 2m
done
