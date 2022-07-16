#!/bin/bash

# Global configuration
. /massa-guard/config/default_config.ini
# Custom configuration
source <(grep = $PATH_CONF_MASSAGUARD/config.ini)

source $HOME/.cargo/env
# Launch client
cd $PATH_CLIENT
screen -dmS massa-client bash -c 'cargo run --release -- -p '$WALLET_PWD''
sleep 1s
# Launch node
cd $PATH_NODE
screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release -- -p '$NODE_PWD' |& tee logs.txt'
