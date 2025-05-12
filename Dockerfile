# Download custom base
FROM ubuntu:20.4

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
&& apt install -y curl wget screen procps python3 \
&& apt autoclean -y

# Download the Massa package
COPY download-massa.sh .
RUN chmod u+x download-massa.sh \
&& ./download-massa.sh \
&& rm download-massa.sh

# Create massa-guard tree
RUN mkdir /massa-guard \
&& mkdir /massa-guard/sources \
&& mkdir /massa-guard/config

# Copy massa-guard sources
COPY massa-guard.sh /massa-guard/
COPY sources /massa-guard/sources
COPY config /massa-guard/config

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
