FROM dhi.io/node:26-alpine3.23

# Build arguments for version pinning
ARG FCLI_VERSION=3.19.0
ARG SUPERGATEWAY_VERSION=3.4.3
ARG MCP_SDK_VERSION=1.19.1

# Environment variables
ENV FORTIFY_DATA_DIR=/fcli-data
ENV FCLI_MCP_MODULE=ssc
ENV MCP_PORT=8000
ENV MCP_BASE_URL=http://fortify-mcp-bridge:8000

# Metadata labels
LABEL maintainer="ymedlop"
LABEL description="Fortify CLI MCP Bridge"
LABEL version="${FCLI_VERSION}"

USER root

# Copy startup script
COPY start-bridge.sh /usr/local/bin/start-bridge.sh

# Install system dependencies
RUN apk add --no-cache \
       openjdk21-jre \
       bash \
       jq \
       curl \
       ca-certificates

# Create application directories and set permissions
RUN mkdir -p /opt/fortify /fcli-data \
    && chown -R node:node /opt/fortify /fcli-data

# Set up SuperGateway with pinned MCP SDK version
RUN mkdir -p /opt/supergateway \
    && cd /opt/supergateway \
    && npm init -y \
    && npm pkg set dependencies.supergateway="${SUPERGATEWAY_VERSION}" \
    && npm pkg set overrides.@modelcontextprotocol/sdk="${MCP_SDK_VERSION}" \
    && npm install --omit=dev \
    && ln -s /opt/supergateway/node_modules/.bin/supergateway /usr/local/bin/supergateway \
    && npm cache clean --force

# Download Fortify CLI with retry logic
RUN set -e; \
    for i in 1 2 3; do \
      if curl -fL https://github.com/fortify/fcli/releases/download/v${FCLI_VERSION}/fcli-${FCLI_VERSION}.jar -o /opt/fortify/fcli.jar; then \
        break; \
      elif [ $i -lt 3 ]; then \
        echo "Download attempt $i failed, retrying in 10s..."; \
        sleep 10; \
      else \
        echo "Failed to download fcli after 3 attempts"; \
        exit 1; \
      fi; \
    done

# Create fcli wrapper script and fix line endings
RUN printf '#!/usr/bin/env sh\nexec java -jar /opt/fortify/fcli.jar "$@"\n' > /usr/local/bin/fcli.sh \
    && sed -i 's/\r$//' /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh \
    && chmod +x /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh \
    && chown node:node /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:${MCP_PORT}/health || exit 1

# Switch to non-root user
USER node

# Verify non-root execution
RUN test "$(id -u)" != "0" || (echo "Container must not run as non-root user" && exit 1)

ENTRYPOINT ["/usr/local/bin/start-bridge.sh"]
