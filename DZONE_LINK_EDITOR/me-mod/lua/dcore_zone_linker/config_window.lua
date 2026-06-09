--------------------------------------------------------------------------------------------------------------------------------
-- config_window.lua - Finestra impostazioni Zone Link Editor
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")
local settings = require("dcore_zone_linker.settings")

local M = {}

local Window, Static, Button, EditBox, CheckBox, Skin, Gui

do
  local ok, mod = pcall(require, "Window"); if ok then Window = mod end
  local ok2, mod2 = pcall(require, "Static"); if ok2 then Static = mod2 end
  local ok3, mod3 = pcall(require, "Button"); if ok3 then Button = mod3 end
  local ok4, mod4 = pcall(require, "EditBox"); if ok4 then EditBox = mod4 end
  local ok5, mod5 = pcall(require, "CheckBox"); if ok5 then CheckBox = mod5 end
  local ok6, mod6 = pcall(require, "Skin"); if ok6 then Skin = mod6 end
  local ok7, mod7 = pcall(require, "dxgui"); if ok7 then Gui = mod7 end
end

local C = {
  visible = false,
  window = nil,
  draft = nil,
  widgets = {},
  on_saved = nil,
}

local WIN_W = 560
local WIN_H = 430
local ROW_H = 24
local GAP = 8
local MARGIN = 12
local LABEL_W = 150
local BTN_W = 72

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
  return math.max(20, (screen_w - WIN_W) / 2), 120
end

local function set_label(widget, text)
  if widget and widget.setText then
    pcall(function() widget:setText(tostring(text)) end)
  end
end

local function get_edit_text(widget)
  if not widget or not widget.getText then return "" end
  local ok, text = pcall(function() return widget:getText() end)
  if ok and type(text) == "string" then return text end
  return ""
end

local function set_edit_text(widget, text)
  if widget and widget.setText then
    pcall(function() widget:setText(tostring(text or "")) end)
  end
end

local function get_checkbox(widget)
  if not widget or not widget.getState then return false end
  local ok, state = pcall(function() return widget:getState() end)
  return ok and state == true
end

local function set_checkbox(widget, state)
  if widget and widget.setState then
    pcall(function() widget:setState(state == true) end)
  end
end

local function _file_dialog()
  local ok, fd = pcall(require, "FileDialog")
  if ok then return fd end
  return nil
end

local function _file_filters()
  local ok, ff = pcall(require, "FileDialogFilters")
  if ok and ff and ff.script then
    return { ff.script() }
  end
  return { { "Lua", "(*.lua)" } }
end

local function _start_dir(path)
  if type(path) ~= "string" or path == "" then
    return settings.get_saved_games_root(settings.load())
  end
  local dir = path:match("^(.*)\\[^\\]+$")
  if dir and dir ~= "" then return dir end
  return path
end

local function refresh_info_label()
  local draft = C.draft or settings.load()
  local graphs = settings.storage_dir(draft) or "(unavailable)"
  local settings_path = settings.settings_path() or "(unavailable)"
  set_label(C.widgets.info_label, table.concat({
    "JSON graphs: " .. graphs,
    "Settings: " .. settings_path,
  }, "\n"))
end

local function load_draft_to_widgets()
  local d = C.draft or settings.defaults()
  set_edit_text(C.widgets.edit_saved_games, d.saved_games_root or "")
  set_edit_text(C.widgets.edit_dcs_install, d.dcs_install_path or "")
  set_edit_text(C.widgets.edit_config_path, d.config_path or "")
  set_edit_text(C.widgets.edit_zone_prefix, d.zone_prefix or settings.DEFAULT_ZONE_PREFIX)
  set_checkbox(C.widgets.chk_all_zones, d.show_all_zones == true)
  set_checkbox(C.widgets.chk_overlay, d.show_link_overlay == true)
  refresh_info_label()
end

