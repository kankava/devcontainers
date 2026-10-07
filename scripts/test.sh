#!/usr/bin/env bash
# Test built images: each image's own images/<name>/test.sh, if it has one, and the test of
# every feature it includes (test/<feature>/test.sh, the one for the feature's default options).
# Each test runs in a fresh container that the devcontainer CLI starts, as it would for a project.
#
# Usage: scripts/test.sh [name...]
#   With no names, tests every image.
#
# Environment:
#   REGISTRY      image prefix (default: ghcr.io/kankava/devcontainer-images)
#   TAG           tag to test (default: latest)
#   DEVCONTAINER  CLI command (default: devcontainer), e.g. "npx -y @devcontainers/cli"
#   BUILDX_BUILDER  buildx builder (default: the current Docker context's builder)
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/kankava/devcontainer-images}"
TAG="${TAG:-latest}"
read -ra devcontainer <<< "${DEVCONTAINER:-devcontainer}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# The CLI builds an image on top that gives the container user the host user's UID, which
# needs a builder that sees local images, as in build.sh
if [[ -z "${BUILDX_BUILDER:-}" ]] && command -v docker > /dev/null; then
    export BUILDX_BUILDER="$(docker context show)"
fi

if (( $# == 0 )); then
    for dir in "${ROOT}"/images/*/; do
        set -- "$@" "$(basename "${dir}")"
    done
fi

stage="$(mktemp -d)"
cleanup() {
    local container image
    for container in $(docker ps -aq --filter "label=devcontainer.local_folder" --no-trunc); do
        [[ "$(docker inspect -f '{{index .Config.Labels "devcontainer.local_folder"}}' "${container}")" == "${stage}"/* ]] || continue
        image="$(docker inspect -f '{{.Config.Image}}' "${container}")"
        docker rm -fv "${container}" > /dev/null
        # The UID image the CLI built, not the image under test
        if [[ "${image}" == vsc-* ]]; then
            docker rmi "${image}" > /dev/null || true
        fi
    done
    rm -rf "${stage}"
}
trap cleanup EXIT

failed=()

# Runs a test script, along with the files next to it, in a container of the image
run_test() { # <image> <label> <test.sh> <copy the whole folder: true|false>
    local image="$1" label="$2" script="$3" whole="$4"
    local workspace="${stage}/${label//\//-}" config="${stage}/config/${label//\//-}/devcontainer.json"
    mkdir -p "${workspace}" "$(dirname "${config}")"
    if ${whole}; then
        cp -r "$(dirname "${script}")"/. "${workspace}"
    else
        cp "${script}" "${workspace}"
    fi
    cp "${ROOT}/scripts/test-lib.sh" "${workspace}/dev-container-features-test-lib"
    printf '{ "image": "%s" }\n' "${image}" > "${config}"

    echo "==> ${label}"
    if "${devcontainer[@]}" up --workspace-folder "${workspace}" --config "${config}" > /dev/null \
        && "${devcontainer[@]}" exec --workspace-folder "${workspace}" --config "${config}" bash test.sh; then
        return
    fi
    failed+=("${label}")
}

for name in "$@"; do
    dir="${ROOT}/images/${name}"
    if [[ ! -f "${dir}/devcontainer.json" ]]; then
        echo "No such image: ${name}" >&2
        exit 1
    fi
    image="${REGISTRY}/${name}:${TAG}"
    if [[ -f "${dir}/test.sh" ]]; then
        run_test "${image}" "${name}" "${dir}/test.sh" false
    fi
    for feature in $(grep -oE '"\./features/[^"]+"' "${dir}/devcontainer.json" | cut -d/ -f3 | tr -d '"'); do
        run_test "${image}" "${name}/${feature}" "${ROOT}/test/${feature}/test.sh" true
    done
done

if (( ${#failed[@]} > 0 )); then
    echo "Failed: ${failed[*]}" >&2
    exit 1
fi
echo "All tests passed"
