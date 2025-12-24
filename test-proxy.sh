#!/bin/bash

# Proxy test script
# Tests if the proxy is working correctly
# Set PROXY_USER and PROXY_PASS environment variables if authentication is enabled

PROXY_HOST="${PROXY_HOST:-localhost}"
PROXY_PORT="${PROXY_PORT:-3128}"
PROXY_USER="${PROXY_USER:-}"
PROXY_PASS="${PROXY_PASS:-}"
PROXY_URL="http://${PROXY_HOST}:${PROXY_PORT}"

# Check if authentication is enabled
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    AUTH_INFO=" (authenticated as ${PROXY_USER})"
    USE_AUTH=1
else
    AUTH_INFO=""
    USE_AUTH=0
fi

# Helper function to run curl with optional authentication
run_curl() {
    if [ $USE_AUTH -eq 1 ]; then
        curl --proxy-user "${PROXY_USER}:${PROXY_PASS}" --proxy "${PROXY_URL}" "$@"
    else
        curl --proxy "${PROXY_URL}" "$@"
    fi
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Proxy Test Script"
echo "=========================================="
echo "Testing proxy at: ${PROXY_URL}${AUTH_INFO}"
echo ""

# Test 1: Check if proxy is accessible
echo -n "Test 1: Checking if proxy is accessible... "
if run_curl -s --connect-timeout 5 http://www.google.com > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  Error: Cannot connect to proxy or proxy is not responding"
    exit 1
fi

# Test 2: Test HTTP request through proxy
echo -n "Test 2: Testing HTTP request through proxy... "
RESPONSE=$(run_curl -s -w "\n%{http_code}" --max-time 10 http://httpbin.org/ip 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "  Response: $BODY"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  HTTP Code: $HTTP_CODE"
    echo "  Response: $BODY"
fi

# Test 3: Test HTTPS request through proxy
echo -n "Test 3: Testing HTTPS request through proxy... "
RESPONSE=$(run_curl -s -w "\n%{http_code}" --max-time 10 https://httpbin.org/ip 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "  Response: $BODY"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  HTTP Code: $HTTP_CODE"
    echo "  Response: $BODY"
fi

# Test 4: Test with a simple GET request
echo -n "Test 4: Testing GET request... "
RESPONSE=$(run_curl -s -w "\n%{http_code}" --max-time 10 http://httpbin.org/get 2>&1)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
    echo "  HTTP Code: $HTTP_CODE"
fi

# Test 5: Check proxy headers
echo -n "Test 5: Checking proxy headers... "
HEADERS=$(run_curl -s -I --max-time 10 http://httpbin.org/headers 2>&1)
if echo "$HEADERS" | grep -q "HTTP/"; then
    echo -e "${GREEN}✓ PASS${NC}"
    echo "  Headers received successfully"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Test 6: Test response time
echo -n "Test 6: Measuring response time... "
START_TIME=$(date +%s%N)
run_curl -s --max-time 10 http://httpbin.org/ip > /dev/null 2>&1
END_TIME=$(date +%s%N)
DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
echo -e "${GREEN}✓ PASS${NC}"
echo "  Response time: ${DURATION}ms"

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Proxy URL: ${PROXY_URL}"
echo "All tests completed!"
echo ""
echo "To test manually, use:"
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    echo "  curl --proxy-user \"${PROXY_USER}:${PROXY_PASS}\" --proxy ${PROXY_URL} http://example.com"
else
    echo "  curl --proxy ${PROXY_URL} http://example.com"
fi
echo ""

