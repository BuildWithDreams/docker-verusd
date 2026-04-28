#!/bin/bash
# Build script for buildwithdreams/verusd
# Usage: ./build.sh [version]
VERUS_VERSION=${1:-1.2.16}}
docker build --build-arg VERUS_VERSION="${VERUS_VERSION}" -t buildwithdreams/verusd:${VERUS_VERSION} .
docker tag buildwithdreams/verusd:${VERUS_VERSION}} buildwithdreams/verusd:latest
