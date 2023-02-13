# Download custom base
FROM ubuntu:20.04

# Build Arguments
ARG TARGETPLATFORM
ARG VERSION

# LABEL about the custom image
LABEL maintainer="benoit@alphatux.fr"
LABEL version=$VERSION
LABEL description="Massa node with massa-guard features"

# Set timezone and default cli
SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/Paris"

# Update and install packages dependencies
RUN apt-get update \
&& apt-get upgrade -y \
&& apt install -y curl wget procps python3-pip netcat \
&& python3 -m pip install -U discord.py==1.7.3

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
COPY sources /massa-guard/sources
COPY config /massa-guard/config

# Conf rights
RUN chmod +x /massa-guard/massa-guard.sh \
&& chmod +x /massa-guard/sources/* \
&& mkdir /massa_mount

# Node run then massa-guard
CMD [ "/massa-guard/sources/run.sh" ]
# CMD /massa-guard/sources/init_copy_host_files.sh \
# && bash /massa-guard/sources/run.sh \
# && bash /massa-guard/massa-guard.sh
