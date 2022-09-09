### Release 09/09/2022 ###

# Download custom base
FROM ubuntu:20.04

# Build Arguments
ARG VERSION=14

ARG MASSA_PACKAGE="massa_${VERSION}_release_linux.tar.gz"
ARG MASSA_PACKAGE_ARM64="massa_${VERSION}_release_linux_arm64.tar.gz"
ARG MASSA_PACKAGE_LOCATION="https://github.com/massalabs/massa/releases/download/$VERSION/"

# LABEL about the custom image
LABEL maintainer="benoit@alphatux.fr"
LABEL version=$VERSION
LABEL description="Massa node"

# Set timezone and default cli
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris"

# Update and install packages dependencies
RUN apt-get update \
&& apt-get upgrade -y \
&& apt install -y curl wget screen procps python3-pip netcat \
&& apt autoclean -y \
&& python3 -m pip install -U discord.py

# Update the package name if building for arm64 platform
RUN if [[ $TARGETPLATFORM =~ linux/arm* ]]; then MASSA_PACKAGE=MASSA_PACKAGE_ARM64; fi

# Download testnet Massa binaries
RUN wget "$MASSA_PACKAGE_LOCATION/$MASSA_PACKAGE" \
&& tar -zxpf $MASSA_PACKAGE \
&& rm -f $MASSA_PACKAGE

# Create massa-guard tree
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

# Node run then massa-guard
CMD /massa-guard/sources/init_copy_host_files.sh \
&& bash /massa-guard/sources/run.sh \
&& bash /massa-guard/massa-guard.sh
