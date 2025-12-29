#!/bin/bash
set -e

echo "🚀 Starting Avatype STUN Server"

# Auto-detect external IP for Fly.io
if [ -z "$COTURN_EXTERNAL_IP" ]; then
    echo "🔍 Auto-detecting external IP..."
    
    # Try multiple methods to get external IP
    COTURN_EXTERNAL_IP=$(curl -s --connect-timeout 3 https://ifconfig.me 2>/dev/null || \
                         curl -s --connect-timeout 3 https://icanhazip.com 2>/dev/null || \
                         curl -s --connect-timeout 3 https://api.ipify.org 2>/dev/null || \
                         echo "auto")
    
    echo "✅ Detected IP: $COTURN_EXTERNAL_IP"
    export COTURN_EXTERNAL_IP
fi

# Generate password if not set
if [ -z "$COTURN_PASSWORD" ]; then
    export COTURN_PASSWORD=$(openssl rand -hex 16)
    echo "🔑 Generated password: ${COTURN_PASSWORD}"
fi

# Create necessary directories
mkdir -p /var/log/coturn
chown turnserver:turnserver /var/log/coturn

# Generate final config file with environment variables
echo "📝 Generating configuration..."
cat > /etc/coturn/turnserver-final.conf <<EOF
# Generated configuration
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
external-ip=${COTURN_EXTERNAL_IP}
realm=${COTURN_REALM:-turn-server-avatype.fly.dev}
server-name=avatype-turn-server
lt-cred-mech
user=${COTURN_USER:-avatype}:${COTURN_PASSWORD}
min-port=${COTURN_MIN_PORT:-49152}
max-port=${COTURN_MAX_PORT:-65535}
log-file=stdout
simple-log
stun-only
no-tcp-relay
no-udp-relay
fingerprint
verbose
EOF

echo "📋 Configuration summary:"
echo "========================="
grep -E "^(listening-port|external-ip|realm|user)" /etc/coturn/turnserver-final.conf
echo "========================="

# Start simple HTTP server for Fly.io health checks
echo "🌐 Starting health check server on port 8080..."
nohup bash -c 'while true; do { echo -e "HTTP/1.1 200 OK\r\n\r\nOK"; } | nc -l -p 8080 -q 1; done' > /dev/null 2>&1 &

# Start coturn
echo "🎯 Starting coturn STUN server..."
exec turnserver -c /etc/coturn/turnserver-final.conf -n