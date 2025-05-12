#!/bin/bash

# Global configuration
. /massa-guard/config/default_config.ini
# Custom configuration
source <(grep = $PATH_CONF_MASSAGUARD/config.ini)

# Launch client
cd $PATH_CLIENT
screen -dmS massa-client bash -c './massa-client -a -p '$WALLET_PWD''
sleep 1s
# Launch node
cd $PATH_NODE
screen -dmS massa-node bash -c './massa-node -a -p '$NODE_PWD' |& tee -a logs.txt '$PATH_LOGS_MASSANODE'/current.txt'
