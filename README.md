# Proxy Docker Setup

A Docker-based proxy server that connects to an upstream proxy with authentication and provides a proxy service without authentication on port 3128.

## Features

- Connects to an upstream proxy with username/password authentication
- **Secure by default**: Proxy requires authentication and is bound to localhost
- **Rate limiting**: Prevents abuse and bandwidth exhaustion
- **Input validation**: All inputs are sanitized to prevent injection attacks
- Supports NO_PROXY configuration to bypass proxy for specific domains
- Automatic cache directory initialization
- Health checks and automatic restart

## Prerequisites

- Docker and Docker Compose installed
- Access to an upstream proxy server

## Quick Start

1. **Clone or download this repository**

2. **Set up environment variables**

   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

3. **Edit `.env` with your proxy credentials**

   ```bash
   # Upstream proxy configuration (optional)
   UPSTREAM_PROXY_HOST=your-proxy-host.com
   UPSTREAM_PROXY_PORT=3128
   UPSTREAM_PROXY_USER=your-username
   UPSTREAM_PROXY_PASS=your-password
   NO_PROXY=localhost,127.0.0.1,*.local
   
   # Security configuration (required for authentication)
   PROXY_USER=myproxyuser
   PROXY_PASS=mysecurepassword
   
   # Optional security settings
   PROXY_BIND_ADDRESS=0.0.0.0    # Bind to all interfaces (0.0.0.0) or localhost (127.0.0.1)
   PROXY_PORT=3128               # Proxy port (default: 3128)
   ALLOWED_IPS=10.0.0.0/8        # Comma-separated IPs/CIDRs to allow (optional)
   RATE_LIMIT=100                # Max connections per client (default: 100)
   ```

4. **Build and start the container**

   ```bash
   docker-compose up -d
   ```

5. **Test the proxy**

   ```bash
   ./quick-test.sh
   ```

   Or use curl directly:
   ```bash
   curl --proxy http://localhost:3128 http://httpbin.org/ip
   ```

## Configuration

### Environment Variables

All configuration is done through the `.env` file:

#### Upstream Proxy Configuration (Optional)

| Variable | Description | Example |
|----------|-------------|---------|
| `UPSTREAM_PROXY_HOST` | Hostname or IP of upstream proxy | `proxy.example.com` |
| `UPSTREAM_PROXY_PORT` | Port of upstream proxy | `3128` |
| `UPSTREAM_PROXY_USER` | Username for upstream proxy | `your-username` |
| `UPSTREAM_PROXY_PASS` | Password for upstream proxy | `your-password` |
| `NO_PROXY` | Comma-separated domains to bypass | `localhost,127.0.0.1,*.local` |

#### Security Configuration (Recommended)

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `PROXY_USER` | Username for proxy authentication | *(none)* | `myuser` |
| `PROXY_PASS` | Password for proxy authentication | *(none)* | `mypassword` |
| `PROXY_BIND_ADDRESS` | IP address to bind proxy to | `127.0.0.1` | `0.0.0.0` (all interfaces) or `127.0.0.1` (localhost only) |
| `PROXY_PORT` | Port for proxy service | `3128` | `3128` |
| `ALLOWED_IPS` | Comma-separated IPs/CIDRs allowed without auth | *(none)* | `10.0.0.0/8,192.168.1.0/24` |
| `RATE_LIMIT` | Maximum connections per client | `100` | `50` |

**Security Note**: If `PROXY_USER` and `PROXY_PASS` are not set, the proxy will only allow connections from localhost and private networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16). For production use, always set authentication credentials.

### Port Configuration

The proxy listens on port `3128` by default. To change it, modify the port mapping in `docker-compose.yml`:

```yaml
ports:
  - "3128:3128"  # Change the first number to your desired host port
```

## Usage

### Using the Proxy

Once the container is running, you can use the proxy on `localhost:3128`:

**If authentication is enabled** (PROXY_USER and PROXY_PASS set):

```bash
# HTTP request with authentication
curl --proxy-user "${PROXY_USER}:${PROXY_PASS}" --proxy http://localhost:3128 http://example.com

# Or inline
curl --proxy-user "myuser:mypassword" --proxy http://localhost:3128 http://example.com

# HTTPS request
curl --proxy-user "${PROXY_USER}:${PROXY_PASS}" --proxy http://localhost:3128 https://example.com
```

