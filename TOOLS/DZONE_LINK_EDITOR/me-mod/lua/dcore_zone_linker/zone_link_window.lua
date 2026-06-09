--------------------------------------------------------------------------------------------------------------------------------
-- zone_link_window.lua - UI semplificata Zone Link Editor
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")
local settings = require("dcore_zone_linker.settings")
local zone_list = require("dcore_zone_linker.zone_list")
local graph_mod = require("dcore_zone_linker.graph")
local persistence = require("dcore_zone_linker.persistence")
local config_export = require("dcore_zone_linker.config_export")
local map_pick = require("dcore_zone_linker.map_pick")
local map_overlay = require("dcore_zone_linker.map_overlay")
local config_window = require("dcore_zone_linker.config_window")

local M = {}

local Window, Static, Button, Skin, Gui, UpdateManager

do
  local ok, mod = pcall(require, "Window"); if ok then Window = mod end
  local ok2, mod2 = pcall(require, "Static"); if ok2 then Static = mod2 end
  local ok3, mod3 = pcall(require, "Button"); if ok3 then Button = mod3 end
  local ok4, mod4 = pcall(require, "Skin"); if ok4 then Skin = mod4 end
  local ok5, mod5 = pcall(require, "dxgui"); if ok5 then Gui = mod5 end
  local ok6, mod6 = pcall(require, "UpdateManager"); if ok6 then UpdateManager = mod6 end
end

local HISTORY_MAX = 5

local W = {
  visible = false,
  window = nil,
  graph = nil,
  settings = nil,
  mission_id = nil,
  base_zone = nil,
  zones = {},
  pick_active = false,
  assoc_history = {},
  widgets = {},
  tick_installed = false,
}

local WIN_W = 440
local WIN_H = 400

local function try_skin(widget, skin_name)
  pcall(function()
    if widget and widget.setSkin and Skin and Skin[skin_name] then
      widget:setSkin(Skin[skin_name]())
    end
  end)
end

local function default_position()
  local screen_w = 1920
  pcall(function()
    if Gui and Gui.GetWindowSize then
      local sw = Gui.GetWindowSize()
      if type(sw) == "number" and sw > 0 then screen_w = sw end
    end
  end)
  return math.max(20, screen_w - WIN_W - 20), 80
end

local function set_label(widget, text)
  if widget and widget.setText then
    pcall(function() widget:setText(tostring(text)) end)
  end
end

local function ensure_window_visible()
  if not W.window or not W.visible then return end
  pcall(function()
    if W.window.setVisible then W.window:setVisible(true) end
    if W.window.setEnabled then W.window:setEnabled(true) end
    if W.window.setZOrder then W.window:setZOrder(10000) end
  end)
end

local function install_keepalive()
  if W.tick_installed or not UpdateManager or not UpdateManager.add then return end
  W.tick_installed = true
  pcall(function()
    UpdateManager.add(function()
      if W.visible then
        ensure_window_visible()
      end
    end)
  end)
end

