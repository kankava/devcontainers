#!/usr/bin/env bash
# Run with: scripts/test.sh base
set -e

source dev-container-features-test-lib

check "user dev" test "$(id -un)" = dev
check "passwordless sudo" sudo -n true
check "home writable" test -w "${HOME}"
check "$HOME/.local/bin on PATH" bash -c 'tr : "\n" <<< "${PATH}" | grep -qx "${HOME}/.local/bin"'
check "UTF-8 locale" test "${LANG}" = C.UTF-8
check "CA certificates" test -s /etc/ssl/certs/ca-certificates.crt
for tool in git curl wget ssh gpg less unzip xz ps; do
    check "${tool}" command -v "${tool}"
done
check "bash completion" test -f /usr/share/bash-completion/bash_completion

reportResults
