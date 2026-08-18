# api-gateway plus the schema-migrator distribution, sequenced by start.sh:
# Railway has no one-shot jobs or startup ordering, so the gateway container
# migrates the schema and ensures the internal CA before it starts listening.
# Every other service simply retries/restarts until this one has done both.
FROM eclipse-temurin:17-jre

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl unzip \
    && rm -rf /var/lib/apt/lists/*

COPY VERSION /tracedown/VERSION
RUN set -e; V="$(cat /tracedown/VERSION)"; \
    curl -fsSL -o /tracedown/app.jar \
      "https://github.com/tracedown/tracedown-core-backend/releases/download/v${V}/api-gateway-${V}-all.jar"; \
    curl -fsSL -o /tmp/migrator.zip \
      "https://github.com/tracedown/tracedown-core-backend/releases/download/v${V}/schema-migrator-${V}.zip"; \
    unzip -q /tmp/migrator.zip -d /tracedown; \
    mv "/tracedown/schema-migrator-${V}" /tracedown/schema-migrator; \
    rm /tmp/migrator.zip

# Saved response bodies — mount a volume here.
RUN mkdir -p /data/bodies
ENV STORAGE_FILESYSTEM_ROOT=/data/bodies

COPY gateway/start.sh /tracedown/start.sh
RUN chmod +x /tracedown/start.sh
ENTRYPOINT ["/tracedown/start.sh"]
