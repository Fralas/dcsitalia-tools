--------------------------------------------------------------------------------------------------------------------------------
-- menu.lua - Voce "DCORE Tools" nella menubar del Mission Editor
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")

local M = {}

local function add_top_level_menu()
  local ok, mb = pcall(require, "me_menubar")
  if not ok or not mb or not mb.menuBar then return false end
  if mb._dcore_zone_linker_added then return true end

  local menu_bar = mb.menuBar
  if type(menu_bar.insertItem) ~= "function" then return false end

  local ok_menu, Menu = pcall(require, "Menu")
  local ok_bar_item, MenuBarItem = pcall(require, "MenuBarItem")
  if not (ok_menu and Menu and ok_bar_item and MenuBarItem) then return false end

  local sibling_top = menu_bar.customize
  local sibling_menu = sibling_top and sibling_top.menu

  local menu = Menu.new()
  pcall(function()
    if sibling_menu and sibling_menu.getSkin and menu.setSkin then
      menu:setSkin(sibling_menu:getSkin())
    end
  end)

  function menu:onChange(item)
    if item and item.func then item.func() end
  end

  local item
  local ok_new = pcall(function()
    item = menu:newItem("Zone Link Editor")
  end)
  if not ok_new or not item then return false end

  pcall(function()
    local sibling_item = sibling_menu
      and (sibling_menu.missionOptions or sibling_menu.mapOptions or sibling_menu.setPosition)
    if sibling_item and sibling_item.getSkin and item.setSkin then
      item:setSkin(sibling_item:getSkin())
    end
  end)

  item.func = function()
    util.info("Zone Link Editor menu clicked")
    local ok_t, terr = pcall(function()
      require("dcore_zone_linker.zone_link_window").toggle()
    end)
    if not ok_t then
      util.error("Zone Link Editor toggle failed: " .. tostring(terr))
    end
  end

  local ok_cfg, cfg_item = pcall(function()
    return menu:newItem("Zone Link Editor - Config")
  end)
  if ok_cfg and cfg_item then
    pcall(function()
      local sibling_item = sibling_menu
        and (sibling_menu.missionOptions or sibling_menu.mapOptions or sibling_menu.setPosition)
      if sibling_item and sibling_item.getSkin and cfg_item.setSkin then
        cfg_item:setSkin(sibling_item:getSkin())
      end
    end)
    cfg_item.func = function()
      local ok_c, cerr = pcall(function()
        local settings = require("dcore_zone_linker.settings")
        require("dcore_zone_linker.config_window").show({
          settings = settings.load(),
          on_saved = function()
            util.info("Zone Link Editor config saved from menu")
          end,
        })
      end)
      if not ok_c then
        util.error("Zone Link Editor config failed: " .. tostring(cerr))
      end
    end
  end

  local bar_item
  local ok_bar = pcall(function()
    bar_item = MenuBarItem.new("DCORE Tools", menu)
  end)
  if not ok_bar or not bar_item then return false end

  pcall(function()
    if sibling_top and sibling_top.getSkin and bar_item.setSkin then
      bar_item:setSkin(sibling_top:getSkin())
    end
  end)

  pcall(function() menu_bar:insertItem(bar_item) end)
  mb._dcore_zone_linker_added = true
  return true
end

local function patch_menubar_show()
  local ok, mb = pcall(require, "me_menubar")
  if not ok or not mb or type(mb.show) ~= "function" then return false end
  if mb._dcore_zone_linker_show_patched then return true end

  local orig_show = mb.show
  mb.show = function(...)
    local result = orig_show(...)
    pcall(add_top_level_menu)
    return result
  end
  mb._dcore_zone_linker_show_patched = true
  return true
end

local function patch_menubar_hideME()
  local ok, mb = pcall(require, "me_menubar")
  if not ok or not mb or type(mb.hideME) ~= "function" then return false end
  if mb._dcore_zone_linker_hideME_patched then return true end

  local orig_hideME = mb.hideME
  mb.hideME = function(...)
    pcall(function()
      local w = package.loaded["dcore_zone_linker.zone_link_window"]
      if w and w.hide then w.hide() end
      local c = package.loaded["dcore_zone_linker.config_window"]
      if c and c.hide then c.hide() end
    end)
    return orig_hideME(...)
  end
  mb._dcore_zone_linker_hideME_patched = true
  return true
end

function M.install()
  pcall(patch_menubar_hideME)

  if add_top_level_menu() then
    return "menu"
  end

  if patch_menubar_show() then
    return "menu"
  end

  return "failed"
end

return M
