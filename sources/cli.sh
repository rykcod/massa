#!/bin/bash

# Global configuration
. /massa-guard/config/default_config.ini

# Shorcut to use massa-client from outside of the container
pushd $PATH_CLIENT
./massa-client "$@"
popd