#!/bin/bash

# Global configuration
. /massa-guard/config/default_config.ini

# Shorcut to use massa-client from outside of the container
cd $PATH_CLIENT
./massa-client -p $WALLETPWD "$@"