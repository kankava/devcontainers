#!/usr/bin/env bash
# Print what the scripts and CI need to know about an image, as one line of JSON:
#   name        its folder under images/
#   repository  where it's published under the registry: "repository" in its image.json if
#               set, as images/base-debian publishes as base, else its name
#   version     from its image.json
#   variants    what it's built in, the first being its default: a base image lists them in
#               its image.json (e.g. trixie, or trixie and trixie-slim); any other image is built in the one
#               variant of the image it builds on
#   parent      for an image built on another of these images (on base, or e.g. cuda on cpp):
#               that image, and the version and variant from its pin in devcontainer.json, e.g.
#               for base:1.0.0-trixie
#               { "name": "base-debian", "repository": "base", "version": "1.0.0", "variant": "trixie" };
#               else null
#   depth       how many images it builds on: 0 for a base image, 1 for an image on base, 2 for
#               an image on one of those
#
# Usage: scripts/image-info.sh <image>
set -euo pipefail

cd "$(dirname "$0")/.."

name="${1:?Usage: scripts/image-info.sh <image>}"
dir="images/${name}"
if [[ ! -f "${dir}/devcontainer.json" ]]; then
    echo "No such image: ${name}" >&2
    exit 1
fi
# The images this call is working out the parents of, to stop at a loop
if [[ " ${IMAGE_INFO_CHAIN:-} " == *" ${name} "* ]]; then
    echo "images/${name} builds on itself:${IMAGE_INFO_CHAIN} ${name}" >&2
    exit 1
fi
export IMAGE_INFO_CHAIN="${IMAGE_INFO_CHAIN:-} ${name}"

# It builds on another of these images when devcontainer.json's "image" names one's repository,
# as <registry>/<repository>:<version>-<variant>
parent=null
depth=0
ref="$(sed -nE 's#.*"image": *"([^"]+)".*#\1#p' "${dir}/devcontainer.json")"
repository="${ref##*/}"
repository="${repository%%:*}"
tag="${ref##*:}"
found=false
for file in images/*/image.json; do
    candidate="$(basename "$(dirname "${file}")")"
    [[ "${candidate}" != "${name}" ]] || continue
    [[ "$(jq -r --arg name "${candidate}" '.repository // $name' "${file}")" == "${repository}" ]] || continue
    found=true
    if ! [[ "${tag}" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-(.+)$ ]]; then
        echo "${dir}/devcontainer.json builds on ${repository}:${tag}: name a version and a variant, e.g. ${repository}:1.0.0-trixie" >&2
        exit 1
    fi
    version="${BASH_REMATCH[1]}"
    variant="${BASH_REMATCH[2]}"
    # Several images can publish to one repository (base-debian and a base-ubuntu as base): the
    # one with this variant
    info="$(scripts/image-info.sh "${candidate}")"
    if jq -e --arg variant "${variant}" '.variants | index($variant)' <<< "${info}" > /dev/null; then
        parent="$(jq -c --arg version "${version}" --arg variant "${variant}" '{name, repository, $version, $variant}' <<< "${info}")"
        depth=$(( $(jq .depth <<< "${info}") + 1 ))
        break
    fi
done
if ${found} && [[ "${parent}" == null ]]; then
    echo "${dir}/devcontainer.json builds on ${repository}:${tag}, but ${repository} has no variant ${variant}" >&2
    exit 1
fi

jq -c --arg name "${name}" --argjson parent "${parent}" --argjson depth "${depth}" '
    {
        $name,
        repository: (.repository // $name),
        version,
        variants: (.variants // [$parent.variant // empty]),
        $parent,
        $depth
    }
    | if .variants == [] then error("images/\(.name) needs variants in its image.json, or to build on one of the images, e.g. base:<version>-<variant>") end
' "${dir}/image.json"
