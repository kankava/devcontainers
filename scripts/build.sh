#!/usr/bin/env bash
# Build images from images/<name>/devcontainer.json with the devcontainer CLI.
#
# Usage: scripts/build.sh [--push] [name...]
#   With no names, builds every image, base first since the others build on it.
#
# Environment:
#   REGISTRY      image prefix (default: ghcr.io/kankava/devcontainer-images)
#   TAGS          space-separated tags (default: "latest YYYYMMDD", today's date in UTC)
#   DEVCONTAINER  CLI command (default: devcontainer), e.g. "npx -y @devcontainers/cli"
#   BUILDX_BUILDER  buildx builder (default: the current Docker context's builder)
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/kankava/devcontainer-images}"
read -ra tags <<< "${TAGS:-latest $(date -u +%Y%m%d)}"
read -ra devcontainer <<< "${DEVCONTAINER:-devcontainer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Images build on top of each other, which needs a builder that sees local images:
# the context's own (docker driver) builder does, a docker-container builder doesn't
if [[ -z "${BUILDX_BUILDER:-}" ]] && command -v docker > /dev/null; then
    export BUILDX_BUILDER="$(docker context show)"
fi

push=false
if [[ "${1:-}" == --push ]]; then
    push=true
    shift
fi

if (( $# == 0 )); then
    set -- base
    for dir in "${ROOT}"/images/*/; do
        name="$(basename "${dir}")"
        [[ "${name}" == base ]] || set -- "$@" "${name}"
    done
fi

stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT

for name in "$@"; do
    if [[ ! -f "${ROOT}/images/${name}/devcontainer.json" ]]; then
        echo "No such image: ${name}" >&2
        exit 1
    fi

    # The CLI only accepts local features inside a .devcontainer/ folder,
    # so build from a staged copy in that layout with src/ alongside
    mkdir -p "${stage}/${name}"
    cp -r "${ROOT}/images/${name}" "${stage}/${name}/.devcontainer"
    if [[ -d "${ROOT}/src" ]]; then
        cp -r "${ROOT}/src" "${stage}/${name}/.devcontainer/features"
    fi

    args=(build --workspace-folder "${stage}/${name}")
    for tag in "${tags[@]}"; do
        args+=(--image-name "${REGISTRY}/${name}:${tag}")
    done
    if ${push}; then
        args+=(--push)
    fi

    echo "==> ${REGISTRY}/${name}"
    "${devcontainer[@]}" "${args[@]}"
done
