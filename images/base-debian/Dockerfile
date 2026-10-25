# The Debian image to start from, one of the variants in image.json. scripts/build.sh sets it
# through devcontainer.json; the default is for a plain docker build
ARG VARIANT=trixie
FROM debian:${VARIANT}

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Debian's latest updates, also for the packages that come with the Debian image, so every
# rebuild has the current security fixes; then common tools every image needs (vim, also
# the editor git opens for commit messages; python3 for scripts and tools written in Python),
# plus a non-root user with passwordless sudo
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
    python3 \
    sudo \
    unzip \
    vim \
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
