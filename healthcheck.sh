#!/bin/bash

# Health check for STUN/TURN server

# Check if coturn process is running
if ! pgrep -x "turnserver" > /dev/null; then
    echo "❌ Coturn process not running"
    exit 1
fi

# Check STUN service on UDP
if ! nc -z -u 127.0.0.1 3478 2>/dev/null; then
    echo "❌ STUN UDP port 3478 not responding"
    exit 1
fi

# Check TURN service on TCP (fallback)
if ! nc -z 127.0.0.1 3478 2>/dev/null; then
    echo "❌ TURN TCP port 3478 not responding"
    exit 1
fi

# Optional: Send actual STUN binding request
STUN_TEST=$(echo -ne "\x00\x01\x00\x00\x21\x12\xa4\x42TESTTESTTEST" | \
            timeout 2 nc -u -w 1 127.0.0.1 3478 2>/dev/null | \
            xxd -p 2>/dev/null | head -c 20)

if [ -z "$STUN_TEST" ]; then
    echo "⚠️  STUN binding request failed (but ports are open)"
    # Don't exit with error, just warning
fi

# Check disk space
DISK_SPACE=$(df /var/lib/coturn --output=pcent | tail -1 | tr -d '% ')
if [ "$DISK_SPACE" -gt 90 ]; then
    echo "⚠️  Disk space low: $DISK_SPACE%"
fi

# Check memory usage
MEM_USAGE=$(free | awk '/Mem:/ {printf "%d", $3/$2 * 100}')
if [ "$MEM_USAGE" -gt 90 ]; then
    echo "⚠️  Memory usage high: $MEM_USAGE%"
fi

echo "✅ STUN/TURN server healthy"
exit 0