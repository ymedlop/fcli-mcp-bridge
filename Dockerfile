# Stage 1: Build dependencies and downloaded artifacts
FROM alpine:3.23 AS builder

RUN apk add --no-cache \
    openjdk21-jre \
    bash \
    jq \
    curl \
    ca-certificates \
    npm

WORKDIR /opt

ARG FCLI_VERSION=3.19.0
ARG SUPERGATEWAY_VERSION=3.4.3
ARG MCP_SDK_VERSION=1.19.1

RUN mkdir -p /opt/supergateway \
    && cd /opt/supergateway \
    && npm init -y \
    && npm pkg set dependencies.supergateway="${SUPERGATEWAY_VERSION}" \
    && npm pkg set overrides.@modelcontextprotocol/sdk="${MCP_SDK_VERSION}" \
    && npm install --omit=dev \
    && ln -s /opt/supergateway/node_modules/.bin/supergateway /usr/local/bin/supergateway \
    && npm cache clean --force

RUN mkdir -p /opt/fortify \
    && set -e; \
       for i in 1 2 3; do \
         if curl -fL "https://github.com/fortify/fcli/releases/download/v${FCLI_VERSION}/fcli.jar" \
              -o /opt/fortify/fcli.jar; then \
           break; \
         elif [ "$i" -lt 3 ]; then \
           echo "Download attempt $i failed, retrying in 10s..."; \
           sleep 10; \
         else \
           echo "Failed to download fcli after 3 attempts"; \
           exit 1; \
         fi; \
       done

COPY start-bridge.sh /usr/local/bin/start-bridge.sh

RUN sed -i 's/\r$//' /usr/local/bin/start-bridge.sh \
    && printf '#!/bin/sh\nexec java -jar /opt/fortify/fcli.jar "$@"\n' > /usr/local/bin/fcli.sh \
    && chmod +x /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh


# Stage 2: Runtime
FROM node:26-alpine3.23

RUN apk add --no-cache \
    openjdk21-jre \
    curl \
    ca-certificates

ENV FORTIFY_DATA_DIR=/fcli-data
ENV FCLI_MCP_MODULE=ssc
ENV MCP_PORT=8000
ENV MCP_BASE_URL=http://fortify-mcp-bridge:8000

LABEL maintainer="ymedlop"
LABEL description="Fortify CLI MCP Bridge"

COPY --from=builder /usr/local/bin/start-bridge.sh /usr/local/bin/start-bridge.sh
COPY --from=builder /usr/local/bin/fcli.sh /usr/local/bin/fcli.sh
COPY --from=builder /opt/fortify /opt/fortify
COPY --from=builder /opt/supergateway /opt/supergateway
COPY --from=builder /usr/local/bin/supergateway /usr/local/bin/supergateway

RUN chmod +x /usr/local/bin/start-bridge.sh /usr/local/bin/fcli.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f "http://localhost:${MCP_PORT}/healthz" || exit 1

ENTRYPOINT ["/usr/local/bin/start-bridge.sh"]
