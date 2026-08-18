# realtime-service from the pinned backend release. Build context is the repo root (this
# Dockerfile is selected by path), so the single VERSION file drives every
# service in the template.
FROM eclipse-temurin:17-jre

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY VERSION /tracedown/VERSION
RUN set -e; V="$(cat /tracedown/VERSION)"; \
    curl -fsSL -o /tracedown/app.jar \
      "https://github.com/tracedown/tracedown-core-backend/releases/download/v${V}/realtime-service-${V}-all.jar"

ENTRYPOINT ["java", "-jar", "/tracedown/app.jar"]
