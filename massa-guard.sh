#!/bin/bash
#==================== Configuration ========================#
# Global configuration
. /massa-guard/config/default_config.ini
# Custom configuration
. $PATH_CONF_MASSAGUARD/config.ini
# Import custom library
. /massa-guard/sources/lib.sh

# Wait node booststrap
WaitBootstrap

#====================== Check and load ==========================#
# Log MASSA-GUARD Start
echo "[$(date +%Y%m%d-%HH%M)][INFO][START]MASSA-GUARD is starting" >> $PATH_LOGS_MASSAGUARD/$(date +%Y%m%d)-massa_guard.txt
# Load Wallet and Node key or create it and stake wallet
CheckOrCreateWalletAndNodeKey
# Get stacking address
WalletAddress=$(GetWalletAddress)

#==================== Massa-guard circle =========================#
# Infinite check
while true
do
	# Check node status
	NodeResponsive=$(CheckNodeResponsive)
	# Check ram consumption percent in integer
	NodeRam=$(CheckNodeRam)
	# Restart node if issue
	ReloadNode=$(CheckAndReloadNode "$NodeRam" "$NodeResponsive")
	if [ "$?" = "0" ]
	then
		# Get candidate rolls and MAS amount
		CandidateRolls=$(GetCandidateRoll "$WalletAddress")
		# Get MAS amount
		MasBalance=$(GetMASAmount "$WalletAddress")
		# Buy max roll or 1 roll if possible when candidate roll amount = 0
		BuyRoll "$CandidateRolls" "$MasBalance" "$WalletAddress"
		# Refresh bootstrap node with connected and routable node
		RefreshBootstrapNode
		# Check and get faucet of current day
		PingFaucet
	fi
	# Wait before next loop
	sleep 2m
done
