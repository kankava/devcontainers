#!/usr/bin/env bash
# Print the files an image is built from, as git pathspecs, one per line: its folder, the
# features it includes, and for every image but base, base's own files. Docs and the image's
# test.sh aren't among them, since changing those doesn't change the image.
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
if [[ "${name}" != base ]]; then
    scripts/inputs.sh base
fi
