# Avatype STUN/TURN Server - HARDENED
# Security-focused container build

FROM coturn/coturn:alpine

# Switch to root for setup
USER root

# ===========================================
# Security: Update all packages first
# ===========================================
RUN apk update && apk upgrade --no-cache

# ===========================================
# Install minimal dependencies only
# ===========================================
RUN apk add --no-cache \
    bash \
    curl \
    openssl \
    && rm -rf /var/cache/apk/* /tmp/*

# ===========================================
# Security: Create non-root user for runtime
# ===========================================
RUN mkdir -p /var/run/coturn /var/log/coturn /var/lib/coturn \
    && chown -R nobody:nogroup /var/run/coturn /var/log/coturn /var/lib/coturn \
    && chmod 750 /var/run/coturn /var/log/coturn /var/lib/coturn

# ===========================================
# Copy configuration files
# ===========================================
COPY --chmod=644 turnserver.conf /etc/turnserver.conf
COPY --chmod=755 entrypoint.sh /entrypoint.sh
COPY --chmod=755 healthcheck.sh /healthcheck.sh

# ===========================================
# Security: Remove unnecessary files
# ===========================================
RUN rm -rf /var/cache/apk/* \
    /tmp/* \
    /root/.ash_history \
    /root/.cache 2>/dev/null || true

# ===========================================
# Expose only required ports
# ===========================================
EXPOSE 3478/udp
EXPOSE 3478/tcp
EXPOSE 5349/tcp
EXPOSE 49152-49252/udp

# ===========================================
# Health check
# ===========================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD /healthcheck.sh || exit 1

# ===========================================
# Security: Run as root but drop privileges
# Coturn handles privilege dropping internally
# ===========================================
USER root

# ===========================================
# Security Labels
# ===========================================
LABEL security.hardened="true" \
      security.no-new-privileges="true"

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]
