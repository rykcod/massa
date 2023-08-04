#!/bin/bash
DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64,linux/arm/v7,linux/arm64/v8 -t peterjah/massa-core --push --build-arg VERSION=TEST.25.2 .
