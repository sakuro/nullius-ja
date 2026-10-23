---
name: factorio-rcon-eval
description: Run arbitrary Lua code, or a math/expression string, against a real, disposable headless Factorio server, via the factorix CLI and RCON, and get the actual result back. Use this whenever the user wants to run, evaluate, test, or experiment with a Lua snippet against Factorio's real runtime API (inspect a prototype, call a `game`/`helpers`/other runtime function, poke at mod state, try out a piece of control-stage or data-stage-adjacent logic) instead of guessing at its behavior; whenever they want to check, verify, or double-check a formula or calculation (e.g. a recipe cost, a technology unlock-count formula, an ammo/damage formula) against actual runtime behavior; whenever they ask what a Lua expression or `LuaHelpers.evaluate_expression` string evaluates to; or whenever they ask about MathExpression syntax (numeric-suffix support like k/M, hex, scientific notation, variable substitution, built-in functions). Not for editing this or any other mod's own Lua source files -- this is for ad-hoc runtime execution and verification only.
---

# Factorio RCON Eval

Spin up a throwaway headless Factorio server, send it **any Lua code** over
RCON via `factorix`, read back the result, then tear the server down.
Evaluating a math/formula string with `LuaHelpers.evaluate_expression` is
one common case (see the reference below), but the underlying mechanism is
just RCON access to a live Factorio instance -- use it for arbitrary Lua
just as readily: inspecting `game.entity_prototypes`, calling `helpers.*`,
poking at a mod's globals, trying out a snippet before it goes into `lib/`,
whatever the task calls for. Nothing here touches the user's real save
files or an already-running Factorio session -- every invocation creates
its own save in a fresh temp directory and its own server on its own port.

## Prerequisites

- `factorix` is installed and configured (`factorix path --json` should
  succeed and show a valid `executable_path`).
- A licensed copy of Factorio is installed at that path.
- Either `jq` or `python3`, to read that JSON.

If any is missing, tell the user instead of trying to work around it --
this skill does not install Factorio or factorix.

No Factorio may be running: a second instance cannot share the user
directory. `start-server.sh` refuses to start while the lock is held and
says so; relay that rather than trying to work around it.

## Workflow

1. **Start the server**:
   ```
   bash ~/.claude/skills/factorio-rcon-eval/scripts/start-server.sh
   ```
   Run this with the Bash tool. It creates a new save in a temp directory,
   starts a headless server against it with RCON enabled, waits until RCON
   actually answers, and prints a **state directory** path on stdout. Keep
   that path -- every later step needs it. This step normally takes several
   seconds (mod loading, checksum computation); let it run rather than
   assuming failure if it isn't instant.

2. **Evaluate** (repeat as many times as needed for the task):
   ```
   bash ~/.claude/skills/factorio-rcon-eval/scripts/eval.sh <state-dir> "<lua>"
   ```
   `<lua>` can be any Lua chunk -- `factorix rcon eval` wraps it in `/c`
   automatically, and `rcon.print(...)` is how you get a value back on
   stdout. Multi-statement snippets, `pcall`, loops, table construction --
   anything the Factorio Lua runtime allows is fair game: inspect
   prototypes, call `game`/`helpers`/other runtime APIs, poke at mod state,
   try out control-stage logic. For a pure math/formula check specifically,
   wrap it in `rcon.print(helpers.evaluate_expression(...))` -- see the
   reference below for exactly how to call it. One snippet is capped at 511
   bytes on the wire, so split a long probe across several calls instead of
   packing it into one.

3. **Stop the server**:
   ```
   bash ~/.claude/skills/factorio-rcon-eval/scripts/stop-server.sh <state-dir>
   ```
   Always run this when done -- including when a step above failed, and even
   if `start-server.sh` never got far enough to print connection details --
   so no orphaned Factorio process or temp save is left behind. It quits the
   server, waits for it to go away, and deletes the state directory (temp
   save included). If the server outlives `/quit` it is killed where that is
   possible and reported otherwise, so read this script's stderr.

### Why a script, and why the liveness checks inside it

