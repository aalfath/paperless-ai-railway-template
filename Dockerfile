# Paperless-AI for Railway: the official upstream image, pinned by version and digest.
# Update: bump the tag and digest below and add a CHANGELOG.md entry.
FROM clusterzx/paperless-ai:4.5.1@sha256:770bce7654fcfa7e5611defea8ec70db3483f87da1a54d75ce418d6910ae7f30

# Railway terminates TLS in front of the app (one proxy hop): real client IPs for the login
# rate limit and secure session cookies.
ENV TRUST_PROXY=1 \
    PAPERLESS_AI_DATA_DIR=/app/data \
    PAPERLESS_AI_READERS=1 \
    UV_THREADPOOL_SIZE=2

COPY railway/ /railway/
RUN chmod 0755 /railway/start.sh

# Health check, port and restart policy are set on the Railway service (no railway.json).
ENTRYPOINT []
CMD ["/railway/start.sh"]
