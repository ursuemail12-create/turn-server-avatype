# Use official coturn Alpine image
FROM coturn/coturn:alpine

# Switch to root for setup
USER root

# Install dependencies
RUN apk update && apk add --no-cache \
    bash \
    curl \
    netcat-openbsd \
    bind-tools \
    iputils-ping \
    jq \
    openssl \
    && rm -rf /var/cache/apk/*

# Create a non-root user for coturn
RUN addgroup -S turnserver && adduser -S -G turnserver turnserver \
    && mkdir -p /var/run/coturn /var/log/coturn \
    && chown -R turnserver:turnserver /var/run/coturn /var/log/coturn

# Copy configuration and scripts
COPY turnserver.conf /etc/coturn/turnserver.conf
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh /healthcheck.sh \
    && chown turnserver:turnserver /entrypoint.sh /healthcheck.sh /etc/coturn/turnserver.conf

# Expose standard STUN/TURN ports
EXPOSE 3478/tcp 3478/udp
EXPOSE 5349/tcp 5349/udp

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD ["/bin/bash", "/healthcheck.sh"]

# Switch to non-root user
USER turnserver

# Entrypoint
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

# Default command if entrypoint does not exec
CMD ["turnserver", "-c", "/etc/coturn/turnserver.conf", "-n", "--log-file=stdout"]
