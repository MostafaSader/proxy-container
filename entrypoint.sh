#!/bin/bash
# Don't exit on error - we want to see what's happening
set +e

# Default values
UPSTREAM_PROXY_HOST=${UPSTREAM_PROXY_HOST:-}
UPSTREAM_PROXY_PORT=${UPSTREAM_PROXY_PORT:-3128}
UPSTREAM_PROXY_USER=${UPSTREAM_PROXY_USER:-}
UPSTREAM_PROXY_PASS=${UPSTREAM_PROXY_PASS:-}
NO_PROXY=${NO_PROXY:-localhost,127.0.0.1}

# Create squid configuration
cat > /etc/squid/squid.conf <<EOF
# Basic Squid configuration
http_port 3128

# Access control - allow all (no auth required)
acl localnet src all
http_access allow localnet

# Cache settings (minimal for forwarding proxy)
cache_dir ufs /var/spool/squid 100 16 256
coredump_dir /var/spool/squid
pid_filename /var/run/squid.pid

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
EOF

# Configure upstream proxy if provided
if [ -n "$UPSTREAM_PROXY_HOST" ]; then
    # Build cache_peer line
    CACHE_PEER="cache_peer ${UPSTREAM_PROXY_HOST} parent ${UPSTREAM_PROXY_PORT} 0 no-query"
    
    # Add authentication if credentials provided
    if [ -n "$UPSTREAM_PROXY_USER" ] && [ -n "$UPSTREAM_PROXY_PASS" ]; then
        # Use password as-is without any escaping or cleaning
        CACHE_PEER="${CACHE_PEER} login=${UPSTREAM_PROXY_USER}:${UPSTREAM_PROXY_PASS}"
    fi
    
    # Add cache_peer configuration first (must be before cache_peer_access)
    # Use printf to ensure the entire line is written correctly
    printf '%s\n' "${CACHE_PEER}" >> /etc/squid/squid.conf
    
    # Add no_proxy domains
    if [ -n "$NO_PROXY" ]; then
        # Convert comma-separated list to acl lines
        IFS=',' read -ra DOMAINS <<< "$NO_PROXY"
        for domain in "${DOMAINS[@]}"; do
            domain=$(echo "$domain" | xargs) # trim whitespace
            if [ -n "$domain" ]; then
                echo "acl no_proxy_domains dstdomain ${domain}" >> /etc/squid/squid.conf
            fi
        done
        echo "cache_peer_access ${UPSTREAM_PROXY_HOST} deny no_proxy_domains" >> /etc/squid/squid.conf
    fi
    
    echo "never_direct allow all" >> /etc/squid/squid.conf
else
    # No upstream proxy - direct connection
    echo "never_direct deny all" >> /etc/squid/squid.conf
fi

# Clean up any stale PID files
rm -f /run/squid.pid /var/run/squid.pid

# Test connectivity to upstream proxy if configured
if [ -n "$UPSTREAM_PROXY_HOST" ]; then
    echo "Testing connectivity to upstream proxy ${UPSTREAM_PROXY_HOST}:${UPSTREAM_PROXY_PORT}..."
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w 2 "${UPSTREAM_PROXY_HOST}" "${UPSTREAM_PROXY_PORT}" 2>/dev/null; then
            echo "✓ Upstream proxy is reachable"
        else
            echo "⚠ Warning: Upstream proxy ${UPSTREAM_PROXY_HOST}:${UPSTREAM_PROXY_PORT} is not reachable, but continuing anyway"
        fi
    fi
fi

# Initialize squid cache directory (always run to ensure directories exist)
echo "Initializing Squid cache directory..."
# Ensure the base directory exists and has correct permissions
mkdir -p /var/spool/squid
chown -R proxy:proxy /var/spool/squid 2>/dev/null || true
chmod -R 755 /var/spool/squid

# Always create all required cache subdirectories manually first
# The cache_dir config "100 16 256" means 16 subdirectories (00-15)
echo "Creating cache subdirectories (00-15)..."
for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    # Format as two-digit number (00, 01, 02, etc.)
    dir=$(printf "%02d" $i)
    if [ ! -d "/var/spool/squid/$dir" ]; then
        mkdir -p "/var/spool/squid/$dir"
        chown proxy:proxy "/var/spool/squid/$dir" 2>/dev/null || true
        chmod 755 "/var/spool/squid/$dir"
        echo "Created /var/spool/squid/$dir"
    fi
done

# Run squid -z to initialize the cache structure (this may fail if directories already exist, which is OK)
echo "Running squid -z to initialize cache structure..."
squid -z -f /etc/squid/squid.conf 2>&1 || true

# Clean up PID file created by squid -z if any
rm -f /run/squid.pid /var/run/squid.pid

# Verify cache directories exist
if [ ! -d /var/spool/squid/00 ] || [ ! -d /var/spool/squid/01 ]; then
    echo "ERROR: Cache directories were not created properly!"
    echo "Contents of /var/spool/squid:"
    ls -la /var/spool/squid/ || true
    exit 1
fi

echo "Cache directories initialized successfully"

# Validate Squid configuration
echo "Validating Squid configuration..."
squid -k parse -f /etc/squid/squid.conf 2>&1
CONFIG_EXIT=$?
if [ $CONFIG_EXIT -ne 0 ]; then
    echo "ERROR: Squid configuration validation failed!"
    echo "Configuration file contents:"
    cat /etc/squid/squid.conf
    exit 1
fi

# Ensure log directories exist and are writable
mkdir -p /var/log/squid
chown -R proxy:proxy /var/log/squid 2>/dev/null || true
chmod -R 755 /var/log/squid

echo "Starting Squid..."
echo "Configuration summary:"
echo "  - Listening on port 3128"
if [ -n "$UPSTREAM_PROXY_HOST" ]; then
    echo "  - Upstream proxy: ${UPSTREAM_PROXY_HOST}:${UPSTREAM_PROXY_PORT}"
    if [ -n "$UPSTREAM_PROXY_USER" ]; then
        echo "  - Authentication: enabled"
    fi
fi

# Show last few lines of config for debugging
echo ""
echo "Last few lines of Squid config:"
tail -5 /etc/squid/squid.conf

# Show the cache_peer line to verify it's written correctly
echo ""
echo "Cache peer configuration line:"
grep "^cache_peer" /etc/squid/squid.conf | head -1
echo "(Length: $(grep "^cache_peer" /etc/squid/squid.conf | head -1 | wc -c) characters)"

# Check if cache log exists and show recent errors before starting
if [ -f /var/log/squid/cache.log ]; then
    echo ""
    echo "Recent cache.log entries:"
    tail -20 /var/log/squid/cache.log
fi

# Execute the command
# Run in foreground - all stderr/stdout will be visible
exec "$@"

