#!/usr/bin/python3
#########################################################################################
##### WARNING: Using this script may cause Discord to terminate your account        #####
##### Use it with a dummy account and at your own risk                              #####
##### The discord token is used to authenticate the connection with the account     #####
##### Be extra careful with the permissions on this script                          #####
##### Recommanded to give rwx permissions only to the owner/executor of the script  #####
#########################################################################################
# This script must be located in /usr/local/bin

import discord # To install this dependency: python3 -m pip install -U discord.py
import time
import datetime
import sys

TOKEN = sys.argv[1]
WALLET_ADDR = sys.argv[2]
FAUCET_CHANNEL_ID = 866190913030193172

class DiscordClient(discord.Client):
    async def on_ready(self):
        while True:
            date = datetime.datetime.today()
            dateLog = date.strftime('%Y%m%d-%HH%M')

            faucet_channel = self.get_channel(FAUCET_CHANNEL_ID)
            if faucet_channel:
                print(f"[{dateLog}][INFO]Ping faucet with address {WALLET_ADDR} for {self.user}")
                await faucet_channel.send(WALLET_ADDR)
            else:
                print(f"[{dateLog}][ERROR]Unable to find faucet channel")

            time.sleep(3601*24)    

DiscordClient().run(TOKEN, bot=False)
