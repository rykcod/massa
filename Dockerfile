# Download custom base
FROM ubuntu:20.04
 
# LABEL about the custom image
LABEL maintainer="benoit@alphatux.fr"
LABEL version="0.12.1.1"
LABEL description="Node Massa"
 
# Defini le timezone du container
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris"

# Met a jour la liste des paquets
RUN apt-get update \
&& apt-get upgrade -y \
&& apt install -y pkg-config curl libclang-dev git build-essential libssl-dev screen procps python3-pip netcat \
&& apt autoclean -y \
&& python3 -m pip install -U discord.py

# Prepare l'environnement
#USER massa
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN source $HOME/.cargo/env \
&& rustup toolchain install nightly \
&& rustup default nightly-2022-07-11

RUN git clone --branch testnet https://github.com/massalabs/massa.git

WORKDIR $HOME/massa/massa-node
RUN source $HOME/.cargo/env \
&& RUST_BACKTRACE=full cargo run --release -- -p MassaToTheMoon2022 |& tee logs.txt | if grep -q "Start bootstrapping"; then pkill massa ; fi

WORKDIR $HOME/massa/massa-client
RUN source $HOME/.cargo/env \
&& cargo run --release  -- -p MassaToTheMoon2022

RUN mkdir /massa-guard \
&& mkdir /massa-guard/sources \
&& mkdir /massa-guard/config

COPY ./massa-guard.sh /massa-guard/
COPY ./sources /massa-guard/sources
COPY ./config /massa-guard/config

# Conf rights and delete temporary node key
RUN chmod +x /massa-guard/massa-guard.sh \
&& chmod +x /massa-guard/sources/* \
&& mkdir /massa_mount \
&& if [ -e /massa/massa-node/config/node_privkey.key ]; then rm /massa/massa-node/config/node_privkey.key; fi \
&& if [ -e /massa/massa-client/wallet.dat ]; then rm /massa/massa-client/wallet.dat; fi

#Expose ports
EXPOSE 31244
EXPOSE 31245
EXPOSE 33035

# Lancement du node
CMD /massa-guard/sources/init_copy_host_files.sh \
&& bash /massa-guard/sources/run.sh \
&& bash /massa-guard/massa-guard.sh
