#!/bin/bash
set -e

APP_NAME="avatype-turn"

echo "🚀 Deploying Avatype STUN/TURN Server to Fly.io"
echo "================================================"

# ===========================================
# Check for flyctl
# ===========================================
if ! command -v flyctl &> /dev/null; then
    echo "📦 flyctl not found. Installing..."
    curl -L https://fly.io/install.sh | sh
    export PATH="$HOME/.fly/bin:$PATH"
fi

# Verify flyctl is available
if ! command -v flyctl &> /dev/null; then
    echo "❌ Failed to install flyctl"
    exit 1
fi

# ===========================================
# Authentication
# ===========================================
echo ""
echo "🔑 Checking Fly.io authentication..."
if ! flyctl auth whoami &> /dev/null; then
    echo "Please log in to Fly.io:"
    flyctl auth login
fi
echo "✅ Authenticated as: $(flyctl auth whoami)"

# ===========================================
# Create App if Needed
# ===========================================
echo ""
echo "🔍 Checking if app exists..."
if ! flyctl apps list 2>/dev/null | grep -q "$APP_NAME"; then
    echo "🆕 Creating new app: $APP_NAME"
    flyctl apps create "$APP_NAME" --machines
else
    echo "✅ App '$APP_NAME' already exists"
fi

# ===========================================
# Set Secrets
# ===========================================
echo ""
echo "🔐 Configuring secrets..."
EXISTING_SECRETS=$(flyctl secrets list -a "$APP_NAME" 2>/dev/null || echo "")

if ! echo "$EXISTING_SECRETS" | grep -q "TURN_AUTH_SECRET"; then
    echo "Setting TURN_AUTH_SECRET..."
    SECRET=$(openssl rand -hex 32)
    flyctl secrets set TURN_AUTH_SECRET="$SECRET" -a "$APP_NAME"
    echo "✅ TURN_AUTH_SECRET set"
    echo ""
    echo "📋 IMPORTANT: Save this secret for your WebRTC clients:"
    echo "   TURN_AUTH_SECRET=$SECRET"
    echo ""
else
    echo "✅ TURN_AUTH_SECRET already configured"
fi

# ===========================================
# Allocate IP Address
# ===========================================
echo ""
echo "🌐 Checking IP allocation..."
EXISTING_IPS=$(flyctl ips list -a "$APP_NAME" 2>/dev/null || echo "")

if ! echo "$EXISTING_IPS" | grep -q "v4"; then
    echo "Allocating dedicated IPv4 address..."
    flyctl ips allocate-v4 -a "$APP_NAME"
fi

if ! echo "$EXISTING_IPS" | grep -q "v6"; then
    echo "Allocating IPv6 address..."
    flyctl ips allocate-v6 -a "$APP_NAME"
fi

echo "✅ IP addresses:"
flyctl ips list -a "$APP_NAME"

# ===========================================
# Deploy
# ===========================================
echo ""
echo "🚀 Deploying application..."
flyctl deploy --app "$APP_NAME" --remote-only

# ===========================================
# Verify Deployment
# ===========================================
echo ""
echo "🔍 Verifying deployment..."
sleep 5

flyctl status -a "$APP_NAME"

# ===========================================
# Get Connection Info
# ===========================================
echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""

PUBLIC_IP=$(flyctl ips list -a "$APP_NAME" | grep "v4" | awk '{print $2}' | head -1)
PUBLIC_IPV6=$(flyctl ips list -a "$APP_NAME" | grep "v6" | awk '{print $2}' | head -1)

echo "📡 Connection Information:"
echo ""
echo "  STUN Server:"
echo "    stun:${APP_NAME}.fly.dev:3478"
echo "    stun:${PUBLIC_IP}:3478"
echo ""
echo "  TURN Server:"
echo "    turn:${APP_NAME}.fly.dev:3478"
echo "    turn:${PUBLIC_IP}:3478"
echo ""
echo "  TURNS Server (TLS):"
echo "    turns:${APP_NAME}.fly.dev:5349"
echo ""
echo "  Realm: turn.avatype.com"
echo ""
echo "📋 To get your auth secret:"
echo "    flyctl secrets list -a $APP_NAME"
echo ""
echo "📋 To generate TURN credentials (time-limited):"
echo "    Username: $(date +%s)"
echo "    Password: Use HMAC-SHA1 of username with TURN_AUTH_SECRET"
echo ""
echo "📋 Useful commands:"
echo "    flyctl logs -a $APP_NAME        # View logs"
echo "    flyctl status -a $APP_NAME      # Check status"
echo "    flyctl ssh console -a $APP_NAME # SSH into container"
echo ""