local function _encode_links_json(links)
  local parts = {}
  for _, nn in ipairs(links or {}) do
    parts[#parts + 1] = string.format("%q", nn)
  end
  return "[" .. table.concat(parts, ", ") .. "]"
end

local function _assoc_json_line(base, links)
  return '{ "' .. tostring(base) .. '": ' .. _encode_links_json(links) .. " }"
end

local function push_assoc_history(base, links)
  if type(base) ~= "string" or base == "" then return end
  if type(links) ~= "table" or #links == 0 then return end

  local entry = {
    base = base,
    links = util.table_copy_shallow(links),
  }

  if #W.assoc_history > 0 and W.assoc_history[1].base == base then
    W.assoc_history[1] = entry
  else
    table.insert(W.assoc_history, 1, entry)
  end

  while #W.assoc_history > HISTORY_MAX do
    table.remove(W.assoc_history)
  end
end

local function finalize_current_assoc()
  if not W.base_zone or not W.graph then return end
  local links = graph_mod.get_links(W.graph, W.base_zone)
  push_assoc_history(W.base_zone, links)
end

local function refresh_live_panel()
  if not W.base_zone then
    set_label(W.widgets.base_label, "Base zone: (none)")
    set_label(W.widgets.links_label, "Linked: (none)")
    return
  end

  local links = graph_mod.get_links(W.graph, W.base_zone)
  set_label(W.widgets.base_label, "Base zone: " .. W.base_zone)

  if #links == 0 then
    set_label(W.widgets.links_label, "Linked: (none)")
  else
    set_label(W.widgets.links_label, "Linked: " .. table.concat(links, ", "))
  end
end

local function refresh_history_json()
  local lines = { "JSON last " .. HISTORY_MAX .. " associations:" }

  if #W.assoc_history == 0 then
    lines[#lines + 1] = "  (none)"
  else
    for i = 1, math.min(HISTORY_MAX, #W.assoc_history) do
      local e = W.assoc_history[i]
      lines[#lines + 1] = string.format("  [%d] %s", i, _assoc_json_line(e.base, e.links))
    end
  end

  set_label(W.widgets.history_label, table.concat(lines, "\n"))
end

local function refresh_status()
  local total = W.graph and graph_mod.link_count(W.graph) or 0
  if W.pick_active and not W.base_zone then
    set_label(W.widgets.status, "Click the BASE zone (right-drag = pan)")
  elseif W.pick_active and W.base_zone then
    set_label(W.widgets.status, "Click zones to link | " .. total .. " total links")
  else
    set_label(W.widgets.status, total .. " links in mission — Create link to start")
  end
  refresh_live_panel()
  refresh_history_json()
end

local function refresh_zones()
  W.zones = zone_list.filter_zones(
    zone_list.get_all_zones(),
    W.settings.zone_prefix,
    W.settings.show_all_zones == true
  )
  map_pick.refresh_zones(W.zones)
end

local function update_overlay_button_text()
  if not W.widgets.overlay_btn or not W.widgets.overlay_btn.setText then return end
  local text = map_overlay.is_enabled() and "Hide links" or "Show links"
  pcall(function() W.widgets.overlay_btn:setText(text) end)
end

local function refresh_link_overlay()
  map_overlay.apply(
    map_overlay.is_enabled(),
    W.graph,
    W.zones
  )
end

local function apply_overlay_setting()
  local enabled = W.settings and W.settings.show_link_overlay == true
  map_overlay.apply(enabled, W.graph, W.zones)
  update_overlay_button_text()
end

local function rebuild_history_from_graph(g)
  local out = {}
  local confini = graph_mod.to_confini(g)
  local keys = util.sorted_keys(confini)
  local start = math.max(1, #keys - HISTORY_MAX + 1)
  for i = start, #keys do
    local base = keys[i]
    table.insert(out, 1, {
      base = base,
      links = util.table_copy_shallow(confini[base]),
    })
  end
  return out
end

local function reload_graph_from_disk(opts)
  opts = opts or {}
  local preserve_base = opts.preserve_base == true
  local prev_base = preserve_base and W.base_zone or nil

  W.mission_id = persistence.mission_id()
  W.settings = settings.load()

  local confini, path, status = persistence.load_fresh(W.mission_id, W.settings)
  if type(confini) ~= "table" then
    confini = {}
  end

  W.graph = graph_mod.new(confini)
  W.graph.dirty = false
  W.assoc_history = rebuild_history_from_graph(W.graph)

  if preserve_base and prev_base then
    W.base_zone = prev_base
    if W.graph.confini[prev_base] == nil then
      graph_mod.ensure_zone(W.graph, prev_base)
    end
  else
    W.base_zone = nil
  end

  refresh_zones()
  refresh_link_overlay()
  local total = graph_mod.link_count(W.graph)
  util.info(string.format(
    "graph reloaded: path=%s status=%s links=%d",
    tostring(path or "(missing)"),
    tostring(status or "?"),
    total
  ))
end

local function stop_pick()
  reload_graph_from_disk({ preserve_base = false })
  W.pick_active = false
  W.base_zone = nil
  map_pick.stop()
  if W.widgets.crea_btn and W.widgets.crea_btn.setText then
    pcall(function() W.widgets.crea_btn:setText("Create link") end)
  end
  refresh_status()
end

local function on_map_click(zone_name)
  if not W.pick_active or not zone_name then return end

  reload_graph_from_disk({ preserve_base = true })

  if not W.base_zone then
    W.base_zone = zone_name
    graph_mod.ensure_zone(W.graph, W.base_zone)
    map_pick.set_phase("target")
    refresh_status()
    return
  end

  if zone_name == W.base_zone then
    set_label(W.widgets.status, "Select a zone other than the base")
    return
  end

  local ok, msg = graph_mod.link(W.graph, W.base_zone, zone_name)
  if ok then
    push_assoc_history(W.base_zone, graph_mod.get_links(W.graph, W.base_zone))
    persistence.save(W.graph, W.mission_id, W.settings)
    refresh_link_overlay()
    refresh_status()
  else
    set_label(W.widgets.status, msg or "Link failed")
  end

  ensure_window_visible()
end

local function on_crea_link()
  if W.pick_active then
    stop_pick()
    reload_graph_from_disk({ preserve_base = false })
    refresh_status()
    set_label(W.widgets.status, "Link mode cancelled")
    return
  end

  reload_graph_from_disk({ preserve_base = false })
  if #W.zones == 0 then
    set_label(W.widgets.status, "No trigger zones (prefix " .. W.settings.zone_prefix .. ")")
    return
  end

  W.pick_active = true
  W.base_zone = nil

  local ok, err = map_pick.start({
    phase = "base",
    zones = W.zones,
    on_click = on_map_click,
  })

  if not ok then
    W.pick_active = false
    set_label(W.widgets.status, "Map error: " .. tostring(err))
    return
  end

  if W.widgets.crea_btn and W.widgets.crea_btn.setText then
    pcall(function() W.widgets.crea_btn:setText("Cancel") end)
  end

  refresh_status()
  ensure_window_visible()
end

local function on_undo_last()
  reload_graph_from_disk({ preserve_base = W.pick_active })

  if #W.assoc_history == 0 then
    set_label(W.widgets.status, "No association to undo")
    return
  end

  local entry = table.remove(W.assoc_history, 1)
  graph_mod.remove_zone(W.graph, entry.base)

  if W.base_zone == entry.base then
    W.base_zone = nil
    if W.pick_active then
      map_pick.set_phase("base")
    end
  end

  persistence.save(W.graph, W.mission_id, W.settings)
  W.assoc_history = rebuild_history_from_graph(W.graph)
  refresh_link_overlay()
  refresh_status()
  set_label(W.widgets.status, "Removed association: " .. entry.base)
  ensure_window_visible()
end

local function on_open_config()
  if W.pick_active then
    set_label(W.widgets.status, "Exit link mode before opening Config")
    return
  end

  config_window.show({
    settings = W.settings,
    on_saved = function(new_settings)
      W.settings = util.table_copy_shallow(new_settings)
      reload_graph_from_disk({ preserve_base = false })
      apply_overlay_setting()
      refresh_status()
      set_label(W.widgets.status, "Config updated")
      ensure_window_visible()
    end,
  })
  ensure_window_visible()
end

local function on_toggle_overlay()
  reload_graph_from_disk({ preserve_base = W.pick_active })
  local enabled = not map_overlay.is_enabled()
  map_overlay.apply(enabled, W.graph, W.zones)
  W.settings.show_link_overlay = enabled
  settings.save(W.settings)
  update_overlay_button_text()
  if enabled then
    set_label(W.widgets.status, "Link overlay enabled")
  else
    set_label(W.widgets.status, "Link overlay disabled")
  end
  ensure_window_visible()
end

local function on_save()
  finalize_current_assoc()
  if W.pick_active then
    W.pick_active = false
    W.base_zone = nil
    map_pick.stop()
    if W.widgets.crea_btn and W.widgets.crea_btn.setText then
      pcall(function() W.widgets.crea_btn:setText("Create link") end)
    end
  end

  local ok_json, err_json = persistence.save(W.graph, W.mission_id, W.settings)
  local path = W.settings.config_path
  local warnings = zone_list.validate_graph_zones(graph_mod.to_confini(W.graph), W.zones)
  local ok_cfg, err_cfg = config_export.export_graph(W.graph, path)

  if not ok_json then
    set_label(W.widgets.status, "JSON save failed: " .. tostring(err_json))
    return
  end

  if not ok_cfg then
    set_label(W.widgets.status, "Config export failed: " .. tostring(err_cfg))
    return
  end

  W.graph.dirty = false
  refresh_link_overlay()
  refresh_status()
  if #warnings > 0 then
    set_label(W.widgets.status, "Saved with " .. #warnings .. " warnings (see dcs.log)")
    for _, w in ipairs(warnings) do util.warn(w) end
  else
    set_label(W.widgets.status, "Saved: JSON + config")
  end
end

local function make_button(parent, x, y, w, h, text, handler)
  local btn = Button.new()
  btn:setBounds(x, y, w, h)
  try_skin(btn, "buttonSkin")
  if btn.setText then btn:setText(text) end
  function btn:onChange()
    handler()
    ensure_window_visible()
  end
  parent:insertWidget(btn)
  return btn
end

local function make_label(parent, x, y, w, h, text)
  local st = Static.new()
  st:setBounds(x, y, w, h)
  try_skin(st, "staticSkin_ME")
  if st.setText then st:setText(text) end
  parent:insertWidget(st)
  return st
end

local function build_window()
  if not Window then
    util.error("dxgui Window not available")
    return false
  end

  local x, y = default_position()
  local win
  pcall(function() win = Window.new(0, 0) end)
  if not win then
    pcall(function() win = Window.new() end)
  end
  if not win then return false end

  win:setBounds(x, y, WIN_W, WIN_H)
  win:setText("DCORE Zone Link Editor")

  W.widgets.status = make_label(win, 12, 12, WIN_W - 24, 28, "Ready")
  W.widgets.base_label = make_label(win, 12, 42, WIN_W - 24, 18, "Base zone: (none)")
  W.widgets.links_label = make_label(win, 12, 62, WIN_W - 24, 36, "Linked: (none)")
  W.widgets.history_label = make_label(win, 12, 100, WIN_W - 24, 200, "JSON last 5 associations:\n  (none)")

  W.widgets.crea_btn = make_button(win, 12, 308, 130, 28, "Create link", on_crea_link)
  make_button(win, 150, 308, 130, 28, "Save", on_save)
  make_button(win, 288, 308, 140, 28, "Undo last", on_undo_last)
  W.widgets.overlay_btn = make_button(win, 12, 346, 200, 28, "Show links", on_toggle_overlay)
  make_button(win, 220, 346, 100, 28, "Config", on_open_config)

  function win:onClose()
    stop_pick()
    M.hide()
    return true
  end

  pcall(function()
    if win.setZOrder then win:setZOrder(10000) end
  end)

  W.window = win
  install_keepalive()
  return true
end

function M.show()
  if not W.window and not build_window() then
    return false
  end

  W.pick_active = false
  reload_graph_from_disk({ preserve_base = false })
  apply_overlay_setting()
  refresh_status()

  ensure_window_visible()
  W.visible = true
  return true
end

function M.hide()
  stop_pick()
  config_window.hide()
  if W.window then
    pcall(function()
      if W.window.setVisible then W.window:setVisible(false) end
    end)
  end
  W.visible = false
end

function M.toggle()
  if W.visible then
    M.hide()
  else
    M.show()
  end
end

return M
