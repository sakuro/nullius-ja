#!/usr/bin/env bash
# Send one Lua snippet to the server started by start-server.sh via RCON.
# `factorix rcon eval` wraps the snippet in /c before sending it, so use
# rcon.print(...) to get a value back on stdout.
#
# A snippet is capped at 511 bytes on the wire; split a long probe into
# several calls rather than packing it into one.
#
# Usage: eval.sh <state-dir> <lua-code>
set -euo pipefail

STATE_DIR="${1:?usage: eval.sh <state-dir> <lua-code>}"
LUA_CODE="${2:?usage: eval.sh <state-dir> <lua-code>}"

# shellcheck disable=SC1091
source "$STATE_DIR/info.env"

factorix rcon eval "$LUA_CODE" --host "${HOST:-127.0.0.1}" --port "$PORT" --password "$PASSWORD"
