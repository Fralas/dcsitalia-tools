--------------------------------------------------------------------------------------------------------------------------------
-- map_overlay.lua - Linee collegamento come user objects sulla mappa ME (non layer Draw)
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")
local graph_mod = require("dcore_zone_linker.graph")

local M = {}

local LINE_CLASS = "TriggerZoneSelectionPolyline"
local LINE_COLOR = { 1, 1, 1, 1 }
local LINE_THICKNESS = 8
local LINE_Z_ORDER = 6
local ID_START = -910000

local _enabled = false
local _line_objects = {}
local _next_id = ID_START
local _graph = nil
local _zones = {}

local function _map_window()
  local ok, mw = pcall(require, "me_map_window")
  if ok then return mw end
  return nil
end

local function _zone_lookup(zones)
  local out = {}
  for _, z in ipairs(zones or {}) do
    out[z.name] = z
  end
  return out
end

local function _border_endpoints(c1, r1, c2, r2)
  local dx = c2.x - c1.x
  local dy = c2.y - c1.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then
    return { x = c1.x, y = c1.y }, { x = c2.x, y = c2.y }
  end
  local ux, uy = dx / dist, dy / dist
  local p1 = { x = c1.x + ux * (r1 or 0), y = c1.y + uy * (r1 or 0) }
  local p2 = { x = c2.x - ux * (r2 or 0), y = c2.y - uy * (r2 or 0) }
  return p1, p2
end

local function _clear_lines()
  local mw = _map_window()
  if mw and #_line_objects > 0 then
    pcall(function() mw.removeUserObjects(_line_objects) end)
  end
  _line_objects = {}
end

local function _build_segments(graph, zones)
  local confini = graph_mod.to_confini(graph)
  local lookup = _zone_lookup(zones)
  local segments = {}
  local seen = {}

  for zn, neighbors in pairs(confini) do
    local z1 = lookup[zn]
    if z1 then
      for _, nn in ipairs(neighbors) do
        local key = zn < nn and (zn .. "|" .. nn) or (nn .. "|" .. zn)
        if not seen[key] then
          seen[key] = true
          local z2 = lookup[nn]
          if z2 then
            local p1, p2 = _border_endpoints(
              { x = z1.x, y = z1.y }, z1.radius,
              { x = z2.x, y = z2.y }, z2.radius
            )
            segments[#segments + 1] = { p1, p2 }
          end
        end
      end
    end
  end

  return segments
end

local function _create_line_object(mw, p1, p2, id)
  local points = {
    mw.createPoint(p1.x, p1.y),
    mw.createPoint(p2.x, p2.y),
  }

  local line
  if mw.createPLN then
    line = mw.createPLN(LINE_CLASS, id, points, LINE_COLOR, LINE_Z_ORDER)
  else
    line = mw.createLIN(LINE_CLASS, id, points, LINE_COLOR, LINE_Z_ORDER)
  end

  line.currColor = LINE_COLOR
  line.thickness = LINE_THICKNESS
  return line
end

function M.is_enabled()
  return _enabled
end

function M.apply(enabled, graph, zones)
  _enabled = enabled == true
  _graph = graph
  _zones = zones or _zones

  if not _enabled then
    M.clear()
    return
  end

  M.refresh(graph, zones)
end

function M.set_enabled(enabled)
  M.apply(enabled, _graph, _zones)
end

function M.clear()
  _clear_lines()
end

function M.refresh(graph, zones)
  _graph = graph
  _zones = zones or _zones

  _clear_lines()
  if not _enabled or not graph then return end

  local mw = _map_window()
  if not (mw and mw.createPoint and mw.addUserObjects and (mw.createPLN or mw.createLIN)) then
    util.warn("map overlay: me_map_window not available")
    return
  end

  local segments = _build_segments(graph, _zones)
  for _, seg in ipairs(segments) do
    _next_id = _next_id - 1
    _line_objects[#_line_objects + 1] = _create_line_object(mw, seg[1], seg[2], _next_id)
  end

  if #_line_objects > 0 then
    pcall(function() mw.addUserObjects(_line_objects) end)
    util.info("map overlay: " .. #_line_objects .. " lines")
  end
end

return M
