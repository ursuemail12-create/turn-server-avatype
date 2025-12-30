#!/bin/bash
set -euo pipefail

echo "========================================"
echo "Avatype STUN/TURN Server - HARDENED"
echo "========================================"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

# ===========================================
# Security: Validate Environment
# ===========================================
if [ -z "${TURN_AUTH_SECRET:-}" ]; then
    echo "FATAL: TURN_AUTH_SECRET not set!"
    echo "Set it with: fly secrets set TURN_AUTH_SECRET=<your-secret>"
    exit 1
fi

if [ ${#TURN_AUTH_SECRET} -lt 32 ]; then
    echo "WARNING: TURN_AUTH_SECRET should be at least 32 characters!"
fi

# ===========================================
# Environment Variable Defaults
# ===========================================
: "${TURN_REALM:=turn.avatype.com}"
: "${TURN_MIN_PORT:=49152}"
: "${TURN_MAX_PORT:=49252}"
: "${TURN_MAX_BPS:=5000000}"
: "${TURN_TOTAL_QUOTA:=1200}"

export TURN_REALM TURN_MIN_PORT TURN_MAX_PORT TURN_MAX_BPS TURN_TOTAL_QUOTA

# ===========================================
# Detect External IP (with validation)
# ===========================================
echo "Detecting external IP..."

get_external_ip() {
    local ip=""
    for service in "https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com" "https://checkip.amazonaws.com"; do
        ip=$(curl -s --connect-timeout 3 --max-time 5 "$service" 2>/dev/null | tr -d '[:space:]') || continue
        # Validate IPv4 format
        if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # Validate each octet
            IFS='.' read -ra OCTETS <<< "$ip"
            local valid=true
            for octet in "${OCTETS[@]}"; do
                if [ "$octet" -gt 255 ]; then
                    valid=false
                    break
                fi
            done
            if $valid; then
                echo "$ip"
                return 0
            fi
        fi
    done
    return 1
}

EXTERNAL_IP=""

# Try Fly.io's provided IP first
if [ -n "${FLY_PUBLIC_IP:-}" ]; then
    EXTERNAL_IP="$FLY_PUBLIC_IP"
    echo "Using FLY_PUBLIC_IP: $EXTERNAL_IP"
else
    EXTERNAL_IP=$(get_external_ip) || true
    if [ -n "$EXTERNAL_IP" ]; then
        echo "External IP detected: $EXTERNAL_IP"
    else
        echo "ERROR: Could not detect external IP"
        exit 1
    fi
fi

# Verify it's not a private IP (security check)
if [[ "$EXTERNAL_IP" =~ ^10\. ]] || \
   [[ "$EXTERNAL_IP" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
   [[ "$EXTERNAL_IP" =~ ^192\.168\. ]] || \
   [[ "$EXTERNAL_IP" =~ ^127\. ]]; then
    echo "ERROR: Detected private IP ($EXTERNAL_IP). This won't work for TURN."
    exit 1
fi

export EXTERNAL_IP

# ===========================================
# Build Secure Command Line Arguments
# ===========================================
TURN_ARGS=(
    "-c" "/etc/turnserver.conf"
    "-n"
    "--external-ip=${EXTERNAL_IP}"
    "--static-auth-secret=${TURN_AUTH_SECRET}"
    "--realm=${TURN_REALM}"
    "--min-port=${TURN_MIN_PORT}"
    "--max-port=${TURN_MAX_PORT}"
    "--max-bps=${TURN_MAX_BPS}"
    "--total-quota=${TURN_TOTAL_QUOTA}"
)

# ===========================================
# Print Configuration (REDACTED secrets)
# ===========================================
echo "========================================"
echo "Configuration:"
echo "  External IP:  ${EXTERNAL_IP}"
echo "  Realm:        ${TURN_REALM}"
echo "  Port Range:   ${TURN_MIN_PORT}-${TURN_MAX_PORT}"
echo "  Max BPS:      ${TURN_MAX_BPS}"
echo "  Total Quota:  ${TURN_TOTAL_QUOTA}"
echo "  Auth Secret:  [REDACTED - ${#TURN_AUTH_SECRET} chars]"
echo "  Listening:    3478/udp, 3478/tcp, 5349/tcp (TLS)"
echo "========================================"

# ===========================================
# Security: Set restrictive umask
# ===========================================
umask 077

# ===========================================
# Create directories (if needed)
# ===========================================
mkdir -p /var/log/coturn 2>/dev/null || true
mkdir -p /var/run/coturn 2>/dev/null || true

# ===========================================
# Start TURN Server
# ===========================================
echo "Starting turnserver with hardened configuration..."
exec turnserver "${TURN_ARGS[@]}"
