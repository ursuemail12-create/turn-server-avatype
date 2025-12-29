#!/bin/bash
set -e

echo "========================================"
echo "Avatype STUN/TURN Server - Starting up"
echo "========================================"
echo "Date: $(date)"

# ===========================================
# Environment Variable Defaults
# ===========================================
: "${TURN_AUTH_SECRET:=$(openssl rand -hex 32)}"
: "${TURN_REALM:=turn.avatype.com}"
: "${TURN_MIN_PORT:=49152}"
: "${TURN_MAX_PORT:=49252}"

export TURN_AUTH_SECRET TURN_REALM TURN_MIN_PORT TURN_MAX_PORT

# ===========================================
# Detect External IP
# ===========================================
echo "Detecting external IP..."

# Try multiple services for reliability
EXTERNAL_IP=""
for service in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com"; do
    EXTERNAL_IP=$(curl -s --connect-timeout 5 "$service" 2>/dev/null | tr -d '[:space:]') || true
    if [[ "$EXTERNAL_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "External IP detected from $service: $EXTERNAL_IP"
        break
    fi
done

# Fallback: use Fly.io's FLY_PUBLIC_IP if available
if [ -z "$EXTERNAL_IP" ] && [ -n "$FLY_PUBLIC_IP" ]; then
    EXTERNAL_IP="$FLY_PUBLIC_IP"
    echo "Using FLY_PUBLIC_IP: $EXTERNAL_IP"
fi

# Final fallback
if [ -z "$EXTERNAL_IP" ]; then
    echo "WARNING: Could not detect external IP, using 0.0.0.0"
    EXTERNAL_IP="0.0.0.0"
fi

export EXTERNAL_IP

# ===========================================
# Build Command Line Arguments
# ===========================================
# We pass secrets via command line to avoid file permission issues
# and to ensure environment variables are properly substituted

TURN_ARGS=(
    "-c" "/etc/turnserver.conf"
    "-n"
    "--external-ip=${EXTERNAL_IP}"
    "--static-auth-secret=${TURN_AUTH_SECRET}"
    "--realm=${TURN_REALM}"
    "--min-port=${TURN_MIN_PORT}"
    "--max-port=${TURN_MAX_PORT}"
)

# ===========================================
# Print Configuration (redacted secrets)
# ===========================================
echo "========================================"
echo "Configuration:"
echo "  External IP:  ${EXTERNAL_IP}"
echo "  Realm:        ${TURN_REALM}"
echo "  Port Range:   ${TURN_MIN_PORT}-${TURN_MAX_PORT}"
echo "  Auth Secret:  ${TURN_AUTH_SECRET:0:8}...redacted"
echo "  Listening:    3478/udp, 3478/tcp, 5349/tcp"
echo "========================================"

# ===========================================
# Create necessary directories
# ===========================================
mkdir -p /var/log/coturn 2>/dev/null || true
mkdir -p /var/run/coturn 2>/dev/null || true

# ===========================================
# Start TURN Server
# ===========================================
echo "Starting turnserver..."
exec turnserver "${TURN_ARGS[@]}"
