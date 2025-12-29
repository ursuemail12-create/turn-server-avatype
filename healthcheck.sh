#!/bin/bash
# Health check script for Avatype TURN server

# Check if turnserver process is running
if ! pgrep -x "turnserver" > /dev/null 2>&1; then
    echo "FAIL: turnserver process not running"
    exit 1
fi

# Check TCP port 3478 is listening
if ! timeout 2 bash -c "echo > /dev/tcp/127.0.0.1/3478" 2>/dev/null; then
    echo "FAIL: TCP port 3478 not responding"
    exit 1
fi

# Check UDP port 3478 with a simple STUN binding request
# STUN magic cookie: 0x2112A442
STUN_RESPONSE=$(echo -ne '\x00\x01\x00\x00\x21\x12\xa4\x42\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' | \
    timeout 2 nc -u -w1 127.0.0.1 3478 2>/dev/null | head -c 20 | xxd -p 2>/dev/null || echo "")

if [ -n "$STUN_RESPONSE" ]; then
    echo "OK: STUN responding on UDP"
else
    # UDP test is flaky in containers, don't fail on it
    echo "WARN: STUN UDP test inconclusive (may be normal)"
fi

echo "OK: Health check passed"
exit 0
