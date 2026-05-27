# ============================================================================
# Stage 1: Download pre-built AionUI WebUI tarball from GitHub releases
# ============================================================================
FROM --platform=linux/amd64 debian:13-slim AS downloader

ARG AIONUI_VERSION=2.1.4
ARG RELEASE_ARCH=x86_64

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    echo "Downloading aionui-web v${AIONUI_VERSION} linux-${RELEASE_ARCH}..." && \
    curl -fsSL -o /tmp/aionui-web.tar.gz \
        "https://github.com/iOfficeAI/AionUi/releases/download/v${AIONUI_VERSION}/aionui-web-${AIONUI_VERSION}-linux-${RELEASE_ARCH}.tar.gz" && \
    mkdir -p /opt/aionui-web && \
    tar -xzf /tmp/aionui-web.tar.gz -C /opt/aionui-web --strip-components=1 && \
    ls -la /opt/aionui-web/ && \
    rm /tmp/aionui-web.tar.gz && \
    echo "Download complete"

# ============================================================================
# Stage 2: Extend Hermes Agent with AionUI
# ============================================================================
FROM nousresearch/hermes-agent:latest

ENV AIONUI_DATA_DIR=/opt/data

COPY --from=downloader --chown=hermes:hermes \
    /opt/aionui-web /opt/aionui

COPY docker/start.sh /opt/hermes/docker/start.sh
RUN chmod +x /opt/hermes/docker/start.sh

ENV PORT=3000
ENV NODE_ENV=production
ENV AIONUI_ALLOW_REMOTE=true
ENV HERMES_HOME=/opt/data

CMD ["/opt/hermes/docker/start.sh"]
