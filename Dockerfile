# Download custom base
FROM ubuntu:20.04
 
# LABEL about the custom image
LABEL maintainer="benoit@alphatux.fr"
LABEL version="0.13.0.0"
LABEL description="Node Massa"
 
# Defini le timezone du container
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris"

# Met a jour la liste des paquets
RUN apt-get update \
&& apt-get upgrade -y \
&& apt install -y pkg-config curl wget libclang-dev build-essential libssl-dev screen procps python3-pip netcat \
&& apt autoclean -y \
&& python3 -m pip install -U discord.py

# Download Testnet 13.0 Massa binaries
RUN wget https://github.com/massalabs/massa/releases/download/TEST.13.0/massa_TEST.13.0_release_linux.tar.gz \
&& tar -zxpf massa_TEST.13.0_release_linux.tar.gz \
&& rm -f massa_TEST.13.0_release_linux.tar.gz

RUN mkdir /massa-guard \
&& mkdir /massa-guard/sources \
&& mkdir /massa-guard/config

# Copy massa-guard sources
COPY ./massa-guard.sh /massa-guard/
COPY ./sources /massa-guard/sources
COPY ./config /massa-guard/config

# Conf rights
RUN chmod +x /massa-guard/massa-guard.sh \
&& chmod +x /massa-guard/sources/* \
&& mkdir /massa_mount

# Expose ports
EXPOSE 31244
EXPOSE 31245
EXPOSE 33035

# Lancement du node
CMD /massa-guard/sources/init_copy_host_files.sh \
&& bash /massa-guard/sources/run.sh \
&& bash /massa-guard/massa-guard.sh
