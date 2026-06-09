--------------------------------------------------------------------------------------------------------------------------------
-- DZONE_TEST.lua - Tool standalone per verificare collegamenti tra zone DMAP
--------------------------------------------------------------------------------------------------------------------------------
-- Carica MOOSE prima di questo script.
-- Nel Mission Editor aggiungi una DO SCRIPT FILE che punta a questo file.
--
-- Configura i collegamenti in DZONE_TEST_Config.lua (tabella confini).
-- Il tool disegna su F10 cerchi e linee con lo stesso stile del DMAP e segnala
-- zone mancanti o collegamenti non simmetrici nel log missione.

local LOG_PREFIX = "[DZONE_TEST] "

local function _log(msg)
  env.info(LOG_PREFIX .. tostring(msg))
end

local function _scriptDir()
  local info = debug and debug.getinfo and debug.getinfo(1, "S")
  local src = info and info.source or nil
  if type(src) == "string" and src:sub(1, 1) == "@" then
    local full = src:sub(2):gsub("/", "\\")
    return full:match("^(.*)\\[^\\]+$")
  end
  return nil
end

local function _fileExists(path)
  local f = io and io.open(path, "r") or nil
  if f then
    f:close()
    return true
  end
  return false
end

local function _resolveConfigPath()
  if type(_G.DZONE_TEST_BASE_PATH) == "string" and _G.DZONE_TEST_BASE_PATH ~= "" then
    local p = _G.DZONE_TEST_BASE_PATH .. "\\DZONE_TEST_Config.lua"
    if _fileExists(p) then return p end
  end

  local dir = _scriptDir()
  if dir and dir ~= "" then
    local p0 = dir .. "\\DZONE_TEST_Config.lua"
    if _fileExists(p0) then return p0 end
  end

  local p1 = "src\\TOOLS\\DZONE_TEST\\DZONE_TEST_Config.lua"
  if _fileExists(p1) then return p1 end

  return p1
end

local function _loadConfig()
  if type(_G.DZONE_TEST_CONFIG) == "table" then
    return _G.DZONE_TEST_CONFIG
  end

  local cfgPath = _resolveConfigPath()
  local ok, mod = pcall(dofile, cfgPath)
  if ok and type(mod) == "table" then
    _G.DZONE_TEST_CONFIG = mod
    return mod
  end

  _log("ERRORE caricamento config da " .. tostring(cfgPath) .. " | " .. tostring(mod))
  return nil
end

local function _nextMarkID(state)
  if type(UTILS) == "table" and type(UTILS.GetMarkID) == "function" then
    return UTILS.GetMarkID()
  end
  state.mark_seq = (state.mark_seq or 30000) + 1
  return state.mark_seq
end

local function _removeMark(id)
  if id then trigger.action.removeMark(id) end
end

local function _lineKey(a, b)
  if a < b then return a .. "|" .. b end
  return b .. "|" .. a
end

local function _borderEndpoints(c1, r1, c2, r2)
  if not c1 or not c2 then return nil, nil end
  local dx = c2.x - c1.x
  local dy = c2.y - c1.y
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist <= 1e-6 then
    return nil, nil
  end
  local ux = dx / dist
  local uy = dy / dist
  local p1 = { x = c1.x + ux * (r1 or 0), y = c1.y + uy * (r1 or 0) }
  local p2 = { x = c2.x - ux * (r2 or 0), y = c2.y - uy * (r2 or 0) }
  return p1, p2
end

local function _collectZoneNames(confini)
  local names = {}
  for zn, neighbors in pairs(confini or {}) do
    names[zn] = true
    for _, nn in ipairs(neighbors or {}) do
      names[nn] = true
    end
  end
  return names
end

