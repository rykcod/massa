#!/bin/bash

# Global configuration
. /massa-guard/config/default_config.ini

/massa-guard/sources/init_copy_host_files.sh

/massa-guard/massa-guard.sh &

# Launch node
cd $PATH_NODE
./massa-node -p $WALLETPWD
