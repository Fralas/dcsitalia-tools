--------------------------------------------------------------------------------------------------------------------------------
-- config_export.lua - Import/export blocco confini in DZONE_TEST_Config.lua
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")
local graph_mod = require("dcore_zone_linker.graph")

local M = {}

local function _read_file(path)
  local f = io.open(path, "r")
  if not f then return nil, "file not found: " .. tostring(path) end
  local content = f:read("*a")
  f:close()
  return content
end

local function _write_file(path, content)
  local f, err = io.open(path, "w")
  if not f then return false, tostring(err) end
  f:write(content)
  f:close()
  return true
end

local function _format_confini_block(confini)
  local keys = util.sorted_keys(confini)
  local lines = { "local confini = {" }

  for _, zn in ipairs(keys) do
    local neighbors = confini[zn] or {}
    local parts = {}
    for _, nn in ipairs(neighbors) do
      parts[#parts + 1] = string.format("%q", nn)
    end
    lines[#lines + 1] = string.format('  [%q] = {%s},', zn, table.concat(parts, ", "))
  end

  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

function M.parse_confini_from_config(path)
  local content, err = _read_file(path)
  if not content then return nil, err end

  local start = content:find("local%s+confini%s*=%s*{")
  if not start then
    return nil, "block 'local confini = {' not found"
  end

  local chunk = content:sub(start)
  local depth = 0
  local end_pos = nil
  for i = 1, #chunk do
    local ch = chunk:sub(i, i)
    if ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      depth = depth - 1
      if depth == 0 then
        end_pos = i
        break
      end
    end
  end

  if not end_pos then
    return nil, "confini block not terminated"
  end

  local table_part = chunk:match("confini%s*=%s*(%b{})")
  if not table_part then
    return nil, "confini table not extracted"
  end

  local fn, load_err = loadstring("return " .. table_part)
  if not fn then
    return nil, "confini parse failed: " .. tostring(load_err)
  end

  local ok, confini = pcall(fn)
  if not ok or type(confini) ~= "table" then
    return nil, "confini is not a table"
  end

  return confini
end

function M.replace_confini_in_config(path, confini)
  local content, err = _read_file(path)
  if not content then return false, err end

  local start, end_block = content:find("local%s+confini%s*=%s*{")
  if not start then
    return false, "block 'local confini = {' not found"
  end

  local tail = content:sub(start)
  local depth = 0
  local rel_end = nil
  for i = 1, #tail do
    local ch = tail:sub(i, i)
    if ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      depth = depth - 1
      if depth == 0 then
        rel_end = i
        break
      end
    end
  end

  if not rel_end then
    return false, "confini block not terminated"
  end

  local abs_end = start + rel_end - 1
  local new_block = _format_confini_block(confini)
  local new_content = content:sub(1, start - 1) .. new_block .. content:sub(abs_end + 1)

  local backup_path = path .. ".bak"
  local backup_ok = _write_file(backup_path, content)
  if not backup_ok then
    util.warn("backup not created: " .. backup_path)
  end

  local ok, write_err = _write_file(path, new_content)
  if not ok then
    return false, write_err
  end

  return true
end

function M.import_from_config(path)
  local confini, err = M.parse_confini_from_config(path)
  if not confini then return nil, err end
  local g = graph_mod.new({})
  for zn, neighbors in pairs(confini) do
    if type(neighbors) == "table" then
      for _, nn in ipairs(neighbors) do
        graph_mod.link(g, zn, nn)
      end
    end
  end
  graph_mod.normalize_symmetry(g)
  g.dirty = false
  return g
end

function M.export_graph(graph, path)
  if not graph then return false, "invalid graph" end
  local confini = graph_mod.to_confini(graph)
  return M.replace_confini_in_config(path, confini)
end

return M
