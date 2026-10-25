#!/usr/bin/env bash
# Print the files an image is built from, as git pathspecs, one per line: its folder, the
# features it includes, and for an image built on another (on base, or e.g. cuda on cpp), that
# image's files, down the chain. Docs and the image's test.sh aren't among them, since changing
# those doesn't change the image.
#
# Usage: scripts/inputs.sh <image>
set -euo pipefail

cd "$(dirname "$0")/.."

name="${1:?Usage: scripts/inputs.sh <image>}"
dir="images/${name}"
if [[ ! -f "${dir}/devcontainer.json" ]]; then
    echo "No such image: ${name}" >&2
    exit 1
fi

echo "${dir}/"
echo ":(exclude)${dir}/test.sh"
echo ":(exclude)${dir}/*.md"
for feature in $(grep -oE '"\./features/[^"]+"' "${dir}/devcontainer.json" | cut -d/ -f3 | tr -d '"'); do
    echo "src/${feature}/"
    echo ":(exclude)src/${feature}/*.md"
done
parent="$(scripts/image-info.sh "${name}" | jq -r '.parent.name // empty')"
if [[ -n "${parent}" ]]; then
    scripts/inputs.sh "${parent}"
fi
