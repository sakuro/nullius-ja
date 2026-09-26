-- Fixture for tools/doc_check_test.sh: locals the module hands out through its
-- final return table are public and checked; ones it keeps are not. Not loaded by
-- the mod.

local Exports = {}
-- A table, not a local function, so this assignment names nothing to check.
Exports.__index = Exports

--- Documented at its definition, which is where an exported local's doc belongs.
---@param value string
---@return string
local function documented_export(value)
  return value
end

local function undocumented_export(value)
  return value
end

-- Not exported below, so it stays the author's judgement call.
local function kept_private(value)
  return value
end

Exports.private_result = kept_private("x")

return {
  -- A table rather than a function, so this export names nothing to check.
  Exports = Exports,
  documented_export = documented_export,
  undocumented_export = undocumented_export,
}
