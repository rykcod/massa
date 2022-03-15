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

TOKEN = sys.argv[1]
CMD = ["/massa/target/release/massa_client", "wallet_info"] # edit this line to replace it with your massa client if needed
FAUCET_CHANNEL_ID = 866190913030193172    
ERROR="[ \033[0;31m\033[1m ERROR \033[0m]"
WARN="[ \033[0;33m\033[1m WARN \033[0m ]" 
INFO="[ \033[0;32m\033[1m INFO \033[0m ]"


class DiscordClient(discord.Client):
    async def on_ready(self):
        utcnow = datetime.datetime.utcnow()
        print(f"{utcnow} {INFO}: Logged on as {self.user}!")
        output, error = subprocess.Popen(CMD, stdout=subprocess.PIPE, stderr=subprocess.PIPE).communicate()
        if (not error) and output:
            address = ""
            for line in output.decode("UTF-8").split("\n"):
                if "Address" in line:
                    address = line.split(" ")[-1]
                    break
            if address :
                faucet_channel = self.get_channel(FAUCET_CHANNEL_ID)
                utcnow = datetime.datetime.utcnow()
                if faucet_channel:
                    print(f"{utcnow} {INFO}: Ping faucet with address {address}")
                    await faucet_channel.send(address)
                else:
                    print(f"{utcnow} {ERROR}: Unable to find faucet channel")
            else:
                utcnow = datetime.datetime.utcnow()  
                print(f"{utcnow} {ERROR}: Unable to find wallet address")
        else:
            error = error.decode("UTF-8")
            utcnow = datetime.datetime.utcnow()
            print(f"{utcnow} {ERROR}: Failed to get wallet address: {error}")
        print(f"{utcnow} {INFO}: Terminated")
        await self.close()


print(f"{datetime.datetime.utcnow()} {INFO}: Starting faucet ping script")
DiscordClient().run(TOKEN, bot=False)
