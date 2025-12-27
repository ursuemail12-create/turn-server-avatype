#!/bin/bash
set -e

echo "🚀 Starting Avatype STUN/TURN Server"

# Auto-detect external IP if not set
if [ -z "$COTURN_EXTERNAL_IP" ]; then
    echo "🔍 Auto-detecting external IP..."
    
    # Try multiple methods to get external IP
    if [ -n "$FLY_ALLOC_ID" ]; then
        # On Fly.io, get the private IP and map to public
        COTURN_EXTERNAL_IP=$(flyctl ips list --json | jq -r '.[] | select(.type == "v4") | .address' 2>/dev/null || true)
    fi
    
    if [ -z "$COTURN_EXTERNAL_IP" ]; then
        COTURN_EXTERNAL_IP=$(curl -s -4 --connect-timeout 2 ifconfig.me 2>/dev/null || \
                            curl -s -4 --connect-timeout 2 icanhazip.com 2>/dev/null || \
                            curl -s -4 --connect-timeout 2 ipinfo.io/ip 2>/dev/null || \
                            echo "auto")
    fi
    
    echo "✅ Using external IP: $COTURN_EXTERNAL_IP"
    export COTURN_EXTERNAL_IP
fi

# Generate auth secret if not set
if [ -z "$COTURN_AUTH_SECRET" ]; then
    export COTURN_AUTH_SECRET=$(openssl rand -hex 32)
    echo "🔑 Generated auth secret: ${COTURN_AUTH_SECRET:0:8}..."
fi

# Create directory for logs and data
mkdir -p /var/lib/coturn /var/log/coturn
chown -R turnserver:turnserver /var/lib/coturn /var/log/coturn

# Generate user credentials if not set
if [ -z "$COTURN_USER" ] || [ -z "$COTURN_PASSWORD" ]; then
    export COTURN_USER="avatype_$(openssl rand -hex 4)"
    export COTURN_PASSWORD=$(openssl rand -hex 16)
    echo "👤 Generated credentials:"
    echo "   Username: $COTURN_USER"
    echo "   Password: $COTURN_PASSWORD"
fi

# Substitute environment variables in config
echo "📝 Generating configuration..."
envsubst < /etc/coturn/turnserver.conf > /etc/coturn/turnserver-resolved.conf

# Print config for debugging (remove in production)
echo "📋 Final Configuration:"
echo "========================"
grep -E "^(listening-port|external-ip|realm|min-port|max-port)" /etc/coturn/turnserver-resolved.conf || true
echo "========================"

# Start coturn
echo "🎯 Starting coturn server..."
exec turnserver -c /etc/coturn/turnserver-resolved.conf "$@"