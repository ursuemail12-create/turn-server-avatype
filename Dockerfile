# Use official coturn image
FROM coturn/coturn:4.6.2

# Install dependencies for health check
RUN apt-get update && apt-get install -y \
    curl \
    netcat-openbsd \
    iputils-ping \
    dnsutils \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY turnserver.conf /etc/coturn/turnserver.conf
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /healthcheck.sh

# Expose STUN/TURN ports
EXPOSE 3478/tcp
EXPOSE 3478/udp
EXPOSE 5349/tcp
EXPOSE 5349/udp
EXPOSE 49152-65535/udp

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD /healthcheck.sh

# Entry point
ENTRYPOINT ["/entrypoint.sh"]
CMD ["turnserver", "-c", "/etc/coturn/turnserver.conf"]