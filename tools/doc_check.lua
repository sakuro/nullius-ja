-- Check the function doc-comment convention on public functions in the mod's
-- own Lua source.
-- The convention itself is documented in CONTRIBUTING.md "Comment conventions".
--
-- Usage:
--   lua tools/doc_check.lua [--baseline PATH] [--write-baseline] FILE...
--
-- Prints one line per violation and exits 1 when any remain. A function listed
-- in the baseline file has all of its violations suppressed, so the existing
-- backlog doesn't block the gate while it is worked through; a baseline entry
-- whose function is now clean, or which no longer exists, is itself reported so
-- the file can only shrink. --write-baseline prints the entries for every
-- currently-violating function to stdout instead of checking.
--
-- "Public" means reachable from outside the module, whichever syntax gets it
-- there: a `function Module.name(...)` / `function Module:name(...)` definition, or
-- a `local function` the module hands out through its final `return` (bare or in a
-- table) or an assignment onto the module table. An exported local is checked at
-- its own definition, which is where its doc comment belongs. Locals that stay
-- inside the module are the author's judgement call.

local OPENERS = { ["function"] = true, ["do"] = true, ["if"] = true, ["repeat"] = true }
local CLOSERS = { ["end"] = true, ["until"] = true }

local function read_lines(path)
  local handle = assert(io.open(path, "r"))
  local lines = {}
  for line in handle:lines() do
    table.insert(lines, line)
  end
  handle:close()
  return lines
end

-- Strips comments and string literals so keyword counting can't be fooled by
-- the word "end" inside a message. Long strings and long comments (`[[...]]`)
-- are not handled; no MOD source uses them yet.
local function code_only(line)
  local stripped = line:gsub('"[^"]*"', '""'):gsub("'[^']*'", "''")
  return (stripped:gsub("%-%-.*$", ""))
end

-- Declared parameter names, in order. stylua wraps a long parameter list across
-- lines, so the list is followed until its parentheses balance. `self` is
-- implicit in a `:` declaration and so never appears here.
local function parameters(lines, index)
  local text = code_only(lines[index])
  local last = index
  local start = text:find("%(")
  if start == nil then
    return {}
  end
  local depth = 0
  local cursor = start
  while true do
    while cursor > #text do
      last = last + 1
      if lines[last] == nil then
        return {}
      end
      text = text .. " " .. code_only(lines[last])
    end
    local char = text:sub(cursor, cursor)
    if char == "(" then
      depth = depth + 1
    elseif char == ")" then
      depth = depth - 1
      if depth == 0 then
        local names = {}
        for name in text:sub(start + 1, cursor - 1):gmatch("[^,%s]+") do
          table.insert(names, name)
        end
        return names
      end
    end
    cursor = cursor + 1
  end
end

-- The contiguous `---` block directly above the definition, in source order.
local function doc_block(lines, index)
  local block = {}
  local cursor = index - 1
  while cursor >= 1 and lines[cursor]:match("^%-%-%-") do
    table.insert(block, 1, lines[cursor])
    cursor = cursor - 1
  end
  return block
end

-- True when the function starting at `index` returns a value of its own, as
-- opposed to a bare `return` used for an early exit, or a value returned by a
-- closure nested inside it.
local function returns_value(lines, index)
  local stack = {}
  local nested = 0
  local cursor = index
  while lines[cursor] ~= nil do
    local code = code_only(lines[cursor])
    local position = 1
    while true do
      local from, to, word = code:find("([%a_][%w_]*)", position)
      if from == nil then
        break
      end
      position = to + 1
      if word == "return" then
        if nested == 0 then
          local rest = code:sub(to + 1):gsub("^%s+", "")
          if rest ~= "" and not rest:match("^end%f[%W]") and not rest:match("^;") then
            return true
          end
        end
      elseif OPENERS[word] then
        table.insert(stack, word)
        if word == "function" and #stack > 1 then
          nested = nested + 1
        end
      elseif CLOSERS[word] then
        local closed = table.remove(stack)
        if #stack == 0 then
          return false
        end
        if closed == "function" then
          nested = nested - 1
        end
      end
    end
    cursor = cursor + 1
  end
  return false
end

local function problems_for(lines, index)
  local declared = parameters(lines, index)
  local block = doc_block(lines, index)
  local problems = {}

  if #block == 0 then
    if index > 1 and lines[index - 1]:match("^%s*%-%-") then
      table.insert(problems, "doc comment must start with `---`, not `--`")
    else
      table.insert(problems, "missing doc comment")
    end
    return problems
  end

  local found = {}
  local returns = 0
  for _, comment in ipairs(block) do
    local parameter = comment:match("^%-%-%-@param%s+(%S+)")
    if parameter then
      table.insert(found, parameter)
    elseif comment:match("^%-%-%-@return%s") then
      returns = returns + 1
    end
  end

  if block[1]:match("^%-%-%-@") or not block[1]:match("^%-%-%-%s+%S") then
    table.insert(problems, "doc comment must open with a one-line summary")
  end
  if table.concat(found, ",") ~= table.concat(declared, ",") then
    table.insert(
      problems,
      string.format("@param list is (%s), declared (%s)", table.concat(found, ", "), table.concat(declared, ", "))
    )
  end
  if returns == 0 and returns_value(lines, index) then
    table.insert(problems, "returns a value but has no @return")
  end

  return problems
