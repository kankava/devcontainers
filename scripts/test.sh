#!/usr/bin/env bash
# Test built images: each image's own images/<name>/test.sh, if it has one, and the test of
# every feature it includes (test/<feature>/test.sh, the one for the feature's default options),
# also those it has from the image it builds on (cuda has cpp's).
# Each test runs in a fresh container that the devcontainer CLI starts, as it would for a project.
#
# Usage: scripts/test.sh [name...]
#   With no names, tests every image. Each image is tested in each of its variants.
#
# Environment:
#   REGISTRY      image prefix (default: ghcr.io/kankava/devcontainer-images)
#   VARIANT       test only this variant
#   TAG           tag to test, for one variant (default: "<version>-<variant>", as scripts/build.sh tags it)
#   DEVCONTAINER  CLI command (default: devcontainer), e.g. "npx -y @devcontainers/cli"
#   BUILDX_BUILDER  buildx builder (default: the current Docker context's builder)
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io/kankava/devcontainer-images}"
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
    info="$("${ROOT}/scripts/image-info.sh" "${name}")"
    repository="$(jq -r .repository <<< "${info}")"
    version="$(jq -r .version <<< "${info}")"
    mapfile -t variants < <(jq -r '.variants[]' <<< "${info}")
    several=false
    if (( ${#variants[@]} > 1 )); then
        several=true
    fi
    if [[ -n "${VARIANT:-}" ]]; then
        if ! jq -e --arg variant "${VARIANT}" '.variants | index($variant)' <<< "${info}" > /dev/null; then
            echo "${name} has no variant ${VARIANT}, only: ${variants[*]}" >&2
            exit 1
        fi
        variants=("${VARIANT}")
    fi
    if [[ -n "${TAG:-}" ]] && (( ${#variants[@]} > 1 )); then
        echo "TAG names the tag of one variant, but ${name} has several: set VARIANT too" >&2
        exit 1
    fi

    # Its features, after those of the images it builds on
    features=()
    link="${name}"
    while [[ -n "${link}" ]]; do
        mapfile -t own < <(grep -oE '"\./features/[^"]+"' "${ROOT}/images/${link}/devcontainer.json" | cut -d/ -f3 | tr -d '"')
        features=("${own[@]}" "${features[@]}")
        link="$("${ROOT}/scripts/image-info.sh" "${link}" | jq -r '.parent.name // empty')"
    done

    for variant in "${variants[@]}"; do
        image="${REGISTRY}/${repository}:${TAG:-${version}-${variant}}"
        label="${name}"
        if ${several}; then
            label="${name}/${variant}"
        fi
        if [[ -f "${dir}/test.sh" ]]; then
            run_test "${image}" "${label}" "${dir}/test.sh" false
        fi
        for feature in "${features[@]}"; do
            run_test "${image}" "${label}/${feature}" "${ROOT}/test/${feature}/test.sh" true
        done
    done
done

if (( ${#failed[@]} > 0 )); then
    echo "Failed: ${failed[*]}" >&2
    exit 1
fi
echo "All tests passed"
