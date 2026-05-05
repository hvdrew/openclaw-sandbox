FROM docker/sandbox-templates:shell-docker

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        jq \
        openssl \
        python3 \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g openclaw@latest \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --chown=agent:agent kits/openclaw-bootstrap/files/home/install-openclaw.sh /home/agent/install-openclaw.sh
RUN chmod 0755 /home/agent/install-openclaw.sh

USER agent
WORKDIR /home/agent
