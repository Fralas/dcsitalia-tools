--------------------------------------------------------------------------------------------------------------------------------
-- init.lua - Bootstrap DCORE Zone Link Editor
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")

local function _bootstrap()
  util.info("DCORE Zone Link Editor v" .. require("dcore_zone_linker.settings").VERSION .. " loading")

  local menu = require("dcore_zone_linker.menu")
  local result = menu.install()

  if result == "menu" then
    util.info("menu registered")
  else
    util.error("menu registration failed")
  end
end

local ok, err = pcall(_bootstrap)
if not ok then
  util.error("bootstrap failed: " .. tostring(err))
end
