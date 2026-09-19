#!/bin/bash
echo "Installing dependencies..."
pip install -r requirements.txt

echo "Starting FastAPI XTTSv2 Server in the background..."
MPLBACKEND=Agg python main.py &

echo "Waiting 60 seconds for the heavy 2.5GB model to load..."
sleep 60

echo "================================================================"
echo "Starting Pinggy Tunnel (uses SSH port 443 - works everywhere)..."
echo "LOOK FOR THE URL BELOW (it looks like https://xxxx.a.pinggy.io)"
echo "Send this URL to the frontend/app team!"
echo "================================================================"
# Pinggy uses SSH over port 443 which is never blocked.
# The tunnel URL will appear in the output below.
ssh -p 443 -R0:localhost:8000 \
    -o StrictHostKeyChecking=no \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    a.pinggy.io
