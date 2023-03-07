FROM ubuntu:20.04

# Build Arguments
ARG ARM
ARG VERSION

# LABEL about the custom image
LABEL maintainers="benoit@alphatux.fr, ps@massa.org"
LABEL version=$VERSION
LABEL description="Massa node with massa-guard features"

# Update and install packages dependencies
RUN apt-get update \
&& apt install -y curl python3-pip \
&& python3 -m pip install -U discord.py==1.7.3 toml-cli

# Download the Massa package
COPY download-massa.sh .
RUN chmod u+x download-massa.sh \
&& ./download-massa.sh \
&& rm download-massa.sh

# Create massa-guard tree
RUN mkdir -p /massa-guard/sources \
&& mkdir -p /massa-guard/config

# Copy massa-guard sources
COPY massa-guard.sh /massa-guard/
COPY sources/cli.sh /cli.sh
COPY sources /massa-guard/sources
COPY config /massa-guard/config

# Conf rights
RUN chmod +x /massa-guard/massa-guard.sh \
&& chmod +x /massa-guard/sources/* \
&& chmod +x /cli.sh \
&& mkdir /massa_mount

# Add Massa cli binary
RUN ln -sf /cli.sh /usr/bin/massa-cli

# Node run then massa-guard
CMD [ "/massa-guard/sources/run.sh" ]