Starting the server is more failure-prone than it looks, for two reasons
that aren't obvious from the command line alone, both confirmed by running
this by hand:

- `--create <path>` **must be an absolute path**. A relative one fails to
  resolve inside the Factorio process, and instead of writing the save and
  exiting, Factorio silently falls back to opening the normal interactive
  desktop game -- a GUI window popping up on the user's screen with no save
  ever written.
- Once RCON is up, Factorio daemonizes: it closes stdin/stdout (logged as
  `Got EOF on stdin; closing`) and keeps running fully detached. `factorix
  launch` itself returns as soon as it has spawned that process, without
  waiting for it to be ready. The upshot is that anything watching this
  command's own stdio -- including a background-task runner reporting a run
  as "completed" -- can be telling you the *launcher* finished, not that the
  *server* exited. The only trustworthy check is looking for the process
  itself (`pgrep -f "factorio --start-server <save>"`), or, where Factorio
  runs outside this process namespace, whether RCON still answers -- which
  is what the scripts poll on. If you ever bypass them and drive `factorix
  launch`/`factorix rcon` by hand, keep using those for liveness, not a
  background task's completion status.

### When Factorio is a Windows binary

`factorix` may point at the Windows desktop build while the scripts run
under WSL (or Cygwin/MSYS). `scripts/lib.sh` detects that from the
executable name and adapts; the workflow above does not change. Two traps
it absorbs, both worth knowing before driving `factorix` by hand there:

- A Unix path handed to that binary is **not** rejected. It is resolved
  against the UNC share root with the share component dropped, so
  `/tmp/x.zip` is logged as saved to `\\wsl.localhost/tmp/x.zip` -- no
  distro name -- and the file never appears. Convert with `wslpath -w`
  first.
- RCON listens on the Windows host, not on this namespace's loopback, so
  under WSL2's default networking `--host` has to be the gateway address
  from `ip route`. A probe to a host that has stopped listening hangs
  instead of being refused, so bound every RCON call with `timeout`.

## Reference: math/formula checks via `LuaHelpers.evaluate_expression`

Signature: `helpers.evaluate_expression(expression, variables?) -> double`.
Full docs: https://lua-api.factorio.com/latest/classes/LuaHelpers.html and
https://lua-api.factorio.com/latest/concepts/MathExpression.html. Facts
below were confirmed by hand against a real server, and go beyond what the
official docs spell out:

- `variables` is a `{string = number}` table substituted into the
  expression, e.g. `helpers.evaluate_expression('a+b*2', {a=3,b=4})` -> `11`.
- Referencing a name not in `variables` raises a Lua error, e.g.
  `Unknown variable 'a' at position 0 near 'a+1'.` -- wrap the call in
  `pcall` if the expression's variable names aren't known ahead of time.
- Supported number formats: decimal, hex (`0x2a5f`), scientific (`4.2e-5`).
  Built-in functions: `abs`, `log2`, `sign`, `max` (2-255 args), `min`
  (2-255 args). Operators: `+ - * / ^` and parentheses, standard precedence.
- **There is no built-in k/M/G-style numeric suffix.** `2k` on its own
  raises `Unknown variable 'k'`. But a number directly followed by an
  identifier (or an opening paren) is parsed as **implicit multiplication**
  -- confirmed with `2k`, `2 k` (whitespace doesn't matter), `2.5k`,
  `2k+3M`, and `2(3+1)` -- so passing suffix letters as variables gets you
  suffix notation for free:
  ```lua
  rcon.print(helpers.evaluate_expression('2.5k + 3M', {k = 1000, M = 1000000}))
  -- 3002500
  ```
  This is genuine multiplication (`2*k`), not string parsing of a
  suffix -- it works the same for any identifier, not just k/M, and is
  case-sensitive (`{k=1000}` does not make `2K` work).

## Cleanup discipline

If a task involves several evaluations, start once, run every `eval.sh`
call against that same state directory, and stop once at the end -- don't
start a new server per expression. If something goes wrong mid-task, still
run `stop-server.sh` on whatever state directory was created before
reporting the failure.
