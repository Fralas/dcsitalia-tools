--------------------------------------------------------------------------------------------------------------------------------
-- persistence.lua - Salvataggio grafo collegamenti per missione
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")
local settings = require("dcore_zone_linker.settings")
local zone_list = require("dcore_zone_linker.zone_list")

local M = {}

local function _sanitize_id(name)
  local id = tostring(name or "unknown_mission")
  id = id:gsub("[^%w%-_%.]", "_")
  if id == "" then id = "unknown_mission" end
  return id
end

function M.mission_id()
  return _sanitize_id(zone_list.get_mission_name())
end

function M.graph_path(mission_id, settings_data)
  local dir = settings.storage_dir(settings_data)
  if not dir then return nil end
  return dir .. "\\" .. _sanitize_id(mission_id) .. ".json"
end

local function _ensure_dir(settings_data)
  local dir = settings.storage_dir(settings_data)
  if not dir then return false end
  os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
  return true
end

local function _encode_string(s)
  return string.format("%q", s)
end

local function _encode_confini(confini)
  local keys = util.sorted_keys(confini)
  local lines = { "{" }
  for _, zn in ipairs(keys) do
    local neighbors = confini[zn] or {}
    local parts = {}
    for _, nn in ipairs(neighbors) do
      parts[#parts + 1] = _encode_string(nn)
    end
    lines[#lines + 1] = "  " .. _encode_string(zn) .. ": [" .. table.concat(parts, ", ") .. "],"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

local function _count_confini_links(confini)
  local seen = {}
  local n = 0
  for zn, neighbors in pairs(confini or {}) do
    for _, nn in ipairs(neighbors or {}) do
      local key = zn < nn and (zn .. "|" .. nn) or (nn .. "|" .. zn)
      if not seen[key] then
        seen[key] = true
        n = n + 1
      end
    end
  end
  return n, util.sorted_keys(confini or {})
end

local function _parse_confini_json(raw)
  local confini = {}
  if type(raw) ~= "string" then return confini end

  raw = raw:match("^%s*(.*)%s*$") or raw
  if raw == "" then return confini end

  local block = raw:match('"confini"%s*:%s*(%b{})')
  if not block then
    return confini
  end

  if block:match("^%s*{%s*}%s*$") then
    return confini
  end

  for zn, list in block:gmatch('"([^"]+)"%s*:%s*%[([^%]]*)%]') do
    confini[zn] = {}
    for nn in list:gmatch('"([^"]+)"') do
      confini[zn][#confini[zn] + 1] = nn
    end
  end

  return confini
end

function M.load(mission_id, settings_data)
  settings_data = settings_data or settings.load()
  if not _ensure_dir(settings_data) then return {}, nil, "storage unavailable" end
  local path = M.graph_path(mission_id, settings_data)
  if not path then return {}, nil, "invalid path" end

  local f = io.open(path, "r")
  if not f then
    return {}, path, "file missing"
  end

  local raw = f:read("*a") or ""
  f:close()

  local confini = _parse_confini_json(raw)
  return confini, path, "ok"
end

function M.load_fresh(mission_id, settings_data)
  settings_data = settings_data or settings.load()
  mission_id = mission_id or M.mission_id()
  local confini, path, status = M.load(mission_id, settings_data)
  if type(confini) ~= "table" then
    confini = {}
  end

  local link_count, zone_keys = _count_confini_links(confini)
  util.info(string.format(
    "JSON load [%s] mission=%s zones=%d links=%d root=%s",
    tostring(status),
    tostring(mission_id),
    #zone_keys,
    link_count,
    tostring(settings.get_saved_games_root(settings_data) or "?")
  ))

  return confini, path, status
end

function M.file_exists(mission_id, settings_data)
  local path = M.graph_path(mission_id, settings_data)
  if not path then return false end
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

function M.save(graph, mission_id, settings_data)
  if not graph then return false, "invalid graph" end
  settings_data = settings_data or settings.load()
  if not _ensure_dir(settings_data) then return false, "storage directory unavailable" end

  local path = M.graph_path(mission_id, settings_data)
  if not path then return false, "invalid storage path" end

  local confini = require("dcore_zone_linker.graph").to_confini(graph)
  local payload = {
    "{\n",
    '  "mission": ' .. _encode_string(mission_id or M.mission_id()) .. ",\n",
    '  "updated_utc": ' .. _encode_string(os.date("!%Y-%m-%dT%H:%M:%SZ")) .. ",\n",
    '  "confini": ' .. _encode_confini(confini):gsub("\n", "\n  ") .. "\n",
    "}",
  }

  local f, err = io.open(path, "w")
  if not f then
    return false, tostring(err)
  end
  f:write(table.concat(payload))
  f:close()

  graph.dirty = false
  util.info("graph saved: " .. path)
  return true
end

return M
