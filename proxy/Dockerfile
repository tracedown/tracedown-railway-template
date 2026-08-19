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

# A deployment can replace the SPA's runtime config wholesale by setting
# RUNTIME_CONFIG_JS (JavaScript source, written to /config.js at container
# start) — endpoints or boot behavior without rebuilding the bundle. Unset,
# the bundle's own no-op config.js serves. The file is served no-cache, so a
# variable change + redeploy is live on the next page load.
CMD ["sh", "-c", "if [ -n \"$RUNTIME_CONFIG_JS\" ]; then printf '%s' \"$RUNTIME_CONFIG_JS\" > /srv/config.js; fi; exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile"]