local function collect_draft_from_widgets()
  return {
    zone_prefix = get_edit_text(C.widgets.edit_zone_prefix),
    config_path = get_edit_text(C.widgets.edit_config_path),
    dcs_install_path = get_edit_text(C.widgets.edit_dcs_install),
    saved_games_root = get_edit_text(C.widgets.edit_saved_games),
    show_all_zones = get_checkbox(C.widgets.chk_all_zones),
    show_link_overlay = get_checkbox(C.widgets.chk_overlay),
  }
end

local function browse_saved_games()
  local fd = _file_dialog()
  if not fd or not fd.selectFolder then return end
  local start = get_edit_text(C.widgets.edit_saved_games)
  if start == "" then start = settings.get_saved_games_root(settings.load()) end
  local ok, folder = pcall(function()
    return fd.selectFolder(start, "Saved Games DCS")
  end)
  if ok and folder and folder ~= "" then
    set_edit_text(C.widgets.edit_saved_games, folder)
    C.draft = collect_draft_from_widgets()
    refresh_info_label()
  end
end

local function browse_dcs_install()
  local fd = _file_dialog()
  if not fd or not fd.selectFolder then return end
  local start = get_edit_text(C.widgets.edit_dcs_install)
  if start == "" then start = "C:\\" end
  local ok, folder = pcall(function()
    return fd.selectFolder(start, "DCS install directory")
  end)
  if ok and folder and folder ~= "" then
    set_edit_text(C.widgets.edit_dcs_install, folder)
    local guessed = settings.guess_saved_games_from_install(folder)
    if guessed and get_edit_text(C.widgets.edit_saved_games) == "" then
      set_edit_text(C.widgets.edit_saved_games, guessed)
    end
    C.draft = collect_draft_from_widgets()
    refresh_info_label()
  end
end

local function browse_config_path()
  local fd = _file_dialog()
  if not fd then return end
  local start = _start_dir(get_edit_text(C.widgets.edit_config_path))
  local filters = _file_filters()
  local ok, filename
  if fd.save then
    ok, filename = pcall(function()
      return fd.save(start, filters, "Confini export file", "lua", "DZONE_TEST_Config")
    end)
  else
    ok, filename = pcall(function()
      return fd.open(start, filters, "Confini export file")
    end)
  end
  if ok and filename and filename ~= "" then
    set_edit_text(C.widgets.edit_config_path, filename)
  end
end

local function on_restore_defaults()
  C.draft = settings.defaults()
  load_draft_to_widgets()
end

