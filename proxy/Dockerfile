# The public edge: serves the dashboard bundle (fetched from the pinned
# frontend release) and routes the API, WebSocket and metrics paths to the
# backend services over the private network — the same shape as the host
# nginx/apache configs in the backend's docker/deploy. Railway's edge
# terminates TLS and forwards to $PORT here.
FROM caddy:2-alpine

RUN apk add --no-cache curl

COPY FRONTEND_VERSION /tmp/FRONTEND_VERSION
RUN set -e; V="$(cat /tmp/FRONTEND_VERSION)"; \
    curl -fsSL -o /tmp/dist.tar.gz \
      "https://github.com/tracedown/tracedown-core-frontend/releases/download/v${V}/tracedown-core-frontend-${V}-dist.tar.gz"; \
    mkdir -p /srv; \
    tar -xzf /tmp/dist.tar.gz -C /srv; \
    rm /tmp/dist.tar.gz

COPY proxy/Caddyfile /etc/caddy/Caddyfile
