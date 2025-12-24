#!/bin/bash
# Don't exit on error - we want to see what's happening
set +e

# Default values
UPSTREAM_PROXY_HOST=${UPSTREAM_PROXY_HOST:-}
UPSTREAM_PROXY_PORT=${UPSTREAM_PROXY_PORT:-3128}
UPSTREAM_PROXY_USER=${UPSTREAM_PROXY_USER:-}
UPSTREAM_PROXY_PASS=${UPSTREAM_PROXY_PASS:-}
NO_PROXY=${NO_PROXY:-localhost,127.0.0.1}

# Security configuration
PROXY_USER=${PROXY_USER:-}
PROXY_PASS=${PROXY_PASS:-}
PROXY_BIND_ADDRESS=${PROXY_BIND_ADDRESS:-127.0.0.1}
PROXY_PORT=${PROXY_PORT:-3128}
ALLOWED_IPS=${ALLOWED_IPS:-}
RATE_LIMIT=${RATE_LIMIT:-100}

# Function to sanitize password - escape special characters for Squid config
sanitize_password() {
    local password="$1"
    # Escape backslashes first, then colons, spaces, and other special chars
    echo "$password" | sed 's/\\/\\\\/g' | sed 's/:/\\:/g' | sed 's/ /\\ /g' | sed 's/\n/\\n/g'
}

# Function to validate and sanitize domain name
sanitize_domain() {
    local domain="$1"
    # Remove whitespace
    domain=$(echo "$domain" | xargs | tr -d '[:space:]')
    # Only allow alphanumeric, dots, hyphens, asterisks (for wildcards), and underscores
    # Reject anything that looks like a command injection attempt
    if echo "$domain" | grep -qE '^[a-zA-Z0-9._*-]+$' && ! echo "$domain" | grep -qE '[;&|`$(){}]'; then
        echo "$domain"
    else
        echo ""
    fi
}

# Create squid configuration
cat > /etc/squid/squid.conf <<EOF
# Basic Squid configuration
http_port ${PROXY_BIND_ADDRESS}:${PROXY_PORT}

# Access control lists
acl localnet src 127.0.0.1/32 ::1
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16

# Rate limiting to prevent abuse (limit concurrent connections per IP)
acl max_conn maxconn ${RATE_LIMIT}
EOF

# Add allowed IPs if configured
if [ -n "$ALLOWED_IPS" ]; then
    IFS=',' read -ra IPS <<< "$ALLOWED_IPS"
    for ip in "${IPS[@]}"; do
        ip=$(echo "$ip" | xargs)
        if [ -n "$ip" ]; then
            # Basic IP validation (CIDR or single IP)
            if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$|^([0-9a-fA-F:]+)(/[0-9]{1,3})?$'; then
                echo "acl allowed_ips src ${ip}" >> /etc/squid/squid.conf
            fi
        fi
    done
fi

# Configure authentication if credentials provided
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    echo "Configuring basic authentication..."
    # Install apache2-utils if not already installed (for htpasswd)
    if ! command -v htpasswd >/dev/null 2>&1; then
        apt-get update -qq && apt-get install -y -qq apache2-utils >/dev/null 2>&1
    fi
    
    # Create password file
    mkdir -p /etc/squid
    # Sanitize password before creating htpasswd entry
    SANITIZED_PASS=$(sanitize_password "$PROXY_PASS")
    echo "$PROXY_PASS" | htpasswd -ci /etc/squid/passwords "$PROXY_USER" 2>/dev/null
    
    # Configure auth in Squid
    cat >> /etc/squid/squid.conf <<EOF

# Authentication configuration
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwords
auth_param basic children 5
auth_param basic realm Proxy
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED
EOF
    
    # Set access rules with authentication
    if [ -n "$ALLOWED_IPS" ]; then
        cat >> /etc/squid/squid.conf <<EOF
# Allow authenticated users and allowed IPs (before rate limiting)
http_access allow authenticated
http_access allow allowed_ips
http_access allow localnet
EOF
    else
        cat >> /etc/squid/squid.conf <<EOF
# Allow authenticated users and localnet (before rate limiting)
http_access allow authenticated
http_access allow localnet
EOF
    fi
