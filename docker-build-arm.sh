#!/bin/bash
docker build -t peterjah/massa-core_arm64 --build-arg VERSION=TEST.20.2 --build-arg ARM=true .