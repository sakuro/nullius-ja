-- Factorio's own load mechanism fixes which globals are available at which
-- stage. lib/** deliberately gets the union of every stage's globals rather
-- than being pinned to control-only ones: AGENTS.md documents it as holding
-- helpers "shared across stages", not just control-stage logic.
std = "lua52"

-- luacheck does not read .gitignore; without this, `luacheck .` also checks build
-- output under dist/ and scratch files under tmp/.
exclude_files = { "dist/", "tmp/" }

read_globals = {
  "mods",
  "log",
}

local data_stage_globals = { "settings" }
local control_stage_globals = {
  "game",
  "script",
  "remote",
  "defines",
  "helpers",
  "prototypes",
  "commands",
  "rcon",
  "rendering",
  "settings",
}

-- `data` is the data stage's own prototype table and the stage exists to write
-- into it. `data:extend{...}` is a call and passes either way, but a GUI style
-- is a field write (`data.raw["gui-style"].default.foo = {...}`), which as a
-- read-only global trips "indirectly setting read-only field of global data".
-- `settings` stays read-only: the data stage reads startup values from it.
local data_stage_write_globals = { "data" }

-- `storage` is the one control-stage global mods are meant to write into (it
-- is the mod's own persisted-state table, initialized empty by Factorio) —
-- unlike the rest of control_stage_globals, which are only ever read/called.
-- Kept as `globals`, not `read_globals`, wherever control_stage_globals
-- applies, so field writes like `storage.foo = storage.foo or {}` don't trip
-- "setting read-only field of global storage".
local control_stage_write_globals = { "storage" }

local function concat(...)
  local result = {}
  for _, list in ipairs({ ... }) do
    for _, name in ipairs(list) do
      table.insert(result, name)
    end
  end
  return result
end

files["settings*.lua"] = { read_globals = data_stage_globals, globals = data_stage_write_globals }
files["data*.lua"] = { read_globals = data_stage_globals, globals = data_stage_write_globals }
files["prototypes/**/*.lua"] = { read_globals = data_stage_globals, globals = data_stage_write_globals }
files["control.lua"] = { read_globals = control_stage_globals, globals = control_stage_write_globals }
files["lib/**/*.lua"] = {
  read_globals = concat(data_stage_globals, control_stage_globals),
  globals = concat(data_stage_write_globals, control_stage_write_globals),
}

-- A spec exercises lib/ code and fakes whatever runtime that code touches, so
-- it gets the same globals lib/ does. luacheck's own default adds the busted
-- DSL on top of this for **/spec/**/*_spec.lua.
files["spec/**/*.lua"] = {
  read_globals = concat(data_stage_globals, control_stage_globals),
  globals = concat(data_stage_write_globals, control_stage_write_globals),
}
