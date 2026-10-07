#!/usr/bin/env bash
# Bump the version of an image or a feature for a release, along with everything built from it:
#   image base      every image, since they all build on base, and their base:<version> moves with it
#   feature <name>  every image that includes the feature
#   image <name>    that image only
#
# Each version moves one level up from its last published version (the git tags
# image_<name>_<version> and feature_<name>_<version>), unless it's already past that, so running
# it twice, or after another bump, doesn't bump twice. Run git fetch first, so the tags of the
# latest releases are there.
#
# Usage: scripts/bump.sh image|feature <name> patch|minor|major
#   scripts/bump.sh image base patch    Debian's security updates, for every image
set -euo pipefail

cd "$(dirname "$0")/.."

usage() {
    echo "Usage: scripts/bump.sh image|feature <name> patch|minor|major" >&2
    exit 1
}
(( $# == 3 )) || usage
kind="$1" name="$2" level="$3"
[[ "${kind}" =~ ^(image|feature)$ && "${level}" =~ ^(patch|minor|major)$ ]] || usage

version_file() { # <kind> <name>
    case "$1" in
        image) echo "images/$2/image.json" ;;
        feature) echo "src/$2/devcontainer-feature.json" ;;
    esac
}

last_published() { # <kind> <name>: empty when there's none
    git tag -l "$1_$2_*" | sed "s/^$1_$2_//" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1 || true
}

next() { # <version> <level>
    local major minor patch
    IFS=. read -r major minor patch <<< "$1"
    case "$2" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
    esac
}

# Rewrites the file rather than running it through jq, to keep its formatting
set_version() { # <file> <version>
    awk -v v="$2" '!done && sub(/"version": *"[^"]*"/, "\"version\": \"" v "\"") { done = 1 } { print }' "$1" > "$1.tmp"
    mv "$1.tmp" "$1"
    if [[ "$(jq -r .version "$1")" != "$2" ]]; then
        echo "Couldn't set the version in $1" >&2
        exit 1
    fi
}

bump() { # <kind> <name>
    local file current last new
    file="$(version_file "$1" "$2")"
    if [[ ! -f "${file}" ]]; then
        echo "No such $1: $2" >&2
        exit 1
    fi
    current="$(jq -r .version "${file}")"
    last="$(last_published "$1" "$2")"
    if [[ -z "${last}" ]]; then
        echo "$1 $2: ${current} (not published yet)"
        return
    fi
    new="$(printf '%s\n' "${current}" "$(next "${last}" "${level}")" | sort -V | tail -1)"
    [[ "${new}" == "${current}" ]] || set_version "${file}" "${new}"
    echo "$1 $2: ${last} -> ${new}"
}

# Makes an image build on base's current version
pin_base() { # <image>
    local file="images/$1/devcontainer.json" version
    version="$(jq -r .version images/base/image.json)"
    awk -v v="${version}" '/"image":/ { sub(/\/base:[^"]*"/, "/base:" v "\"") } { print }' "${file}" > "${file}.tmp"
    mv "${file}.tmp" "${file}"
}

bump "${kind}" "${name}"
case "${kind}" in
    image)
        if [[ "${name}" == base ]]; then
            for dir in images/*/; do
                image="$(basename "${dir}")"
                [[ "${image}" != base ]] || continue
                pin_base "${image}"
                bump image "${image}"
            done
        fi
        ;;
    feature)
        for file in $(grep -lE "\"\./features/${name}\"" images/*/devcontainer.json || true); do
            bump image "$(basename "$(dirname "${file}")")"
        done
        ;;
esac
