#!/usr/bin/env bash
# Create a throwaway save and start a headless, RCON-enabled Factorio server
# for it via factorix. Prints the state directory to stdout on success;
# everything else goes to stderr. The caller must pass the state directory
# to eval.sh and stop-server.sh.
#
# Usage: start-server.sh [port] [password]
set -euo pipefail

# shellcheck source=lib.sh source-path=SCRIPTDIR
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

require_factorio_not_running

PORT="${1:-$(( (RANDOM % 20000) + 30000 ))}"
PASSWORD="${2:-$(printf '%04x%04x' "$RANDOM" "$RANDOM")}"
STATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/factorio-rcon-eval.XXXXXX")"
SAVE="$STATE_DIR/eval.zip"
# What Factorio is given; identical to $SAVE for a native binary. $SAVE stays
# the path this script tests for and that stop-server.sh later deletes.
SAVE_ARG="$(to_factorio_path "$SAVE")"

echo "Creating temporary save: $SAVE" >&2
# The path passed to --create MUST be absolute. A relative path fails to
# resolve inside the Factorio process; instead of creating the save and
# exiting, it silently falls back to launching the normal interactive
# desktop game, popping a GUI window on the user's screen.
factorix launch --wait -- --create "$SAVE_ARG" >"$STATE_DIR/create.log" 2>&1

if [ ! -f "$SAVE" ]; then
  echo "Failed to create save file; see $STATE_DIR/create.log" >&2
  exit 1
fi

echo "Starting RCON server on port $PORT" >&2
# `factorix launch` returns as soon as it has spawned the factorio process --
# it does not wait for the server to become ready. Factorio then daemonizes
# (it closes stdin/stdout, logged as "Got EOF on stdin; closing") and keeps
# running detached from this command. Because of this, anything that judges
# liveness by watching this command's own stdio (e.g. a background-task
# runner reporting "completed") can be wrong: that only means the launcher
# step finished, not that the server exited. Liveness must be checked by
# looking at the server itself, which is what the polling loops below do.
factorix launch -- --start-server "$SAVE_ARG" --rcon-port "$PORT" --rcon-password "$PASSWORD" \
  >"$STATE_DIR/server.log" 2>&1

if ! factorio_is_windows_binary; then
  for _ in $(seq 1 30); do
    pgrep -f -- "factorio --start-server $SAVE_ARG" >/dev/null && break
    sleep 1
  done

  if ! pgrep -f -- "factorio --start-server $SAVE_ARG" >/dev/null; then
    echo "Server process never appeared; see $STATE_DIR/server.log" >&2
    exit 1
  fi
fi

# Probing settles which candidate host actually reaches the server, so the
# other scripts don't have to repeat the guesswork.
HOST=""
for _ in $(seq 1 30); do
  for candidate in $(rcon_host_candidates); do
    if rcon_answers "$candidate" "$PORT" "$PASSWORD"; then
      HOST="$candidate"
      break 2
    fi
  done
  sleep 1
done

if [ -z "$HOST" ]; then
  echo "RCON never became ready; see $STATE_DIR/server.log" >&2
  exit 1
fi

cat > "$STATE_DIR/info.env" <<EOF
HOST=$HOST
PORT=$PORT
PASSWORD=$PASSWORD
SAVE=$SAVE
SAVE_ARG=$SAVE_ARG
EOF

echo "$STATE_DIR"
