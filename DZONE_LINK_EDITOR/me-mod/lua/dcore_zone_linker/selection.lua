--------------------------------------------------------------------------------------------------------------------------------
-- selection.lua - Lettura selezione zona dal Mission Editor
--------------------------------------------------------------------------------------------------------------------------------

local M = {}

local function safe_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then return result end
  return nil
end

local function zone_name(zone)
  if type(zone) ~= "table" then return nil end
  if type(zone.name) == "string" and zone.name ~= "" then return zone.name end
  if type(zone.zoneId) == "number" then return "zone_" .. tostring(zone.zoneId) end
  return nil
end

local function collect_single_zone()
  local MapController = safe_call(require, "Mission.MapController")
  local MissionData = safe_call(require, "Mission.Data")
  local TriggerZoneController = safe_call(require, "Mission.TriggerZoneController")
  if not MapController or not MissionData or not TriggerZoneController then
    return nil
  end

  local objectId = safe_call(MapController.getSelectedObjectId, MapController)
  if not objectId then return nil end

  local zoneType = safe_call(MissionData.triggerZoneType, MissionData)
  local kind = safe_call(MissionData.getObjectType, MissionData, objectId)
  if kind ~= zoneType then return nil end

  local zone = safe_call(TriggerZoneController.getTriggerZone, TriggerZoneController, objectId)
  if not zone then return nil end

  return zone_name(zone), zone
end

local function collect_multi_zones()
  local multiSelection = safe_call(require, "me_multiSelection")
  if not multiSelection or not multiSelection.isVisible or not multiSelection.getSelectedObjects then
    return nil
  end
  if not safe_call(multiSelection.isVisible, multiSelection) then
    return nil
  end

  local objects = safe_call(multiSelection.getSelectedObjects, multiSelection)
  if type(objects) ~= "table" or type(objects.selectTriggerZones) ~= "table" then
    return nil
  end

  local names = {}
  for _, zone in pairs(objects.selectTriggerZones) do
    local name = zone_name(zone)
    if name then names[#names + 1] = name end
  end

  if #names == 0 then return nil end
  table.sort(names)
  return names[1], objects.selectTriggerZones
end

function M.get_selected_zone_name()
  local ok, name = pcall(function()
    local multi_name = collect_multi_zones()
    if multi_name then return multi_name end
    return collect_single_zone()
  end)

  if ok then return name end
  return nil
end

function M.snapshot()
  local snap = {
    ok = false,
    zone_name = nil,
    error = nil,
  }

  local ok, result = pcall(function()
    snap.zone_name = M.get_selected_zone_name()
    snap.ok = snap.zone_name ~= nil
    if not snap.ok then
      snap.error = "No trigger zone selected on the map"
    end
    return snap
  end)

  if not ok then
    snap.error = tostring(result)
  end

  return snap
end

return M
