#!/usr/bin/env bash
# The functions test scripts get from `source dev-container-features-test-lib`, as the
# devcontainer CLI provides them to feature tests. scripts/test.sh copies this file in under
# that name, so the same test scripts run against built images.

FAILED=()

check() { # <label> <command> [args...]
    local label="$1"
    shift
    echo "Testing '${label}'"
    if "$@"; then
        echo "Passed '${label}'"
    else
        echo "Failed '${label}'" >&2
        FAILED+=("${label}")
        return 1
    fi
}

reportResults() {
    if (( ${#FAILED[@]} > 0 )); then
        echo "Failed tests: ${FAILED[*]}" >&2
        exit 1
    fi
    echo "Test passed"
    exit 0
}
