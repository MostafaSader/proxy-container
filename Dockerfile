FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Squid and required tools (including apache2-utils for authentication)
RUN apt-get update && \
    apt-get install -y squid curl netcat-openbsd apache2-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy squid configuration script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create necessary directories with proper permissions
RUN mkdir -p /var/spool/squid /var/log/squid && \
    chown -R proxy:proxy /var/spool/squid /var/log/squid && \
    chmod -R 755 /var/spool/squid /var/log/squid

# Expose proxy port
EXPOSE 3128

# Run entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
CMD ["squid", "-N", "-f", "/etc/squid/squid.conf"]

