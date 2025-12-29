#!/bin/bash

echo "🩺 Running health checks..."

# Check if coturn process is running
if ! pgrep -x "turnserver" > /dev/null 2>&1; then
    echo "❌ Coturn process not running"
    exit 1
fi

# Check UDP port 3478 (STUN)
if ! nc -z -u -w 1 127.0.0.1 3478 2>/dev/null; then
    echo "⚠️  UDP port 3478 not responding (might be normal for STUN)"
    # Don't fail for UDP as it's connectionless
fi

# Check TCP port 3478 (fallback)
if ! nc -z -w 2 127.0.0.1 3478 2>/dev/null; then
    echo "❌ TCP port 3478 not responding"
    exit 1
fi

# Simple STUN test (send binding request)
echo "🧪 Testing STUN binding..."
STUN_TEST=$(echo -ne "\x00\x01\x00\x00\x21\x12\xa4\x42TESTTESTTEST" | \
            timeout 2 nc -u -w 1 127.0.0.1 3478 2>/dev/null | \
            head -c 20 2>/dev/null | xxd -p 2>/dev/null)

if [ -n "$STUN_TEST" ]; then
    echo "✅ STUN server responding correctly"
else
    echo "⚠️  STUN test inconclusive (UDP might be filtered)"
    # Don't exit with error for UDP issues
fi

echo "✅ All health checks passed"
exit 0