#!/bin/bash
#############################################################
# FONCTION = WaitBootstrap
# DESCRIPTION = Wait node bootstrapping
#############################################################
WaitBootstrap() {
	# Wait node booststrap
	tail -n +1 -f $PATH_NODE/logs.txt | grep -m 1 "Successful bootstrap"
	sleep 2s
	return 0
}

