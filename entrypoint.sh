#!/bin/bash
set -e

echo "========================================"
echo "Avatype STUN/TURN Server - Starting up"
echo "========================================"

# Generate auth secret if not set (optional, for dev/testing)
: "${TURN_AUTH_SECRET:=changeme_in_production}"
export TURN_AUTH_SECRET

# Print external IP
EXTERNAL_IP=$(curl -s https://api.ipify.org || echo "127.0.0.1")
echo "External IP detected: $EXTERNAL_IP"

# Optional: Run health check first (warnings only)
if ! /bin/bash /healthcheck.sh; then
    echo "⚠️  Health check reported issues, continuing startup..."
fi

echo "Starting turnserver..."
# Use exec to replace the shell with turnserver (PID 1)
exec turnserver -c /etc/turnserver.conf -n --log-file=stdout