**If authentication is disabled** (only localhost access):

```bash
# HTTP request (from localhost only)
curl --proxy http://localhost:3128 http://example.com

# HTTPS request
curl --proxy http://localhost:3128 https://example.com
```

**With verbose output**:
```bash
curl -v --proxy-user "${PROXY_USER}:${PROXY_PASS}" --proxy http://localhost:3128 http://example.com
```

### Testing Scripts

Two test scripts are provided:

1. **Quick Test** (`quick-test.sh`)
   ```bash
   ./quick-test.sh
   ```
   Simple one-liner test that checks if the proxy works.

2. **Comprehensive Test** (`test-proxy.sh`)
   ```bash
   ./test-proxy.sh
   ```
   Runs multiple tests including HTTP/HTTPS, headers, and response time.

## Docker Commands

### Start the proxy
```bash
docker-compose up -d
```

### Stop the proxy
```bash
docker-compose down
```

### View logs
```bash
docker-compose logs -f
```

### Rebuild after changes
```bash
docker-compose down
docker-compose build
docker-compose up -d
```

### Check container status
```bash
docker-compose ps
```

## Architecture

The setup uses:
- **Squid** as the proxy server
- **Ubuntu 22.04** as the base image
- Automatic cache directory initialization
- Health checks for container monitoring

## Troubleshooting

### Container exits immediately

Check the logs:
```bash
docker-compose logs
```

Common issues:
- Upstream proxy is not reachable
- Cache directories not initialized (should be automatic)
- Configuration errors

### Proxy not accessible

1. Verify the container is running:
   ```bash
   docker-compose ps
   ```

2. Check if port 3128 is available:
   ```bash
   netstat -an | grep 3128
   ```

3. Test connectivity:
   ```bash
   curl -v --proxy http://localhost:3128 http://httpbin.org/ip
   ```

### Upstream proxy connection issues

1. Verify the upstream proxy is reachable from the container:
   ```bash
   docker-compose exec proxy nc -zv UPSTREAM_PROXY_HOST UPSTREAM_PROXY_PORT
   ```

2. Check credentials in `.env` file

3. Verify network connectivity (especially on macOS where Docker runs in a VM)

## Security Features

### Implemented Security Measures

✅ **Authentication**: Basic HTTP authentication is supported (set `PROXY_USER` and `PROXY_PASS`)

✅ **Network Binding**: By default, proxy binds to `127.0.0.1` (localhost only) to prevent external access. Set `PROXY_BIND_ADDRESS=0.0.0.0` to listen on all interfaces (requires authentication for security)

✅ **Input Validation**: All user inputs (passwords, domains, IPs) are sanitized to prevent injection attacks

✅ **Rate Limiting**: Configurable connection limits prevent abuse and bandwidth exhaustion

✅ **Access Control**: 
   - With authentication: Only authenticated users and allowed IPs can access
   - Without authentication: Only localhost and private networks (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) can access

✅ **Secure Defaults**: The proxy is secure by default - authentication is recommended for production use

### Security Best Practices

- **Always set `PROXY_USER` and `PROXY_PASS`** for production deployments
- The `.env` file contains sensitive credentials and is excluded from git
- Set `PROXY_BIND_ADDRESS=0.0.0.0` to listen on all interfaces (included in `.env.example`). If not set, defaults to `127.0.0.1` (localhost only). **Always enable authentication when binding to all interfaces**
- Use strong passwords for `PROXY_PASS`
- Regularly rotate credentials
- Monitor logs for suspicious activity
- Consider using Docker secrets for credentials in production environments

## Files Structure

```
.
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Docker Compose configuration
├── entrypoint.sh          # Container startup script
├── .env                   # Your credentials (not in git)
├── .env.example           # Example environment file
├── .gitignore             # Git ignore rules
├── test-proxy.sh          # Comprehensive test script
├── quick-test.sh          # Quick test script
└── README.md              # This file
```

## License

This project is provided as-is for personal use.

## Contributing

Feel free to submit issues or pull requests for improvements.

