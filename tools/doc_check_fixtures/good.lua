-- Fixture for tools/doc_check_test.sh: every public function here conforms.
-- Not loaded by the mod.

local Good = {}

--- Reports nothing and takes nothing -- summary only, no tags needed.
function Good.register()
  Good.registered = true
end

--- Rounds value up to the next multiple of size.
---
--- The rationale paragraph is optional and says why, not what.
---@param value number
---@param size number
---@return number
function Good.round_up(value, size)
  return size * (math.floor(value / size) + 1)
end

--- Returns early without a value, so no @return is required.
---@param player table
function Good.maybe_act(player)
  if player == nil then
    return
  end
  Good.acted = true
end

--- Sums whatever contents arrays the caller passes.
---@param ... table
---@return table
function Good.merge(...)
  local total = {}
  for _, contents in ipairs({ ... }) do
    table.insert(total, contents)
  end
  return total
end

--- A colon method: `self` is implicit and is not a documented parameter.
---@param name string
---@return boolean
function Good:has(name)
  return self[name] ~= nil
end

--- A value returned by a nested closure is the closure's, not this function's.
---@param names table
function Good.sort(names)
  table.sort(names, function(left, right)
    return left < right
  end)
end

--- A parameter list stylua wrapped across lines is still matched in order.
---@param first_component_name string
---@param second_component_name string
---@param third_component_name string
---@param fourth_component_name string
---@param fifth_component_name string
---@return string
function Good.join(
  first_component_name,
  second_component_name,
  third_component_name,
  fourth_component_name,
  fifth_component_name
)
  return first_component_name
    .. second_component_name
    .. third_component_name
    .. fourth_component_name
    .. fifth_component_name
end

--- A local the module hands out by assignment, documented at its definition.
---@param value string
---@return string
local function assigned_export(value)
  return value
end

Good.assigned_export = assigned_export

return Good