local function _validateGraph(confini)
  local issues = {}
  local zoneNames = _collectZoneNames(confini)

  if next(zoneNames) == nil then
    issues[#issues + 1] = "confini vuoto: aggiungi i collegamenti in DZONE_TEST_Config.lua"
    return issues, zoneNames
  end

  for zn, neighbors in pairs(confini) do
    for _, nn in ipairs(neighbors or {}) do
      if confini[nn] == nil then
        issues[#issues + 1] = "destinazione non definita in confini: " .. zn .. " -> " .. nn
      end

      local reverse = confini[nn]
      local found = false
      if type(reverse) == "table" then
        for _, back in ipairs(reverse) do
          if back == zn then
            found = true
            break
          end
        end
      end
      if not found then
        issues[#issues + 1] = "collegamento non simmetrico: " .. zn .. " -> " .. nn .. " (manca " .. nn .. " -> " .. zn .. ")"
      end
    end
  end

  return issues, zoneNames
end

local function _linkHasIssue(confini, zn, nn, zones)
  if not zones[zn] or not zones[nn] then
    return true
  end
  if confini[nn] == nil then
    return true
  end
  for _, back in ipairs(confini[nn] or {}) do
    if back == zn then
      return false
    end
  end
  return true
end

local function _resolveZones(zoneNames)
  local zones = {}
  local missing = {}

  for zn in pairs(zoneNames) do
    local zObj = ZONE and ZONE.FindByName and ZONE:FindByName(zn) or nil
    if zObj then
      zones[zn] = { zoneObj = zObj, markID = nil, labelID = nil }
    else
      missing[#missing + 1] = zn
    end
  end

  table.sort(missing)
  return zones, missing
end

local function _drawCircle(cfg, state, zoneObj, colorRGB, lineAlpha, fillAlpha)
  local coord = zoneObj:GetCoordinate()
  local vec3 = coord:GetVec3()
  local radius = 1000
  if zoneObj.GetRadius then
    radius = zoneObj:GetRadius()
  end

  local lineColor = { colorRGB[1], colorRGB[2], colorRGB[3], lineAlpha or 1.0 }
  local fillColor = { colorRGB[1], colorRGB[2], colorRGB[3], fillAlpha or cfg.ZONE_FILL_ALPHA }

  local markID = _nextMarkID(state)
  trigger.action.circleToAll(
    -1,
    markID,
    vec3,
    radius,
    lineColor,
    fillColor,
    cfg.ZONE_LINE_TYPE,
    false,
    ""
  )

  return markID
end

local function _drawZoneLabel(cfg, zoneObj, text)
  if not zoneObj then return nil end

  local center = zoneObj:GetVec2()
  if not center then return nil end

  local shifted = {
    x = center.x + cfg.LABEL_OFFSET_X_M,
    y = center.y + cfg.LABEL_OFFSET_Y_M,
  }

  local coord = COORDINATE:NewFromVec2(shifted)
  if not coord or not coord.TextToAll then return nil end

  return coord:TextToAll(
    text,
    -1,
    cfg.LABEL_TEXT_COLOR,
    cfg.LABEL_TEXT_ALPHA,
    cfg.LABEL_BG_COLOR,
    cfg.LABEL_BG_ALPHA,
    cfg.LABEL_FONT_SIZE
  )
end

local function _clearDraw(state)
  for _, d in pairs(state.zones or {}) do
    _removeMark(d.markID)
    _removeMark(d.labelID)
    d.markID = nil
    d.labelID = nil
  end

  for _, pl in pairs(state.lines or {}) do
    if pl and pl.UnDrawLine then
      pl:UnDrawLine(0)
    end
  end
  state.lines = {}
end

local function _drawAll(cfg, state, graphIssues)
  if not ZONE or not COORDINATE then
    _log("MOOSE non disponibile: carica Moose.lua prima di DZONE_TEST.lua")
    return
  end

  local confini = cfg.confini or {}
  local graphIssuesLocal, zoneNames = _validateGraph(confini)
  for _, issue in ipairs(graphIssuesLocal) do
    graphIssues[#graphIssues + 1] = issue
  end

  local zones, missing = _resolveZones(zoneNames)
  state.zones = zones

  for _, zn in ipairs(missing) do
    graphIssues[#graphIssues + 1] = "zona non trovata in missione: " .. zn
  end

  _clearDraw(state)

  for zn, d in pairs(zones) do
    local labelText = " " .. zn .. " "
    d.labelID = _drawZoneLabel(cfg, d.zoneObj, labelText)
    d.markID = _drawCircle(cfg, state, d.zoneObj, cfg.COLOR_ZONE, 1.0, cfg.ZONE_FILL_ALPHA)
  end

  if not PATHLINE or not PATHLINE.NewFromVec2Array then
    _log("PATHLINE non disponibile: cerchi OK, linee disabilitate.")
    return
  end

  local drawn = {}
  for zn, neighbors in pairs(confini) do
    local z1 = zones[zn] and zones[zn].zoneObj or nil
    for _, nn in ipairs(neighbors or {}) do
      local key = _lineKey(zn, nn)
      if not drawn[key] then
        drawn[key] = true

        local z2 = zones[nn] and zones[nn].zoneObj or nil
        local hasError = _linkHasIssue(confini, zn, nn, zones)

        if z1 and z2 then
          local c1 = z1:GetCoordinate():GetVec2()
          local c2 = z2:GetCoordinate():GetVec2()
          local r1 = (z1.GetRadius and z1:GetRadius()) or 0
          local r2 = (z2.GetRadius and z2:GetRadius()) or 0
          local p1, p2 = _borderEndpoints(c1, r1, c2, r2)
          if p1 and p2 then
            local col = hasError and cfg.COLOR_LINK_ERROR or cfg.COLOR_LINK
            local line = PATHLINE:NewFromVec2Array("DZT_" .. key, { p1, p2 })
            line:DrawLine(-1, { col[1], col[2], col[3], 1.0 }, cfg.ZONE_LINE_TYPE)
            state.lines[key] = line
          end
        end
      end
    end
  end
end

local function _report(issues, zoneCount, linkCount)
  if #issues == 0 then
    _log(string.format("OK - %d zone, %d collegamenti disegnati. Grafo coerente.", zoneCount, linkCount))
    return
  end

  _log(string.format("ATTENZIONE - %d problemi trovati (%d zone, %d collegamenti disegnati):", #issues, zoneCount, linkCount))
  for i, issue in ipairs(issues) do
    _log(string.format("  %d) %s", i, issue))
  end
end

local function _countLinks(confini)
  local seen = {}
  local n = 0
  for zn, neighbors in pairs(confini or {}) do
    for _, nn in ipairs(neighbors or {}) do
      local key = _lineKey(zn, nn)
      if not seen[key] then
        seen[key] = true
        n = n + 1
      end
    end
  end
  return n
end

local function _tick()
  local cfg = _G.DZONE_TEST_CONFIG
  local state = _G.DZONE_TEST_STATE
  if not cfg or not state then return end

  local issues = {}
  _drawAll(cfg, state, issues)
  _report(issues, _tableSize(state.zones), _countLinks(cfg.confini))
end

local function _tableSize(t)
  local n = 0
  for _ in pairs(t or {}) do n = n + 1 end
  return n
end

local function InitDZoneTest()
  local cfg = _loadConfig()
  if not cfg then return end

  if type(cfg.confini) ~= "table" then
    _log("Config non valida: manca confini")
    return
  end

  _G.DZONE_TEST_CONFIG = cfg
  _G.DZONE_TEST_STATE = {
    zones = {},
    lines = {},
    mark_seq = 30000,
  }

  _log("Avvio tool validazione collegamenti zone")

  local delay = tonumber(cfg.START_DELAY_SEC) or 5
  local redraw = tonumber(cfg.REDRAW_SEC) or 60

  SCHEDULER:New(nil, _tick, {}, delay, redraw)

  _G.DZoneTestRedraw = function()
    _tick()
  end
end

InitDZoneTest()
