# Use official coturn image with Alpine (smaller, more secure)
FROM coturn/coturn:alpine

# Switch to root for installation
USER root

# Install dependencies for health check (Alpine uses apk)
RUN apk update && apk add --no-cache \
    bash \
    curl \
    netcat-openbsd \
    bind-tools \
    iputils-ping \
    jq \
    openssl

# Copy configuration files
COPY turnserver.conf /etc/coturn/turnserver.conf
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /healthcheck.sh && \
    mkdir -p /var/run/coturn && \
    chown -R turnserver:turnserver /var/run/coturn

# Create logs directory with correct permissions
RUN mkdir -p /var/log/coturn && \
    chown -R turnserver:turnserver /var/log/coturn

# Expose STUN/TURN ports (documentation only)
EXPOSE 3478/tcp 3478/udp
EXPOSE 5349/tcp 5349/udp

# Switch back to non-root user for security
USER turnserver

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD ["/bin/bash", "/healthcheck.sh"]

# Entry point
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
CMD ["turnserver", "-c", "/etc/coturn/turnserver.conf", "-n", "--log-file=stdout"]