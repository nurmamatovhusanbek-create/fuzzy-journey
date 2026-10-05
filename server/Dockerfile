# Terra Bellum dedicated multiplayer server (headless Godot running the authoritative engine).
# Build from the REPO ROOT:  docker build -f server/Dockerfile -t terra-bellum-server .
FROM debian:bookworm-slim AS godot
ARG GODOT_VERSION=4.4.1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /tmp/g.zip https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
 && unzip -q /tmp/g.zip -d /opt/godot && mv /opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot && rm /tmp/g.zip

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/* && useradd -m tb
COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot
COPY godot /app/godot
RUN chown -R tb:tb /app
USER tb
WORKDIR /app/godot
# build class cache / imports once at image build time
RUN godot --headless --import >/dev/null 2>&1 || true
# Render injects $PORT; the server reads it (falls back to 8080)
ENV PORT=8080
EXPOSE 8080
CMD ["godot", "--headless", "--path", "/app/godot", "res://src/net/server.tscn"]
