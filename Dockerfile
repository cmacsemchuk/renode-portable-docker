# Multi-arch Renode Docker image
# Uses portable dotnet builds from builds.renode.io
# Compatible with official Renode Docker image interface
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Etc/UTC
ENV TZ=${TZ}
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

ARG TARGETARCH

ARG RENODE_VERSION=latest

# Install dependencies including Robot Framework build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    sudo \
    wget \
    curl \
    tar \
    xz-utils \
    python3 \
    python3-pip \
    python3-dev \
    build-essential \
    telnet && \
    rm -rf /var/lib/apt/lists/*

# Set up developer user
RUN sed -i.bkp -e \
      's/%sudo\s\+ALL=(ALL\(:ALL\)\?)\s\+ALL/%sudo ALL=NOPASSWD:ALL/g' \
      /etc/sudoers

ARG userId=1000
ARG groupId=1000
RUN mkdir -p /home/developer && \
    echo "developer:x:$userId:$groupId:Developer,,,:/home/developer:/bin/bash" >> /etc/passwd && \
    echo "developer:x:$userId:" >> /etc/group && \
    echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer && \
    chown $userId:$groupId -R /home/developer

USER developer
ENV HOME=/home/developer
WORKDIR /home/developer

# Install Renode portable build
USER root
RUN set -eux; \
    # Select portable flavor based on target architecture
    case "${TARGETARCH}" in \
      amd64|x86_64) \
        FLAVOR="linux-portable-dotnet";; \
      arm64|aarch64) \
        FLAVOR="linux-arm64-portable-dotnet";; \
      *) \
        echo "ERROR: Unsupported architecture: ${TARGETARCH}" >&2; \
        exit 1;; \
    esac; \
    # Use special "latest" tarball name when RENODE_VERSION=latest, otherwise pin a specific build
    if [ "${RENODE_VERSION}" = "latest" ]; then \
      RENODE_TGZ="renode-latest.${FLAVOR}.tar.gz"; \
    else \
      RENODE_TGZ="renode-${RENODE_VERSION}.${FLAVOR}.tar.gz"; \
    fi; \
    RENODE_URL="https://builds.renode.io/${RENODE_TGZ}"; \
    echo "Downloading: ${RENODE_URL}"; \
    wget -O /tmp/renode.tar.gz "${RENODE_URL}"; \
    tar -xzf /tmp/renode.tar.gz -C /opt; \
    rm /tmp/renode.tar.gz; \
    # Create stable symlink
    ln -sfn "$(find /opt -maxdepth 1 -type d -name 'renode_*' | sort | tail -n1)" /opt/renode; \
    # Create command symlinks
    ln -sf /opt/renode/renode /usr/local/bin/renode; \
    ([ -f /opt/renode/scripts/renode-test ] && ln -sf /opt/renode/scripts/renode-test /usr/local/bin/renode-test || true)

# Install Robot Framework
RUN pip3 install --no-cache-dir robotframework

# Install Python test requirements
RUN pip3 install --no-cache-dir -r /opt/renode/tests/requirements.txt

# Ensure PATH includes renode
ENV PATH="/opt/renode:${PATH}"

# Switch back to developer user
USER developer
WORKDIR /home/developer

CMD ["renode"]
