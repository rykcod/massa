#!/bin/bash

# Global configuration
. /massa-guard/config/default_config.ini

# Import custom library
. /massa-guard/sources/lib.sh

/massa-guard/sources/init_copy_host_files.sh

if [ "$?" = 1 ]; then
    warn "ERROR" "Initialization failed. Exiting..."
    exit 1
fi

/massa-guard/massa-guard.sh &

# Launch node
cd $PATH_NODE
./massa-node -p $WALLETPWD
