--------------------------------------------------------------------------------------------------------------------------------
-- zone_list.lua - Enumerazione trigger zone dalla missione corrente
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")

local M = {}

local function zone_name(zone)
  if type(zone) ~= "table" then return nil end
  if type(zone.name) == "string" and zone.name ~= "" then return zone.name end
  if type(zone.zoneId) == "number" then return "zone_" .. tostring(zone.zoneId) end
  return nil
end

local function _basename_from_path(path)
  if type(path) ~= "string" or path == "" then return nil end
  local normalized = path:gsub("\\", "/")
  local base = normalized:match("([^/]+)$")
  if not base or base == "" then return nil end
  return base:match("^(.+)%.[^%.]+$") or base
end

function M.get_mission_name()
  local ok, mission = pcall(function()
    local me = require("me_mission")
    return me and me.mission
  end)
  if not ok or type(mission) ~= "table" then return "unknown_mission" end

  if type(mission.name) == "string" and mission.name ~= "" then
    return mission.name
  end

  local from_path = _basename_from_path(mission.path)
  if from_path and from_path ~= "" then
    return from_path
  end

  return "unknown_mission"
end

function M.get_all_zones()
  local zones = {}
  local seen = {}

  local ok, err = pcall(function()
    local me = require("me_mission")
    local mission = me and me.mission
    local list = mission and mission.triggers and mission.triggers.zones
    if type(list) ~= "table" then return end

    for _, z in ipairs(list) do
      local name = zone_name(z)
      if name and not seen[name] then
        seen[name] = true
        zones[#zones + 1] = {
          name = name,
          x = tonumber(z.x) or 0,
          y = tonumber(z.y) or 0,
          radius = tonumber(z.radius) or 0,
          raw = z,
        }
      elseif name and seen[name] then
        util.warn("duplicate zone in mission: " .. name)
      end
    end
  end)

  if not ok then
    util.error("get_all_zones failed: " .. tostring(err))
  end

  table.sort(zones, function(a, b) return a.name < b.name end)
  return zones
end

function M.filter_zones(zones, zone_prefix, show_all)
  if show_all then return zones end
  local prefix = zone_prefix or "zone_"
  local out = {}
  for _, z in ipairs(zones or {}) do
    if z.name:sub(1, #prefix) == prefix then
      out[#out + 1] = z
    end
  end
  return out
end

function M.zone_names(zones)
  local names = {}
  for _, z in ipairs(zones or {}) do
    names[#names + 1] = z.name
  end
  return names
end

function M.validate_graph_zones(confini, mission_zones)
  local mission_set = {}
  for _, z in ipairs(mission_zones or {}) do
    mission_set[z.name] = true
  end

  local warnings = {}
  for zn, neighbors in pairs(confini or {}) do
    if not mission_set[zn] then
      warnings[#warnings + 1] = "zone in graph but missing from mission: " .. zn
    end
    for _, nn in ipairs(neighbors or {}) do
      if not mission_set[nn] then
        warnings[#warnings + 1] = "link to missing zone: " .. zn .. " -> " .. nn
      end
    end
  end

  return warnings
end

return M