end

-- The names the module makes reachable from outside: a bare `return name`, the
-- values of a final `return { key = name }` table, and `Module.key = name`
-- assignments. Only names that are local functions in this file matter; a
-- `Module.__index = Module` assignment names a table, not a function, so it drops
-- out here.
local function exported_names(lines)
  local names = {}
  local in_return_table = false
  for _, line in ipairs(lines) do
    local code = code_only(line)
    local bare = code:match("^return ([%w_]+)%s*$")
    local assigned = code:match("^[%w_]+%.[%w_]+%s*=%s*([%w_]+)%s*$")
    if bare ~= nil then
      names[bare] = true
    elseif assigned ~= nil then
      names[assigned] = true
    elseif code:match("^return%s*{") then
      in_return_table = true
    end
    if in_return_table then
      local value = code:match("[%w_]+%s*=%s*([%w_]+)")
      if value ~= nil then
        names[value] = true
      end
      if code:match("}") then
        in_return_table = false
      end
    end
  end
  return names
end

local function check_file(path, found)
  local lines = read_lines(path)
  local exported = exported_names(lines)
  for index, line in ipairs(lines) do
    local module, separator, name = line:match("^function ([%w_]+)([.:])([%w_]+)%s*%(")
    local exported_local = line:match("^local function ([%w_]+)%s*%(")
    local qualified = nil
    if module ~= nil then
      qualified = module .. separator .. name
    elseif exported_local ~= nil and exported[exported_local] then
      qualified = exported_local
    end
    if qualified ~= nil then
      table.insert(found, {
        path = path,
        line = index,
        name = qualified,
        key = path .. ":" .. qualified,
        problems = problems_for(lines, index),
      })
    end
  end
end

-- Returns the listed keys, their order, and whether the file was there at all.
-- A missing or misspelled path yields an empty baseline, which can only make the
-- check stricter -- every violation is then reported -- never weaker.
local function read_baseline(path)
  local listed, order = {}, {}
  local handle = path and io.open(path, "r")
  if handle == nil then
    return listed, order, false
  end
  for line in handle:lines() do
    local key = line:gsub("^%s+", ""):gsub("%s+$", "")
    if key ~= "" and not key:match("^#") and listed[key] == nil then
      listed[key] = false
      table.insert(order, key)
    end
  end
  handle:close()
  return listed, order, true
end

local baseline_path, write_baseline, paths = nil, false, {}
local argument = 1
while arg[argument] ~= nil do
  local value = arg[argument]
  if value == "--baseline" then
    argument = argument + 1
    baseline_path = arg[argument]
  elseif value == "--write-baseline" then
    write_baseline = true
  else
    table.insert(paths, value)
  end
  argument = argument + 1
end

if #paths == 0 then
  io.stderr:write("usage: lua tools/doc_check.lua [--baseline PATH] [--write-baseline] FILE...\n")
  os.exit(2)
end

local functions = {}
for _, path in ipairs(paths) do
  check_file(path, functions)
end

if write_baseline then
  -- The header goes in the output so the regeneration command below is the
  -- whole story -- no hand-restored preamble.
  print("# Public functions that predate the doc-comment convention")
  print('# (CONTRIBUTING.md "Comment conventions"). `mise run doc-check` suppresses')
  print("# these and reports any entry that is now documented or gone, so the list")
  print("# can only shrink. Regenerate with:")
  print("#   mise run doc-check -- --write-baseline > .doc-check-baseline")
  for _, entry in ipairs(functions) do
    if #entry.problems > 0 then
      print(entry.key)
    end
  end
  os.exit(0)
end

local listed, order, baseline_present = read_baseline(baseline_path)
local failures = {}

-- The baseline is scaffolding for a backlog, not a permanent file. Once the last
-- entry goes it has no reason to exist, and saying so here is what makes it
-- actually get deleted rather than linger as an empty file.
if baseline_present and #order == 0 then
  table.insert(failures, {
    path = baseline_path,
    line = 0,
    text = string.format(
      "%s: no entries left -- delete the file and drop --baseline from tasks/doc-check",
      baseline_path
    ),
  })
end
for _, entry in ipairs(functions) do
  local in_baseline = listed[entry.key] ~= nil
  if in_baseline then
    listed[entry.key] = true
  end
  local function report(problem)
    table.insert(failures, {
      path = entry.path,
      line = entry.line,
      text = string.format("%s:%d: %s: %s", entry.path, entry.line, entry.name, problem),
    })
  end
  if #entry.problems > 0 then
    if not in_baseline then
      for _, problem in ipairs(entry.problems) do
        report(problem)
      end
    end
  elseif in_baseline then
    report(string.format("documented now -- remove it from %s", baseline_path))
  end
end

for _, key in ipairs(order) do
  if listed[key] == false then
    table.insert(failures, {
      path = key,
      line = 0,
      text = string.format("%s: no such function -- remove it from %s", key, baseline_path),
    })
  end
end

table.sort(failures, function(left, right)
  if left.path ~= right.path then
    return left.path < right.path
  end
  if left.line ~= right.line then
    return left.line < right.line
  end
  return left.text < right.text
end)
for _, failure in ipairs(failures) do
  print(failure.text)
end

if #failures > 0 then
  print(string.format("\n%d problem(s)", #failures))
  os.exit(1)
end
