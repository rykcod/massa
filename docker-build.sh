#!/bin/bash

# This builds the image  for all architectures an publish it on dockerhub
#DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64,linux/arm/v7,linux/arm64/v8 -t peterjah/massa-core --push --build-arg VERSION=TEST.27.6 .
# This builds the image for amd64 an load it in local docker
DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64 -t peterjah/massa-core --load --build-arg VERSION=TEST.27.6  .
