#!/usr/bin/env bash
# Build images from images/<name>/devcontainer.json with the devcontainer CLI.
#
# Usage: scripts/build.sh [--push] [name...]
#   With no names, builds every image, each after the one it builds on: the base images, the
#   images on base, then the images on those (e.g. cuda on cpp).
#   Each image is built in each of its variants (scripts/image-info.sh).
#
# Environment:
#   REGISTRY      image prefix (default: ghcr.io/kankava/devcontainer-images)
#   VARIANT       build only this variant
#   TAGS          space-separated tags, for one variant (default: "<version>-<variant>", the
#                 version from the image's image.json, plus "latest <version>" for its default variant)
#   DEVCONTAINER  CLI command (default: devcontainer), e.g. "npx -y @devcontainers/cli"
#   BUILDX_BUILDER  buildx builder (default: the current Docker context's builder)
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/kankava/devcontainer-images}"
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
    order=()
    for dir in "${ROOT}"/images/*/; do
        name="$(basename "${dir}")"
        depth="$("${ROOT}/scripts/image-info.sh" "${name}" | jq .depth)"
        order+=("${depth} ${name}")
    done
    mapfile -t names < <(printf '%s\n' "${order[@]}" | sort -s -n -k1,1 | cut -d' ' -f2)
    set -- "${names[@]}"
fi

stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT

for name in "$@"; do
    info="$("${ROOT}/scripts/image-info.sh" "${name}")"
    repository="$(jq -r .repository <<< "${info}")"
    version="$(jq -r .version <<< "${info}")"
    mapfile -t variants < <(jq -r '.variants[]' <<< "${info}")
    default="${variants[0]}"
    if [[ -n "${VARIANT:-}" ]]; then
        if ! jq -e --arg variant "${VARIANT}" '.variants | index($variant)' <<< "${info}" > /dev/null; then
            echo "${name} has no variant ${VARIANT}, only: ${variants[*]}" >&2
            exit 1
        fi
        variants=("${VARIANT}")
    fi
    if [[ -n "${TAGS:-}" ]] && (( ${#variants[@]} > 1 )); then
        echo "TAGS names the tags of one variant, but ${name} has several: set VARIANT too" >&2
        exit 1
    fi

    # The CLI only accepts local features inside a .devcontainer/ folder,
    # so build from a staged copy in that layout with src/ alongside
    mkdir -p "${stage}/${name}"
    cp -r "${ROOT}/images/${name}" "${stage}/${name}/.devcontainer"
    if [[ -d "${ROOT}/src" ]]; then
        cp -r "${ROOT}/src" "${stage}/${name}/.devcontainer/features"
    fi

    for variant in "${variants[@]}"; do
        if [[ -n "${TAGS:-}" ]]; then
            read -ra tags <<< "${TAGS}"
        else
            tags=("${version}-${variant}")
            if [[ "${variant}" == "${default}" ]]; then
                tags+=(latest "${version}")
            fi
        fi
        args=(build --workspace-folder "${stage}/${name}")
        for tag in "${tags[@]}"; do
            args+=(--image-name "${REGISTRY}/${repository}:${tag}")
        done
        if ${push}; then
            args+=(--push)
        fi

        echo "==> ${REGISTRY}/${repository}, ${variant}"
        # For a base image's devcontainer.json, which passes it to its Dockerfile
        VARIANT="${variant}" "${devcontainer[@]}" "${args[@]}"
    done
done
