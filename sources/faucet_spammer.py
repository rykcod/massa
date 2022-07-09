#!/usr/bin/python3
#########################################################################################
##### WARNING: Using this script may cause Discord to terminate your account        #####
##### Use it with a dummy account and at your own risk                              #####
##### The discord token is used to authenticate the connection with the account     #####
##### Be extra careful with the permissions on this script                          #####
##### Recommanded to give rwx permissions only to the owner/executor of the script  #####
#########################################################################################
# This script must be located in /usr/local/bin

import subprocess
import discord # To install this dependency: python3 -m pip install -U discord.py
import datetime
import sys

TOKEN = sys.argv[1]
WALLET_PWD = sys.argv[1]
CMD = ["/massa/target/release/massa-client", "-p", WALLET_PWD, "wallet_info"] # edit this line to replace it with your massa client if needed
FAUCET_CHANNEL_ID = 866190913030193172
ERROR="[ERROR]"
WARN="[WARN]"
INFO="[INFO]"


class DiscordClient(discord.Client):
    async def on_ready(self):
        date = datetime.datetime.today()
        dateLog = date.strftime('%Y%m%d-%HH%M')
        output, error = subprocess.Popen(CMD, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
        if (not error) and output:
            address = ""
            for line in output.decode("UTF-8").split("\n"):
                if "Address" in line:
                    address = line.split(" ")[-1]
                    break
            if address :
                faucet_channel = self.get_channel(FAUCET_CHANNEL_ID)
                if faucet_channel:
                    print(f"[{dateLog}]{INFO}Ping faucet with address {address} for {self.user}")
                    await faucet_channel.send(address)
                else:
                    print(f"[{dateLog}]{ERROR}Unable to find faucet channel")
            else:
                print(f"[{dateLog}]{ERROR}Unable to find wallet address")
        else:
            error = error.decode("UTF-8")
            print(f"[{dateLog}]{ERROR}Failed to get wallet address: {error}")
        await self.close()

DiscordClient().run(TOKEN, bot=False)