--------------------------------------------------------------------------------------------------------------------------------
-- map_pick.lua - Click sulla mappa con zona più vicina (me_map_window state)
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")
local zone_list = require("dcore_zone_linker.zone_list")

local M = {}

local _active = false
local _phase = nil
local _on_click = nil
local _zones = {}

local function _forward(pan_state, method, ...)
  if not pan_state then return end
  local fn = pan_state[method]
  if type(fn) == "function" then
    pcall(fn, pan_state, ...)
  end
end

function M.find_nearest_zone_name(wx, wy, zones)
  if not wx or not wy or not zones or #zones == 0 then
    return nil
  end

  local best_name = nil
  local best_score = math.huge

  for _, z in ipairs(zones) do
    local dx = (z.x or 0) - wx
    local dy = (z.y or 0) - wy
    local dist = math.sqrt(dx * dx + dy * dy)
    local radius = tonumber(z.radius) or 0
    local score = dist
    if radius > 0 and dist <= radius then
      score = dist - radius * 2
    end
    if score < best_score then
      best_score = score
      best_name = z.name
    end
  end

  return best_name
end

function M.is_active()
  return _active
end

function M.get_phase()
  return _phase
end

function M.stop()
  if not _active then return end
  _active = false
  _phase = nil
  _on_click = nil

  pcall(function()
    local MapWindow = require("me_map_window")
    if MapWindow and MapWindow.setState and MapWindow.getPanState then
      MapWindow.setState(MapWindow.getPanState())
    end
  end)

  util.info("map pick stopped")
end

function M.start(opts)
  opts = opts or {}
  _on_click = opts.on_click
  _phase = opts.phase or "base"
  _zones = opts.zones or zone_list.get_all_zones()

  local ok, err = pcall(function()
    local MapWindow = require("me_map_window")
    if not (MapWindow and MapWindow.setState and MapWindow.getPanState and MapWindow.getMapPoint) then
      error("me_map_window not available")
    end

    local pan_state = MapWindow.getPanState()
    local pick_state = {}

    function pick_state:onMouseDown(x, y, button)
      if button ~= 1 then
        _forward(pan_state, "onMouseDown", x, y, button)
        return
      end

      local wx, wy = MapWindow.getMapPoint(x, y)
      if not (wx and wy) then return end

      local zone_name = M.find_nearest_zone_name(wx, wy, _zones)
      if not zone_name then return end

      if type(_on_click) == "function" then
        pcall(_on_click, zone_name, wx, wy, _phase)
      end
    end

    function pick_state:onMouseUp(x, y, button)
      if button ~= 1 then
        _forward(pan_state, "onMouseUp", x, y, button)
      end
    end

    function pick_state:onMouseDrag(dx, dy, button, x, y)
      if button ~= 1 then
        _forward(pan_state, "onMouseDrag", dx, dy, button, x, y)
      end
    end

    function pick_state:onMouseMove(x, y)
      _forward(pan_state, "onMouseMove", x, y)
    end

    function pick_state:onMouseWheel(x, y, clicks)
      _forward(pan_state, "onMouseWheel", x, y, clicks)
    end

    MapWindow.setState(pick_state)
  end)

  if not ok then
    util.error("map pick start failed: " .. tostring(err))
    return false, tostring(err)
  end

  _active = true
  util.info("map pick started phase=" .. tostring(_phase))
  return true
end

function M.set_phase(phase)
  _phase = phase
end

function M.refresh_zones(zones)
  _zones = zones or _zones
end

return M
