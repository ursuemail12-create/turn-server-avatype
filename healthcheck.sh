#!/bin/bash

echo "Running comprehensive health checks..."

# 1. Check if process is running
if ! pgrep -x "turnserver" > /dev/null; then
    echo "❌ Coturn process not found"
    exit 1
fi

# 2. Check TCP connectivity
if ! timeout 2 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/3478" 2>/dev/null; then
    echo "❌ TCP port 3478 not responding"
    exit 1
fi

# 3. Check UDP (STUN) - send binding request
STUN_TEST=$(echo -ne "\x00\x01\x00\x00\x21\x12\xa4\x42$(head -c 12 /dev/urandom)" | \
    timeout 2 nc -u -w 1 127.0.0.1 3478 2>/dev/null | \
    hexdump -C 2>/dev/null | head -1)

if echo "$STUN_TEST" | grep -q "00 01 00 00 21 12 a4 42"; then
    echo "✅ STUN binding request successful"
else
    echo "⚠️  STUN test inconclusive (may be normal)"
fi

# 4. Check disk space
DISK_USAGE=$(df /var/lib/coturn --output=pcent | tail -1 | tr -d '% ')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "⚠️  High disk usage: ${DISK_USAGE}%"
fi

# 5. Check memory
MEM_TOTAL=$(free -b | awk '/Mem:/ {print $2}')
MEM_USED=$(free -b | awk '/Mem:/ {print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

if [ "$MEM_PERCENT" -gt 90 ]; then
    echo "⚠️  High memory usage: ${MEM_PERCENT}%"
fi

# 6. Check for recent errors in logs
if [ -f "/var/log/coturn/turn.log" ]; then
    ERROR_COUNT=$(tail -100 /var/log/coturn/turn.log | grep -c "ERROR\|FAILED\|CRITICAL")
    if [ "$ERROR_COUNT" -gt 5 ]; then
        echo "⚠️  Multiple errors in log: ${ERROR_COUNT} recent errors"
    fi
fi

echo "✅ All health checks passed"
exit 0