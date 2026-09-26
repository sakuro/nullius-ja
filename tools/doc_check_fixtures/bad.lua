-- Fixture for tools/doc_check_test.sh: every public function here violates one
-- rule. Not loaded by the mod.

local Bad = {}

function Bad.undocumented(value)
  return value
end

-- Uses `--`, so this description does not register as a doc comment at all.
-- @param value number
function Bad.plain_comment(value)
  Bad.value = value
end

---@param value number
---@return number
function Bad.no_summary(value)
  return value
end

--- Documents a parameter that is not declared, and misses one that is.
---@param value number
---@param missing number
function Bad.wrong_params(value, size)
  Bad.value = value / size
end

--- Documents the parameters in the wrong order.
---@param size number
---@param value number
function Bad.swapped_params(value, size)
  Bad.value = value / size
end

--- Returns a value with no @return tag.
---@param value number
function Bad.silent_return(value)
  if value == nil then
    return 0
  end
  return value
end

local function assigned_export(value)
  return value
end

Bad.assigned_export = assigned_export

return Bad
