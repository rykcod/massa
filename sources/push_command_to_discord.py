#!/usr/bin/python3

import discord
import sys

TOKEN = sys.argv[1]
QUERY = sys.argv[2]
MASSABOTID="867678025653944360"

MASSABOTID="867678025653944360"

class SendIP(discord.Client):
    async def on_ready(self):
        user = await self.fetch_user(MASSABOTID)
        await user.send(QUERY)

    async def on_message(self, message):
        print(message.content)

SendIP().run(TOKEN, bot=False)
