#!/bin/bash
##################################################
##### A executer dans un screen massa-guard ######
##################################################
# Chemin de base
path="/massa"
# Logs path
path_log="/massa_mount"
# Chemin ou se trouve les sources de massa-client
path_client="/massa/massa-client"
# Chemin ou se trouve les sources de massa-client
path_node="/massa/massa-node"
# Chemin ou se trouve la version compilee de massa-client
path_target="/massa/target/release"
# Combien de rolls achete-t-on ?
nRolls=1

# Get stacking address
cd $path_client
addresses=$(cargo run -- --wallet wallet.dat wallet_info | grep "Address" | awk '{ print $2}')

# Copy/refresh massa_mount wallet and config files
cp $path_log/config.toml $path_node/config/config.toml
cp $path_log/wallet.dat $path_client/wallet.dat
cp $path_log/node_privkey.key $path_node/node_privkey.key
cp $path_log/staking_keys.json $path_node/staking_keys.json

while true
do
	# Attends un peu
        sleep 5m

        get_addresses=$(cd $path_client;$path_target/massa-client get_addresses $addresses)
        Candidate_rolls=$(echo "$get_addresses" | grep "Candidate rolls" | cut -d " " -f 3)

        # Check candidate roll > 0
        if [ $Candidate_rolls -eq 0 ]
        then
                echo "[$(date +%Y%m%d-%HH%M)][ROLL][KO]BUY $nRolls ROLL" >> $path_log/massa_guard-$(date +%F).txt
                cd $path_client
                $path_target/massa-client buy_rolls $addresses $nRolls 0
        fi

        # Verifie si le node est en difficulte
        checkGetStatus=$(timeout 2 $path_target/massa-client get_status | wc -l)
        checkDiscardStatus=$(grep "DiscardReason" $path_node/logs.txt | wc -l)
        if [ $checkGetStatus -lt 10 ]
        then
                # Error log
                echo "[$(date +%Y%m%d-%HH%M)][NODE][KO]TIMEOUT - RESTART NODE" >> $path_log/massa_guard-$(date +%F).txt

                # Stop node
                cd $path_client
                nodePID=$(ps -ax | grep massa-node | grep SCREEN | awk '{print $1}')
                kill $nodePID
                sleep 10s

                # Backup current log file to troobleshoot
                cd $path_node
                mv logs.txt $path_log/$(date +%F)-logs.txt

                # Re-Launch node to new massa-node Screen
                screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt'
        elif [ $checkDiscardStatus -ge 1 ]
        then
                # Error log
                echo "[$(date +%Y%m%d-%HH%M)][NODE][KO]DISCARD - RESTART NODE" >> $path_log/massa_guard-$(date +%F).txt

                # Stop node
                cd $path_client
                nodePID=$(ps -ax | grep massa-node | grep SCREEN | awk '{print $1}')
                kill $nodePID
                sleep 10s

                # Backup current log file to troobleshoot
                cd $path_node
                mv logs.txt $path_log/$(date +%F)-logs.txt

                # Re-Launch node to new massa-node Screen
                screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt'
        fi
done
