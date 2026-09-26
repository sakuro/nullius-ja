-- Fixture for tools/doc_check_test.sh: a module whose whole public surface is one
-- bare `return name`. Not loaded by the mod.

local function bare_export(value)
  return value
end

return bare_export
