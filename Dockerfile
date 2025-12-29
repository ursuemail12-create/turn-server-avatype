# Avatype STUN/TURN Server
# Based on official coturn Alpine image

FROM coturn/coturn:alpine

# Switch to root for setup
USER root

# Install dependencies for health checks and debugging
RUN apk update && apk add --no-cache \
    bash \
    curl \
    netcat-openbsd \
    bind-tools \
    openssl \
    && rm -rf /var/cache/apk/*

# Create directories with proper permissions
RUN mkdir -p /var/run/coturn /var/log/coturn /var/lib/coturn \
    && chown -R turnserver:turnserver /var/run/coturn /var/log/coturn /var/lib/coturn

# Copy configuration files
COPY turnserver.conf /etc/turnserver.conf
COPY entrypoint.sh /entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

# Set permissions
RUN chmod +x /entrypoint.sh /healthcheck.sh \
    && chmod 644 /etc/turnserver.conf \
    && chown turnserver:turnserver /etc/turnserver.conf

# Expose ports
# STUN/TURN UDP and TCP
EXPOSE 3478/udp
EXPOSE 3478/tcp
# TURNS (TLS)
EXPOSE 5349/tcp
# Media relay ports (limited range for Fly.io compatibility)
EXPOSE 49152-49252/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD /healthcheck.sh || exit 1

# Run as root to allow binding to privileged ports
# The turnserver process itself drops privileges
USER root

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
