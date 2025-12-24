# Proxy Docker Setup

A Docker-based proxy server that connects to an upstream proxy with authentication and provides a proxy service without authentication on port 3128.

## Features

- Connects to an upstream proxy with username/password authentication
- Exposes a proxy service on port 3128 without authentication
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
   UPSTREAM_PROXY_HOST=your-proxy-host.com
   UPSTREAM_PROXY_PORT=3128
   UPSTREAM_PROXY_USER=your-username
   UPSTREAM_PROXY_PASS=your-password
   NO_PROXY=localhost,127.0.0.1,*.local
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

| Variable | Description | Example |
|----------|-------------|---------|
| `UPSTREAM_PROXY_HOST` | Hostname or IP of upstream proxy | `192.168.200.220` |
| `UPSTREAM_PROXY_PORT` | Port of upstream proxy | `3128` |
| `UPSTREAM_PROXY_USER` | Username for upstream proxy | `m.sader` |
| `UPSTREAM_PROXY_PASS` | Password for upstream proxy | `your-password` |
| `NO_PROXY` | Comma-separated domains to bypass | `localhost,127.0.0.1,*.local` |

### Port Configuration

The proxy listens on port `3128` by default. To change it, modify the port mapping in `docker-compose.yml`:

```yaml
ports:
  - "3128:3128"  # Change the first number to your desired host port
```

## Usage

### Using the Proxy

Once the container is running, you can use the proxy on `localhost:3128`:

```bash
# HTTP request
curl --proxy http://localhost:3128 http://example.com

# HTTPS request
curl --proxy http://localhost:3128 https://example.com

# With verbose output
curl -v --proxy http://localhost:3128 http://example.com
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

## Security Notes

- The `.env` file contains sensitive credentials and is excluded from git
- The proxy on port 3128 has **no authentication** - anyone with network access can use it
- Only expose this proxy on trusted networks
- Consider adding authentication if exposing to the internet

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

