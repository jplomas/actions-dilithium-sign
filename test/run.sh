#!/bin/bash
#
# Checks that the pinned qrlft and this action's entrypoint still agree.
#
# That agreement is the thing most likely to break here. qrlft has since made
# --algorithm mandatory, so the invocation this action used before the entrypoint
# was corrected now fails outright — and an unpinned clone meant a rebuild could
# pick that up without anyone changing a line of this repo. The pin prevents it;
# this catches it if the pin ever moves.
#
# Set QRLFT to an existing binary, or let this build the pinned one.

set -e
set -o pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "  ok    $1"; }
no() { fail=$((fail + 1)); echo "  FAIL  $1"; }
check() { if [ "$1" = "yes" ]; then ok "$2"; else no "$2"; fi; }

if [ -z "$QRLFT" ]; then
  COMMIT="$(grep -oE 'ARG QRLFT_COMMIT=[0-9a-f]+' "$ROOT/Dockerfile" | cut -d= -f2)"
  echo "building qrlft $COMMIT"
  curl -sL "https://github.com/theQRL/qrlft/archive/${COMMIT}.tar.gz" | tar xz -C "$WORK"
  (cd "$WORK"/qrlft-* && CGO_ENABLED=0 go build -o "$WORK/qrlft" .)
  QRLFT="$WORK/qrlft"
fi

cd "$WORK"
mkdir -p dist
printf 'first payload'  > dist/app_v1.0.0_linux_amd64.zip
printf 'second payload' > dist/app_v1.0.0_windows_amd64.zip

"$QRLFT" new -a dilithium key > /dev/null
SEED="$(sed -n 2p key.private.hexseed | sed 's/^0x//')"

echo
echo "signing"
"$ROOT/entrypoint.sh" "$SEED" signatures.txt "dist/*.zip"

check "$([ -s signatures.txt ] && echo yes)" "the entrypoint runs against the pinned qrlft"
check "$([ "$(wc -l < signatures.txt | tr -d ' ')" = "2" ] && echo yes)" "one line per matched file"

# 4595 bytes. Dilithium5 and ML-DSA-87 differ only in signature length, 4595
# against 4627, and share a public key size, so this is the only thing that
# tells them apart.
LEN="$(head -1 signatures.txt | awk '{print length($1)}')"
check "$([ "$LEN" = "9190" ] && echo yes)" "signatures are Dilithium5, not something else ($LEN hex chars)"

echo
echo "verifying"
SIG="$(head -1 signatures.txt | awk '{print $1}')"
NAME="$(head -1 signatures.txt | awk '{print $2}')"
if "$QRLFT" verify -a dilithium --signature="$SIG" --pkfile=key.pub "$NAME" > /dev/null 2>&1; then
  ok "a signature it produced verifies against the generated key"
else
  no "a signature it produced verifies against the generated key"
fi

printf 'tampered' > "$NAME"
if "$QRLFT" verify -a dilithium --signature="$SIG" --pkfile=key.pub "$NAME" > /dev/null 2>&1; then
  no "altered bytes are rejected"
else
  ok "altered bytes are rejected"
fi

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