local function on_save()
  C.draft = collect_draft_from_widgets()
  if C.draft.zone_prefix == "" then
    C.draft.zone_prefix = settings.DEFAULT_ZONE_PREFIX
  end

  local warnings = settings.validate(C.draft)
  if not settings.save(C.draft) then
    set_label(C.widgets.status, "Failed to save settings")
    return
  end

  if type(C.on_saved) == "function" then
    pcall(C.on_saved, util.table_copy_shallow(C.draft))
  end

  if #warnings > 0 then
    set_label(C.widgets.status, "Saved with " .. #warnings .. " warnings (see dcs.log)")
    for _, w in ipairs(warnings) do util.warn(w) end
  else
    set_label(C.widgets.status, "Settings saved")
  end
end

local function on_cancel()
  M.hide()
end

local function make_label(parent, x, y, w, h, text)
  local st = Static.new()
  st:setBounds(x, y, w, h)
  try_skin(st, "staticSkin_ME")
  set_label(st, text)
  parent:insertWidget(st)
  return st
end

local function make_button(parent, x, y, w, h, text, handler)
  local btn = Button.new()
  btn:setBounds(x, y, w, h)
  try_skin(btn, "buttonSkin")
  set_label(btn, text)
  function btn:onChange()
    handler()
  end
  parent:insertWidget(btn)
  return btn
end

local function make_edit_row(parent, y, label, key)
  local field_w = WIN_W - MARGIN * 2 - LABEL_W - BTN_W - GAP
  make_label(parent, MARGIN, y, LABEL_W, ROW_H, label)
  local edit = EditBox.new()
  edit:setBounds(MARGIN + LABEL_W + GAP, y, field_w, ROW_H)
  try_skin(edit, "editBoxSkin")
  parent:insertWidget(edit)
  C.widgets[key] = edit
  make_button(parent, MARGIN + LABEL_W + GAP + field_w + GAP, y, BTN_W, ROW_H, "...", function()
    if key == "edit_saved_games" then browse_saved_games()
    elseif key == "edit_dcs_install" then browse_dcs_install()
    elseif key == "edit_config_path" then browse_config_path()
    end
  end)
  return y + ROW_H + GAP
end

local function build_window()
  if not Window or not EditBox then
    util.error("config window: dxgui not available")
    return false
  end

  local x, y = default_position()
  local win
  pcall(function() win = Window.new(0, 0) end)
  if not win then pcall(function() win = Window.new() end) end
  if not win then return false end

  win:setBounds(x, y, WIN_W, WIN_H)
  win:setText("Zone Link Editor - Config")

  local row_y = MARGIN + 4
  row_y = make_edit_row(win, row_y, "Saved Games:", "edit_saved_games")
  row_y = make_edit_row(win, row_y, "Install DCS:", "edit_dcs_install")
  row_y = make_edit_row(win, row_y, "Confini export:", "edit_config_path")
  row_y = make_edit_row(win, row_y, "Zone prefix:", "edit_zone_prefix")

  make_label(win, MARGIN, row_y, 220, ROW_H, "Map zone filter")
  if CheckBox then
    local chk1 = CheckBox.new()
    chk1:setBounds(MARGIN + 220, row_y, 180, ROW_H)
    try_skin(chk1, "checkBoxSkin")
    set_label(chk1, "All zones")
    win:insertWidget(chk1)
    C.widgets.chk_all_zones = chk1

    local chk2 = CheckBox.new()
    chk2:setBounds(MARGIN + 400, row_y, 180, ROW_H)
    try_skin(chk2, "checkBoxSkin")
    set_label(chk2, "Overlay on start")
    win:insertWidget(chk2)
    C.widgets.chk_overlay = chk2
  end

  row_y = row_y + ROW_H + GAP + 4
  C.widgets.info_label = make_label(win, MARGIN, row_y, WIN_W - MARGIN * 2, 48, "")
  row_y = row_y + 52

  make_label(win, MARGIN, row_y, WIN_W - MARGIN * 2, 36,
    "Empty Saved Games = auto (DCS writedir).\nInstall DCS = install path reference / mod reinstall.")

  C.widgets.status = make_label(win, MARGIN, WIN_H - 78, WIN_W - MARGIN * 2, 22, "")
  make_button(win, MARGIN, WIN_H - 48, 120, 28, "Restore", on_restore_defaults)
  make_button(win, WIN_W - 252, WIN_H - 48, 110, 28, "Cancel", on_cancel)
  make_button(win, WIN_W - 132, WIN_H - 48, 120, 28, "Save", on_save)

  function win:onClose()
    M.hide()
    return true
  end

  pcall(function()
    if win.setZOrder then win:setZOrder(10001) end
  end)

  C.window = win
  return true
end

function M.show(opts)
  opts = opts or {}
  C.on_saved = opts.on_saved
  C.draft = util.table_copy_shallow(opts.settings or settings.load())

  if not C.window and not build_window() then
    return false
  end

  load_draft_to_widgets()
  set_label(C.widgets.status, "")

  pcall(function()
    if C.window.setVisible then C.window:setVisible(true) end
    if C.window.setZOrder then C.window:setZOrder(10001) end
  end)

  C.visible = true
  return true
end

function M.hide()
  if C.window then
    pcall(function()
      if C.window.setVisible then C.window:setVisible(false) end
    end)
  end
  C.visible = false
  C.on_saved = nil
end

function M.is_visible()
  return C.visible
end

return M
