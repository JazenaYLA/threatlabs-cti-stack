#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

sudo mkdir -p vol/{esdata7/data,esdata8/data}
sudo chown -R 1000:1000 vol/{esdata7,esdata8}
