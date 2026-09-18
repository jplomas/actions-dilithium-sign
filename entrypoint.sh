#!/bin/bash

set -e
set -o pipefail

QRLFT="${QRLFT:-/qrlft/qrlft}"

# Unquoted on purpose: the patterns input is a list of globs, and this is where
# they expand. Long-standing behaviour, kept as it is.
# shellcheck disable=SC2086
"$QRLFT" sign -a dilithium --hexseed "$1" $3 > "$2"
