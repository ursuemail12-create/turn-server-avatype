#!/bin/bash
set -e

echo "========================================"
echo "Avatype STUN/TURN Server - Starting up"
echo "========================================"

# Generate secrets if not provided
if [ -z "$TURN_AUTH_SECRET" ]; then
    export TURN_AUTH_SECRET=$(openssl rand -hex 32)
    echo "Generated auth secret: ${TURN_AUTH_SECRET:0:8}..."
fi

# Auto-detect external IP if not set
if [ -z "$TURN_EXTERNAL_IP" ]; then
    echo "Auto-detecting external IP..."
    export TURN_EXTERNAL_IP=$(curl -s --connect-timeout 5 \
        https://api.ipify.org || \
        curl -s --connect-timeout 5 \
        https://icanhazip.com || \
        echo "auto")
    echo "External IP set to: $TURN_EXTERNAL_IP"
fi

# Create runtime directory
mkdir -p /var/run/coturn
chown turnserver:turnserver /var/run/coturn

# Process configuration template
echo "Processing configuration..."
envsubst < /etc/turnserver.conf > /etc/turnserver-processed.conf

# Validate configuration
if ! turnserver -c /etc/turnserver-processed.conf --test; then
    echo "ERROR: Configuration validation failed!"
    exit 1
fi

# Start HTTP health check server (port 8080)
echo "Starting health check server on port 8080..."
(
    while true; do
        echo -e "HTTP/1.1 200 OK\r\n\r\nAvatype STUN/TURN Server" | \
        nc -l -p 8080 -q 1 2>/dev/null || sleep 1
    done
) &

# Start the main server
echo "Starting coturn server..."
exec turnserver -c /etc/turnserver-processed.conf \
    --log-file /var/log/coturn/turn.log \
    --simple-log \
    --no-cli \
    --verbosity 3