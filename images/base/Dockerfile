FROM debian:trixie

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Debian's latest updates, also for the packages that come with debian:trixie, so every
# rebuild has the current security fixes; then common tools every image needs, plus a
# non-root user with passwordless sudo
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
    bash-completion \
    ca-certificates \
    curl \
    git \
    gnupg \
    less \
    openssh-client \
    procps \
    sudo \
    unzip \
    wget \
    xz-utils \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /workspaces \
    && chown ${USERNAME}:${USERNAME} /workspaces \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=C.UTF-8 \
    PATH=/home/${USERNAME}/.local/bin:${PATH}

LABEL org.opencontainers.image.source="https://github.com/kankava/devcontainers"

# Set here, not only in devcontainer.json, so the image also works with plain docker/podman run
USER ${USERNAME}
WORKDIR /workspaces
