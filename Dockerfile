# Download custom base
FROM ubuntu:20.04
 
# LABEL about the custom image
LABEL maintainer="benoit@alphatux.fr"
LABEL version="0.10.0"
LABEL description="Node Massa"
 
# Defini le timezone du container
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris"

# Met a jour la liste des paquets
RUN apt-get update \
&& apt-get upgrade -y \
&& apt install -y pkg-config curl git build-essential libssl-dev screen procps python3-pip \
&& apt autoclean -y \
&& python3 -m pip install -U discord.py

# Prepare l'environnement
#USER massa
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN source $HOME/.cargo/env \
&& rustup toolchain install nightly \
&& rustup default nightly

RUN git clone --branch testnet https://github.com/massalabs/massa.git

WORKDIR $HOME/massa/massa-node
RUN source $HOME/.cargo/env \
&& RUST_BACKTRACE=full cargo run --release |& tee logs.txt | if grep -q "Started node at time"; then pkill massa ; fi

WORKDIR $HOME/massa/massa-client
RUN source $HOME/.cargo/env \
&& cargo run --release

RUN mkdir /massa-guard \
&& mkdir /massa-guard/sources \
&& mkdir /massa-guard/config

COPY ./massa-guard.sh /massa-guard/
COPY ./sources /massa-guard/sources
COPY ./config /massa-guard/config

RUN chmod +x /massa-guard/massa-guard.sh \
&& chmod +x /massa-guard/sources/* \
&& mkdir /massa_mount

#Ouuverture des ports
EXPOSE 31244
EXPOSE 31245

# Lancement du node
CMD /massa-guard/sources/init_copy_host_files.sh \
&& source $HOME/.cargo/env \
&& cd /massa/massa-client \
&& screen -dmS massa-client bash -c 'cargo run --release' \
&& sleep 1 \
&& cd /massa/massa-node \
&& screen -dmS massa-node bash -c 'RUST_BACKTRACE=full cargo run --release |& tee logs.txt' \
&& bash /massa-guard/massa-guard.sh