# massa
Massa node + massa-guard

INFO
Build a massa-node container This image include a script to:

Autobuy roll when your node failed and lost his active roll
Restart node when hang
TO DO
Mount a folder to the /massa_mount path on container Store in this folder your files:

wallet.dat
config.toml
node_privkey.key
staking_keys.json
This folder will store the massa-guard log file.
