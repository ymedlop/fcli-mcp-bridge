[![](https://images.microbadger.com/badges/version/ymedlop/fcli-mcp-bridge.svg)](https://microbadger.com/images/ymedlop/fcli-mcp-bridge "Get your own version badge on microbadger.com") [![](https://images.microbadger.com/badges/image/ymedlop/fcli-mcp-bridge.svg)](https://microbadger.com/images/ymedlop/fcli-mcp-bridge "Get your own image badge on microbadger.com") [![](https://images.microbadger.com/badges/commit/ymedlop/fcli-mcp-bridge.svg)](https://microbadger.com/images/ymedlop/fcli-mcp-bridge "Get your own commit badge on microbadger.com") [![](https://images.microbadger.com/badges/license/ymedlop/fcli-mcp-bridge.svg)](https://microbadger.com/images/ymedlop/fcli-mcp-bridge "Get your own license badge on microbadger.com")
[![](https://img.shields.io/docker/pulls/ymedlop/fcli-mcp-bridge.svg)](https://img.shields.io/docker/pulls/ymedlop/fcli-mcp-bridge.svg)

# Fortify fcli MCP Bridge

Expose Fortify CLI (`fcli`) as a remote Model Context Protocol (MCP) service by running the fcli stdio MCP server behind Supergateway.

This image is intended for non-Studio, remote, browser-based, no-code, or orchestration solutions that can consume an MCP endpoint over HTTP/SSE but cannot directly start a local `stdio` MCP process.

## What this image does

The container combines three pieces:

1. **Fortify CLI (`fcli`)**
   - Provides command-line access to Fortify products such as Software Security Center (SSC), Fortify on Demand (FoD), ScanCentral SAST, and ScanCentral DAST.

2. **fcli MCP server**
   - Starts fcli as an MCP server using:

     ```sh
     fcli util mcp-server start --module=<module>
     ```

   - The fcli MCP server exposes selected Fortify operations as MCP tools.

3. **Supergateway**
   - Wraps the fcli stdio MCP server and exposes it over HTTP/SSE.
   - This allows clients that support remote MCP endpoints to call Fortify functionality without installing or launching fcli locally.

## Architecture

```text
MCP client / non-Studio solution
        |
        | HTTP/SSE
        v
Supergateway inside Docker
        |
        | stdio
        v
fcli util mcp-server start --module=<module>
        |
        v
Fortify SSC / FoD / ScanCentral APIs
```

## Default endpoints

When started with the default configuration, the bridge listens on port `8000` and exposes:

| Purpose | URL |
|---|---|
| MCP SSE endpoint | `http://localhost:8000/sse` |
| MCP message endpoint | `http://localhost:8000/message` |
| Health endpoint | `http://localhost:8000/healthz` |

The public base URL is controlled with `MCP_BASE_URL`. Set this to the URL that your MCP client will use to reach the container.

Examples:

```sh
MCP_BASE_URL=http://localhost:8000
MCP_BASE_URL=http://fortify-mcp-bridge:8000
MCP_BASE_URL=https://fortify-mcp.example.com
```

## Build the image

```sh
docker build -t fcli-mcp-bridge:local .
```

Optional build arguments:

```sh
docker build \
  --build-arg FCLI_VERSION=3.19.0 \
  --build-arg SUPERGATEWAY_VERSION=3.4.3 \
  --build-arg MCP_SDK_VERSION=1.19.1 \
  -t fcli-mcp-bridge:local .
```

## Runtime configuration

| Variable | Default | Description |
|---|---:|---|
| `FORTIFY_DATA_DIR` | `/fcli-data` | Directory used by fcli for persisted state and sessions. Mount this as a volume if sessions must survive container recreation. |
| `FCLI_MCP_MODULE` | `ssc` | fcli module exposed through MCP. Common values include `ssc`, `fod`, `sc-sast`, `sc-dast`, and `aviator`, depending on the installed fcli version. |
| `MCP_PORT` | `8000` | Port used by Supergateway inside the container. |
| `MCP_BASE_URL` | `http://fortify-mcp-bridge:8000` | Externally visible base URL advertised by Supergateway. Set this to the URL used by your MCP client. |

## Authenticate fcli

fcli is session-based. Log in once, persist the fcli state directory in a Docker volume, then run the bridge using the same volume.

Create a volume:

```sh
docker volume create fcli-data
```

Log in to SSC interactively using a token prompt:

```sh
docker run --rm -it \
  -v fcli-data:/fcli-data \
  fcli-mcp-bridge:local \
  fcli.sh ssc session login \
    --url "https://ssc.example.com" \
    --token
```

Or log in with username/password and let fcli prompt for the password:

```sh
docker run --rm -it \
  -v fcli-data:/fcli-data \
  fcli-mcp-bridge:local \
  fcli.sh ssc session login \
    --url "https://ssc.example.com" \
    --user "user@example.com" \
    --password
```

Validate the session:

```sh
docker run --rm -it \
  -v fcli-data:/fcli-data \
  fcli-mcp-bridge:local \
  fcli.sh ssc session list --validate
```

For automation, prefer environment variables or secrets management instead of putting credentials directly in shell history.

## Run the bridge

```sh
docker run --rm \
  --name fortify-mcp-bridge \
  -p 8000:8000 \
  -v fcli-data:/fcli-data \
  -e FCLI_MCP_MODULE=ssc \
  -e MCP_PORT=8000 \
  -e MCP_BASE_URL=http://localhost:8000 \
  fcli-mcp-bridge:local
```

Health check:

```sh
curl -f http://localhost:8000/healthz
```

## Docker Compose example

```yaml
services:
  fortify-mcp-bridge:
    build: .
    image: fcli-mcp-bridge:local
    container_name: fortify-mcp-bridge
    ports:
      - "8000:8000"
    environment:
      FORTIFY_DATA_DIR: /fcli-data
      FCLI_MCP_MODULE: ssc
      MCP_PORT: 8000
      MCP_BASE_URL: http://localhost:8000
    volumes:
      - fcli-data:/fcli-data
    restart: unless-stopped

volumes:
  fcli-data:
```

Start it:

```sh
docker compose up -d
```

View logs:

```sh
docker logs -f fortify-mcp-bridge
```

## Configure an MCP client

Use the SSE endpoint exposed by Supergateway:

```json
{
  "mcpServers": {
    "fortify-ssc": {
      "type": "sse",
      "url": "http://localhost:8000/sse"
    }
  }
}
```

Exact configuration syntax depends on the MCP host. The important values are:

```text
Transport: SSE / remote MCP over HTTP
URL:       http://<bridge-host>:<port>/sse
```

For a container running behind a reverse proxy, configure the client with the externally reachable URL, for example:

```text
https://fortify-mcp.example.com/sse
```

and set:

```sh
MCP_BASE_URL=https://fortify-mcp.example.com
```

## Selecting a Fortify module

By default, the bridge exposes the `ssc` module:

```sh
-e FCLI_MCP_MODULE=ssc
```

Other modules depend on the fcli version and your Fortify deployment. Examples:

```sh
-e FCLI_MCP_MODULE=fod
-e FCLI_MCP_MODULE=sc-sast
-e FCLI_MCP_MODULE=sc-dast
-e FCLI_MCP_MODULE=aviator
```

If the installed fcli version supports comma-separated modules, you can expose more than one module:

```sh
-e FCLI_MCP_MODULE=ssc,fod
```

Use the smallest module scope required by the client.

## Operational notes

### Session persistence

Mount `/fcli-data` as a Docker volume. Without a volume, fcli sessions are lost when the container is removed.

```sh
-v fcli-data:/fcli-data
```

### Network access

The container must be able to reach your Fortify endpoints, such as SSC, FoD, or ScanCentral services. If Fortify is internal, run the bridge on a network that has access to those systems.

### Reverse proxy

If you publish the bridge through a reverse proxy, make sure it supports long-lived SSE connections. Avoid buffering the SSE stream.

### Health endpoint

The startup script configures Supergateway with:

```sh
--healthEndpoint /healthz
```

The Docker health check should therefore call:

```sh
http://localhost:${MCP_PORT}/healthz
```

not `/health`.

## Security considerations

This bridge gives an MCP client access to Fortify operations through the authenticated fcli session. Treat it as a privileged integration point.

Recommended controls:

- Do not expose the bridge directly to the public Internet.
- Put the service behind a private network, VPN, reverse proxy, or API gateway.
- Add authentication and TLS at the reverse proxy or platform layer.
- Use a dedicated Fortify service account.
- Grant the minimum Fortify permissions required for the expected workflows.
- Prefer short-lived or rotated tokens.
- Protect the Docker volume mounted at `/fcli-data` because it contains fcli session state.
- Expose only the required fcli module with `FCLI_MCP_MODULE`.
- Review all actions requested by AI agents before enabling autonomous workflows.

## Troubleshooting

### `exec /usr/local/bin/start-bridge.sh: no such file or directory`

This usually means the runtime image cannot execute the script, even if the file exists. Common causes:

- The runtime image does not contain `/bin/sh`.
- The script has Windows CRLF line endings.
- The shebang points to an interpreter that is not present in the image.

Fixes:

- Use a runtime image that includes `/bin/sh`, or replace the shell script with a real executable entrypoint.
- Normalize the script during the image build:

  ```dockerfile
  RUN sed -i 's/\r$//' /usr/local/bin/start-bridge.sh
  ```

### `java: not found`

The fcli wrapper runs:

```sh
java -jar /opt/fortify/fcli.jar
```

Make sure the final runtime image includes a Java runtime, not only the builder stage.

### Health check fails

Check that:

- The container exposes the configured `MCP_PORT`.
- The health check uses `/healthz`.
- The runtime image contains `curl`, or the health check uses a binary available in the image.

### MCP client cannot connect

Check that:

- The client URL points to `/sse`.
- `MCP_BASE_URL` matches the externally reachable base URL.
- Port `8000` is published or routed correctly.
- Any reverse proxy supports SSE and does not buffer the event stream.

### Fortify commands fail with authentication errors

Check that:

- You logged in with the same `/fcli-data` volume used by the running bridge.
- The fcli session is still valid:

  ```sh
  docker run --rm -it \
    -v fcli-data:/fcli-data \
    fcli-mcp-bridge:local \
    fcli.sh ssc session list --validate
  ```

- The selected module matches the Fortify product you authenticated against.

## Useful diagnostic commands

Run fcli directly inside the image:

```sh
docker run --rm -it \
  -v fcli-data:/fcli-data \
  fcli-mcp-bridge:local \
  fcli.sh --version
```

List SSC sessions:

```sh
docker run --rm -it \
  -v fcli-data:/fcli-data \
  fcli-mcp-bridge:local \
  fcli.sh ssc session list --validate
```

Start the bridge with another module:

```sh
docker run --rm \
  -p 8000:8000 \
  -v fcli-data:/fcli-data \
  -e FCLI_MCP_MODULE=fod \
  -e MCP_BASE_URL=http://localhost:8000 \
  fcli-mcp-bridge:local
```

## References

- Fortify CLI documentation: https://fortify.github.io/fcli/
- fcli MCP server command: https://fortify.github.io/fcli/latest/manpage/fcli-util-mcp-server-start.html
- Supergateway: https://github.com/supercorp-ai/supergateway
- Model Context Protocol: https://modelcontextprotocol.io/
