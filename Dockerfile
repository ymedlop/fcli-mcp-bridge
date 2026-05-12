FROM node:lts-trixie

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openjdk-21-jre-headless \
       bash \
       jq \
       curl \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/fortify /fcli-data \
    && chown -R node:node /opt/fortify /fcli-data  \
    && mkdir -p /opt/supergateway \
    && cd /opt/supergateway \
    && npm init -y \
    && npm pkg set dependencies.supergateway="3.4.3" \
    && npm pkg set overrides.@modelcontextprotocol/sdk="1.19.1" \
    && npm install --omit=dev \
    && ln -s /opt/supergateway/node_modules/.bin/supergateway /usr/local/bin/supergateway

COPY vendor/fcli.jar /opt/fortify/fcli.jar

RUN printf '#!/usr/bin/env sh\nexec java -jar /opt/fortify/fcli.jar "$@"\n' > /usr/local/bin/fcli.sh \
    && chmod +x /usr/local/bin/fcli.sh

COPY start-bridge.sh /usr/local/bin/start-bridge.sh

RUN sed -i 's/\r$//' /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh \
    && chmod +x /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh \
    && chown node:node /usr/local/bin/fcli.sh /usr/local/bin/start-bridge.sh

ENV FORTIFY_DATA_DIR=/fcli-data
ENV FCLI_MCP_MODULE=ssc
ENV MCP_PORT=8000
ENV MCP_BASE_URL=http://fortify-mcp-bridge:8000

USER node

ENTRYPOINT ["/usr/local/bin/start-bridge.sh"]
