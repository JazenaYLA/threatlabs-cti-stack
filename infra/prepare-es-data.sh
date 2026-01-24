#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

sudo mkdir -p vol/esdata
sudo chown -R 1000:1000 vol/esdata
