#!/bin/bash

# Quick proxy test
# Usage: ./quick-test.sh [proxy_host] [proxy_port] [proxy_user] [proxy_pass]
# Or set PROXY_USER and PROXY_PASS environment variables

PROXY_HOST="${1:-localhost}"
PROXY_PORT="${2:-3128}"
PROXY_USER="${3:-${PROXY_USER:-}}"
PROXY_PASS="${4:-${PROXY_PASS:-}}"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

echo "Testing proxy at ${PROXY_URL}..."
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    echo "Using authentication: ${PROXY_USER}"
fi
echo ""

# Simple test with optional authentication
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    # Test with authentication
    if curl -s --proxy-user "${PROXY_USER}:${PROXY_PASS}" --proxy "${PROXY_URL}" --max-time 10 http://httpbin.org/ip > /dev/null 2>&1; then
        echo "✓ Proxy is working!"
        echo ""
        echo "Your IP through proxy:"
        curl -s --proxy-user "${PROXY_USER}:${PROXY_PASS}" --proxy "${PROXY_URL}" http://httpbin.org/ip
        echo ""
    else
        echo "✗ Proxy test failed!"
        echo "Make sure the proxy is running on ${PROXY_URL} and credentials are correct"
        exit 1
    fi
else
    # Test without authentication
    if curl -s --proxy "${PROXY_URL}" --max-time 10 http://httpbin.org/ip > /dev/null 2>&1; then
        echo "✓ Proxy is working!"
        echo ""
        echo "Your IP through proxy:"
        curl -s --proxy "${PROXY_URL}" http://httpbin.org/ip
        echo ""
    else
        echo "✗ Proxy test failed!"
        echo "Make sure the proxy is running on ${PROXY_URL}"
        echo "Note: If authentication is enabled, set PROXY_USER and PROXY_PASS environment variables"
        exit 1
    fi
fi

