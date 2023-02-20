#!/bin/bash
docker build -t peterjah/massa-core_arm64 --build-arg VERSION=TEST.19.3 --build-arg ARM=true .