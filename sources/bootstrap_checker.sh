#!/bin/bash
#==================== Configuration ========================#
# Global configuration
. /massa-guard/config/default_config.ini

#############################################################
# FONCTION = BanBootstrapUnavailable
# DESCRIPTION = Ban connected node which unavailable to bootstrap on
# ARGUMENT = Bootstrapper file to check
#############################################################
BanBootstrapUnavailable() {
	hostListToCheck=$(cat $PATH_NODE_CONF/bootstrappers.toml |sed '1,/^\[others\]$/d' | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
	for host in $hostListToCheck
	do
		if ( timeout 0.5 nc -z -v $host 31245 > /dev/null )
		then
			echo "$host OK"
		else
			echo "$host KO"
		fi
	done
	return 0
}

BanBootstrapUnavailable