else
    # No authentication - only allow localnet and optionally allowed IPs
    if [ -n "$ALLOWED_IPS" ]; then
        cat >> /etc/squid/squid.conf <<EOF
# Allow localnet and explicitly allowed IPs only (no authentication, before rate limiting)
http_access allow localnet
http_access allow allowed_ips
EOF
    else
        cat >> /etc/squid/squid.conf <<EOF
# Allow localnet only (no authentication, restricted to local network, before rate limiting)
http_access allow localnet
EOF
    fi
fi

# Rate limiting: deny excessive connections (after allowing legitimate users)
cat >> /etc/squid/squid.conf <<EOF
# Deny clients with excessive concurrent connections
http_access deny max_conn

# Deny all other access
http_access deny all

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
    # Validate upstream proxy host (basic validation)
    if echo "$UPSTREAM_PROXY_HOST" | grep -qE '[;&|`$(){}]'; then
        echo "ERROR: Invalid characters in UPSTREAM_PROXY_HOST"
        exit 1
    fi
    
    # Validate port is numeric
    if ! echo "$UPSTREAM_PROXY_PORT" | grep -qE '^[0-9]+$'; then
        echo "ERROR: UPSTREAM_PROXY_PORT must be numeric"
        exit 1
    fi
    
    # Build cache_peer line with sanitized values
    CACHE_PEER="cache_peer ${UPSTREAM_PROXY_HOST} parent ${UPSTREAM_PROXY_PORT} 0 no-query"
    
    # Add authentication if credentials provided
    if [ -n "$UPSTREAM_PROXY_USER" ] && [ -n "$UPSTREAM_PROXY_PASS" ]; then
        # Sanitize username and password to prevent injection
        SANITIZED_USER=$(echo "$UPSTREAM_PROXY_USER" | sed 's/:/\\:/g' | sed 's/ /\\ /g')
        SANITIZED_PASS=$(sanitize_password "$UPSTREAM_PROXY_PASS")
        CACHE_PEER="${CACHE_PEER} login=${SANITIZED_USER}:${SANITIZED_PASS}"
    fi
    
    # Add cache_peer configuration first (must be before cache_peer_access)
    # Use printf to ensure the entire line is written correctly
    printf '%s\n' "${CACHE_PEER}" >> /etc/squid/squid.conf
    
    # Add no_proxy domains with validation
    if [ -n "$NO_PROXY" ]; then
        # Convert comma-separated list to acl lines
        IFS=',' read -ra DOMAINS <<< "$NO_PROXY"
        VALID_DOMAINS=()
        for domain in "${DOMAINS[@]}"; do
            SANITIZED_DOMAIN=$(sanitize_domain "$domain")
            if [ -n "$SANITIZED_DOMAIN" ]; then
                VALID_DOMAINS+=("$SANITIZED_DOMAIN")
            else
                echo "WARNING: Skipping invalid domain in NO_PROXY: $domain"
            fi
        done
        
        if [ ${#VALID_DOMAINS[@]} -gt 0 ]; then
            for domain in "${VALID_DOMAINS[@]}"; do
                echo "acl no_proxy_domains dstdomain ${domain}" >> /etc/squid/squid.conf
            done
            echo "cache_peer_access ${UPSTREAM_PROXY_HOST} deny no_proxy_domains" >> /etc/squid/squid.conf
        fi
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
echo "  - Listening on ${PROXY_BIND_ADDRESS}:${PROXY_PORT}"
echo "  - Rate limit: ${RATE_LIMIT} connections"
if [ -n "$PROXY_USER" ] && [ -n "$PROXY_PASS" ]; then
    echo "  - Proxy authentication: enabled (user: ${PROXY_USER})"
else
    echo "  - Proxy authentication: disabled (localnet only)"
fi
if [ -n "$ALLOWED_IPS" ]; then
    echo "  - Allowed IPs: ${ALLOWED_IPS}"
fi
if [ -n "$UPSTREAM_PROXY_HOST" ]; then
    echo "  - Upstream proxy: ${UPSTREAM_PROXY_HOST}:${UPSTREAM_PROXY_PORT}"
    if [ -n "$UPSTREAM_PROXY_USER" ]; then
        echo "  - Upstream authentication: enabled"
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

