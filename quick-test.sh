#!/bin/bash

# Quick proxy test
# Usage: ./quick-test.sh [proxy_host] [proxy_port]

PROXY_HOST="${1:-localhost}"
PROXY_PORT="${2:-3128}"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

echo "Testing proxy at ${PROXY_URL}..."
echo ""

# Simple test
if curl -s --proxy "${PROXY_URL}" --max-time 10 http://httpbin.org/ip > /dev/null 2>&1; then
    echo "✓ Proxy is working!"
    echo ""
    echo "Your IP through proxy:"
    curl -s --proxy "${PROXY_URL}" http://httpbin.org/ip
    echo ""
else
    echo "✗ Proxy test failed!"
    echo "Make sure the proxy is running on ${PROXY_URL}"
    exit 1
fi

