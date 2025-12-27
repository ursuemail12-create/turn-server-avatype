#!/bin/bash
set -e

echo "🚀 Deploying Avatype STUN/TURN Server to Fly.io"

# Install flyctl if not installed
if ! command -v flyctl &> /dev/null; then
    echo "📦 Installing flyctl..."
    curl -L https://fly.io/install.sh | sh
    export PATH="$HOME/.fly/bin:$PATH"
fi

# Login to Fly.io
echo "🔑 Logging into Fly.io..."
flyctl auth login

# Create app if it doesn't exist
if ! flyctl apps list | grep -q "avatype-turn"; then
    echo "🆕 Creating new app..."
    flyctl apps create avatype-turn --machines
else
    echo "✅ App already exists"
fi

# Set secrets if not set
if ! flyctl secrets list | grep -q "COTURN_AUTH_SECRET"; then
    echo "🔐 Setting secrets..."
    flyctl secrets set COTURN_AUTH_SECRET=$(openssl rand -hex 32)
    flyctl secrets set COTURN_PASSWORD=$(openssl rand -hex 16)
fi

# Allocate IPv4 address if not allocated
if ! flyctl ips list | grep -q "v4"; then
    echo "🌐 Allocating IPv4 address..."
    flyctl ips allocate-v4
fi

# Deploy the application
echo "🚀 Deploying..."
flyctl deploy --remote-only --build-arg VERSION=$(date +%s)

# Get the public IP
echo "📡 Getting server info..."
PUBLIC_IP=$(flyctl ips list | grep "v4" | awk '{print $3}')
echo "✅ Server deployed!"
echo "🌐 Public IP: $PUBLIC_IP"
echo "🔗 STUN URL: stun:turn.avatype.fly.dev:3478"
echo "🔗 TURN URL: turn:turn.avatype.fly.dev:3478"
echo "👤 Username: avatype"
echo "🔑 Password: (check flyctl secrets list)"

# Test the server
echo "🧪 Testing server..."
sleep 10
curl -s "http://turn.avatype.fly.dev:3478" || true
echo "✅ Deployment complete!"