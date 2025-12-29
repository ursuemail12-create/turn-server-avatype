# Proper STUN/TURN server with full functionality
FROM debian:bullseye-slim

# Install coturn and required dependencies
RUN apt-get update && apt-get install -y \
    coturn \
    curl \
    netcat-openbsd \
    iputils-ping \
    dnsutils \
    jq \
    openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create turnserver user (non-root for security)
RUN useradd -r -m -U -d /var/lib/coturn -s /bin/false turnserver \
    && mkdir -p /var/log/coturn /var/run/coturn \
    && chown -R turnserver:turnserver /var/log/coturn /var/run/coturn

# Copy configuration files
COPY turnserver.conf /etc/turnserver.conf
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Set proper permissions
RUN chmod +x /entrypoint.sh /healthcheck.sh \
    && chown turnserver:turnserver /etc/turnserver.conf /entrypoint.sh /healthcheck.sh

# Create log directory
RUN mkdir -p /var/log/coturn && chown turnserver:turnserver /var/log/coturn

# Expose necessary ports
EXPOSE 3478/tcp 3478/udp 5349/tcp 5349/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD ["/bin/bash", "/healthcheck.sh"]

# Run as non-root user
USER turnserver

# Entry point
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["turnserver", "-c", "/etc/turnserver.conf"]