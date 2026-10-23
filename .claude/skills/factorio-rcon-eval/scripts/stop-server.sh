#!/usr/bin/env bash
# Stop the server started by start-server.sh and remove its temporary save
# and state directory. Always call this when done, including on error paths
# -- an orphaned server keeps holding its RCON port and a running-but-hidden
# process on the user's machine.
#
# Usage: stop-server.sh <state-dir>
set -euo pipefail

# shellcheck source=lib.sh source-path=SCRIPTDIR
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

STATE_DIR="${1:?usage: stop-server.sh <state-dir>}"

# A start-server.sh that died before recording connection details leaves a
# state directory with only its logs in it. Still worth calling this script on
# that directory -- there is just nothing to send /quit to.
if [ ! -f "$STATE_DIR/info.env" ]; then
  echo "No info.env in $STATE_DIR; removing the directory without a /quit" >&2
  rm -rf "$STATE_DIR"
  exit 0
fi

# shellcheck disable=SC1091
source "$STATE_DIR/info.env"
HOST="${HOST:-127.0.0.1}"
SAVE_ARG="${SAVE_ARG:-$SAVE}"

# /quit does not return promptly: the server drops the connection as it shuts
# down and factorix then sits on the dead socket for minutes. The command only
# has to be delivered, so send it in the background and let the poll below
# decide when the server is actually gone.
factorix rcon exec "/quit" --host "$HOST" --port "$PORT" --password "$PASSWORD" >/dev/null 2>&1 &
QUIT_PID=$!

STOPPED=no
for _ in $(seq 1 10); do
  if ! server_is_alive "$SAVE_ARG" "$HOST" "$PORT" "$PASSWORD"; then
    STOPPED=yes
    break
  fi
  sleep 1
done

kill "$QUIT_PID" 2>/dev/null || true
wait "$QUIT_PID" 2>/dev/null || true

# /quit should be enough, but don't leave an orphaned Factorio process behind
# if it didn't take effect.
if [ "$STOPPED" != yes ]; then
  if factorio_is_windows_binary; then
    # A Windows Factorio has no process here to signal, and killing by image
    # name would take the user's interactive game down with it.
    echo "Server still answering on $HOST:$PORT; quit it by hand" >&2
  else
    pkill -f -- "factorio --start-server $SAVE_ARG" || true
  fi
fi

rm -rf "$STATE_DIR"
