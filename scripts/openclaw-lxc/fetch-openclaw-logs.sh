#!/bin/bash
# fetch-openclaw-logs.sh
# Run this inside the OpenClaw LXC to fetch the crash logs

journalctl -u openclaw.service -n 50 --no-pager
