# Shared helpers for the factorio-rcon-eval scripts. Source, don't execute --
# hence no shebang and no executable bit.
#
# Everything here exists to keep the other three scripts identical across
# installs. The one case that genuinely differs is a Windows Factorio binary
# driven from a Unix-like layer (WSL, Cygwin, MSYS): it cannot resolve the
# Unix paths we hand it, and its sockets live on the Windows host rather than
# in our network namespace. A native install takes every default branch here.

# shellcheck shell=bash

# Print one top-level string field of `factorix path --json`.
factorix_path_field() {
  local field="$1"
  local json
  json="$(factorix path --json)" || return 1
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --arg f "$field" '.[$f] // empty'
  else
    printf '%s' "$json" |
      python3 -I -c 'import json, sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$field"
  fi
}

_FACTORIO_IS_WINDOWS_BINARY=""

# Is the configured Factorio a Windows executable? Decided by the binary we
# are told to run, not by the host OS: WSL can hold either a native headless
# Factorio or the Windows desktop build, and only the latter needs the
# workarounds below.
factorio_is_windows_binary() {
  if [ -z "$_FACTORIO_IS_WINDOWS_BINARY" ]; then
    local exe
    exe="$(factorix_path_field executable_path)" || exe=""
    case "$exe" in
    *.exe | *.EXE) _FACTORIO_IS_WINDOWS_BINARY=yes ;;
    *) _FACTORIO_IS_WINDOWS_BINARY=no ;;
    esac
  fi
  [ "$_FACTORIO_IS_WINDOWS_BINARY" = yes ]
}

# Translate a path into the form the Factorio binary can resolve, and echo it.
# A no-op for a native binary.
#
# Handing a Windows Factorio a rooted Unix path does NOT fail loudly: it
# resolves the path against the UNC share root, loses the share component
# (`/tmp/x` becomes `\\wsl.localhost/tmp/x`, with no distro name) and logs a
# save it never actually writes. So the conversion has to happen up front.
to_factorio_path() {
  local path="$1"
  if factorio_is_windows_binary; then
    if command -v wslpath >/dev/null 2>&1; then
      wslpath -w "$path"
      return
    elif command -v cygpath >/dev/null 2>&1; then
      cygpath -w "$path"
      return
    fi
  fi
  printf '%s' "$path"
}

# Print the RCON hosts to probe, in order. A native server answers on
# loopback; a Windows one binds on the Windows host, which under WSL2's
# default NAT networking is reachable only via the gateway address (with
# mirrored networking loopback works and the first candidate already wins).
rcon_host_candidates() {
  printf '127.0.0.1\n'
  if factorio_is_windows_binary; then
    ip route 2>/dev/null | awk '/^default/ { print $3; exit }'
  fi
}

# Run a command under a deadline where the system provides one, otherwise
# plainly. Only RCON probes need this, and only against a non-loopback host:
# a refused connection on loopback fails at once, while a dropped SYN to a
# host that stopped listening hangs until the TCP stack gives up. That host
# is the Windows one, i.e. WSL, where coreutils `timeout` is always present.
with_deadline() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
  else
    "$@"
  fi
}

rcon_answers() {
  local rcon_host="$1" rcon_port="$2" rcon_pass="$3"
  with_deadline 5 factorix rcon eval "rcon.print(1)" \
    --host "$rcon_host" --port "$rcon_port" --password "$rcon_pass" >/dev/null 2>&1
}

# Is the server we started still alive? A Windows Factorio has no process in
# this namespace, so there RCON is the only liveness signal available.
server_is_alive() {
  local save_path="$1" rcon_host="$2" rcon_port="$3" rcon_pass="$4"
  if factorio_is_windows_binary; then
    rcon_answers "$rcon_host" "$rcon_port" "$rcon_pass"
  else
    pgrep -f -- "factorio --start-server $save_path" >/dev/null
  fi
}

# Refuse to start while Factorio's user-directory lock is held. Without this
# check a launch blocked by an already-running game fails silently: no save,
# an empty create.log, and not even a Factorio log entry to point at.
require_factorio_not_running() {
  local lock
  lock="$(factorix_path_field lock_path)" || lock=""
  [ -n "$lock" ] && [ -e "$lock" ] || return 0

  cat >&2 <<EOF
Factorio's user-directory lock is held:
  $lock
Another Factorio -- most likely the interactive game, possibly a server left
over from an earlier run -- is using that directory. A second instance cannot
start. Close it and retry. If nothing is running, the lock is stale and can be
deleted.
EOF
  return 1
}
