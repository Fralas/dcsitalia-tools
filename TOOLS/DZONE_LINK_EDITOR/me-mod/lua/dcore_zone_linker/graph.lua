--------------------------------------------------------------------------------------------------------------------------------
-- graph.lua - Modello confini con collegamenti bidirezionali
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")

local M = {}

local function _sorted_unique(list)
  local seen = {}
  local out = {}
  for _, v in ipairs(list or {}) do
    if type(v) == "string" and v ~= "" and not seen[v] then
      seen[v] = true
      out[#out + 1] = v
    end
  end
  table.sort(out)
  return out
end

local function _remove_from(list, value)
  local out = {}
  for _, v in ipairs(list or {}) do
    if v ~= value then out[#out + 1] = v end
  end
  return out
end

local function _prune_empty(confini)
  for zn, neighbors in pairs(confini) do
    if type(neighbors) ~= "table" or #neighbors == 0 then
      confini[zn] = nil
    end
  end
end

function M.new(confini)
  local g = {
    confini = {},
    dirty = false,
  }

  if type(confini) == "table" then
    for zn, neighbors in pairs(confini) do
      if type(zn) == "string" and type(neighbors) == "table" then
        g.confini[zn] = _sorted_unique(neighbors)
      end
    end
  end

  return g
end

function M.ensure_zone(g, zone_name)
  if not g or type(zone_name) ~= "string" or zone_name == "" then return end
  if g.confini[zone_name] == nil then
    g.confini[zone_name] = {}
  end
end

function M.get_links(g, zone_name)
  if not g or not zone_name then return {} end
  return _sorted_unique(g.confini[zone_name] or {})
end

function M.has_link(g, a, b)
  if not g or not a or not b then return false end
  for _, nn in ipairs(g.confini[a] or {}) do
    if nn == b then return true end
  end
  return false
end

function M.link(g, a, b)
  if not g or type(a) ~= "string" or type(b) ~= "string" then
    return false, "invalid zone names"
  end
  if a == b then
    return false, "cannot link a zone to itself"
  end

  M.ensure_zone(g, a)
  M.ensure_zone(g, b)

  if M.has_link(g, a, b) then
    return true, "already linked"
  end

  g.confini[a] = _sorted_unique((function()
    local t = util.table_copy_shallow(g.confini[a])
    t[#t + 1] = b
    return t
  end)())

  g.confini[b] = _sorted_unique((function()
    local t = util.table_copy_shallow(g.confini[b])
    t[#t + 1] = a
    return t
  end)())

  g.dirty = true
  return true
end

function M.unlink(g, a, b)
  if not g or type(a) ~= "string" or type(b) ~= "string" then
    return false, "invalid zone names"
  end

  g.confini[a] = _remove_from(g.confini[a], b)
  g.confini[b] = _remove_from(g.confini[b], a)
  _prune_empty(g.confini)
  g.dirty = true
  return true
end

function M.remove_zone(g, zone_name)
  if not g or type(zone_name) ~= "string" or zone_name == "" then
    return false, "invalid zone name"
  end

  local neighbors = _sorted_unique(g.confini[zone_name] or {})
  for _, nn in ipairs(neighbors) do
    if g.confini[nn] then
      g.confini[nn] = _remove_from(g.confini[nn], zone_name)
    end
  end

  g.confini[zone_name] = nil
  _prune_empty(g.confini)
  g.dirty = true
  return true
end

function M.to_confini(g)
  local out = {}
  if not g then return out end
  for zn, neighbors in pairs(g.confini or {}) do
    local list = _sorted_unique(neighbors)
    if #list > 0 then
      out[zn] = list
    end
  end
  return out
end

function M.normalize_symmetry(g)
  if not g then return end
  for zn, neighbors in pairs(g.confini or {}) do
    for _, nn in ipairs(neighbors or {}) do
      if zn ~= nn then
        M.ensure_zone(g, zn)
        M.ensure_zone(g, nn)
        if not M.has_link(g, zn, nn) then
          g.confini[zn] = _sorted_unique((function()
            local t = util.table_copy_shallow(g.confini[zn])
            t[#t + 1] = nn
            return t
          end)())
          g.confini[nn] = _sorted_unique((function()
            local t = util.table_copy_shallow(g.confini[nn])
            t[#t + 1] = zn
            return t
          end)())
        end
      end
    end
  end
  _prune_empty(g.confini)
end

function M.link_count(g)
  local seen = {}
  local n = 0
  for zn, neighbors in pairs(g and g.confini or {}) do
    for _, nn in ipairs(neighbors) do
      local key = zn < nn and (zn .. "|" .. nn) or (nn .. "|" .. zn)
      if not seen[key] then
        seen[key] = true
        n = n + 1
      end
    end
  end
  return n
end

function M.zone_count(g)
  local n = 0
  for _ in pairs(g and g.confini or {}) do n = n + 1 end
  return n
end

return M
