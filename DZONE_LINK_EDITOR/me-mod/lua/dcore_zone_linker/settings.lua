--------------------------------------------------------------------------------------------------------------------------------
-- settings.lua - Impostazioni persistenti del mod
--------------------------------------------------------------------------------------------------------------------------------

local util = require("dcore_zone_linker.util")

local M = {}

M.VERSION = "1.2.0"

M.DEFAULT_ZONE_PREFIX = "zone_"
M.DEFAULT_CONFIG_PATH = "C:\\DCS SERVER\\MISSION SCRIPTS\\DCORE\\src\\TOOLS\\DZONE_TEST\\DZONE_TEST_Config.lua"
M.DEFAULT_DCS_INSTALL_PATH = ""

local function _normalize_dir(path)
  if type(path) ~= "string" or path == "" then return nil end
  return path:gsub("/", "\\"):gsub("\\+$", "")
end

local function _normalize_file(path)
  if type(path) ~= "string" or path == "" then return nil end
  return path:gsub("/", "\\")
end

local function _auto_saved_games_root()
  local ok, lfs = pcall(require, "lfs")
  if ok and lfs and type(lfs.writedir) == "function" then
    return _normalize_dir(lfs.writedir())
  end

  local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
  if home == "" then return nil end

  for _, sub in ipairs({ "DCS.openbeta", "DCS" }) do
    local candidate = _normalize_dir(home .. "\\Saved Games\\" .. sub)
    if candidate then
      local probe = io.open(candidate .. "\\Logs\\dcs.log", "r")
      if probe then
        probe:close()
        return candidate
      end
    end
  end

  return _normalize_dir(home .. "\\Saved Games\\DCS")
end

local function _legacy_settings_dirs()
  local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
  if home == "" then return {} end
  return {
    _normalize_dir(home .. "\\Saved Games\\DCS\\dcore-tools\\zone-linker"),
    _normalize_dir(home .. "\\Saved Games\\DCS.openbeta\\dcore-tools\\zone-linker"),
  }
end

local function _bootstrap_settings_dir()
  local root = _auto_saved_games_root()
  if not root then return nil end
  return root .. "\\dcore-tools\\zone-linker"
end

function M.defaults()
  return {
    zone_prefix = M.DEFAULT_ZONE_PREFIX,
    config_path = M.DEFAULT_CONFIG_PATH,
    dcs_install_path = M.DEFAULT_DCS_INSTALL_PATH,
    saved_games_root = "",
    show_all_zones = false,
    show_link_overlay = false,
  }
end

function M.get_saved_games_root(data)
  data = data or M.load()
  local override = _normalize_dir(data and data.saved_games_root)
  if override then return override end
  return _auto_saved_games_root()
end

function M.settings_path()
  local dir = _bootstrap_settings_dir()
  if not dir then return nil end
  return dir .. "\\settings.lua"
end

function M.storage_dir(data)
  local root = M.get_saved_games_root(data)
  if not root then return nil end
  return root .. "\\dcore-tools\\zone-linker\\graphs"
end

function M.tool_config_dir(data)
  local root = M.get_saved_games_root(data)
  if not root then return nil end
  return root .. "\\dcore-tools\\zone-linker"
end

function M.saved_games_root()
  return M.get_saved_games_root(M.load())
end

function M.guess_saved_games_from_install(install_path)
  local install = _normalize_dir(install_path)
  if not install then return nil end
  local home = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
  if home == "" then return nil end
  if install:lower():find("openbeta", 1, true) then
    return _normalize_dir(home .. "\\Saved Games\\DCS.openbeta")
  end
  return _normalize_dir(home .. "\\Saved Games\\DCS")
end

local function _migrate_legacy_storage()
  local target = _bootstrap_settings_dir()
  if not target then return end

  local has_settings = io.open(target .. "\\settings.lua", "r") ~= nil
  local graphs_dir = target .. "\\graphs"
  local has_graph = false
  local ok = os.execute('if exist "' .. graphs_dir:gsub("/", "\\") .. '\\*.json" exit 0 else exit 1 end')
  if ok == 0 or ok == true then has_graph = true end

  if has_settings or has_graph then return end

  for _, legacy in ipairs(_legacy_settings_dirs()) do
    if legacy and legacy ~= target then
      local src_settings = legacy .. "\\settings.lua"
      local f = io.open(src_settings, "r")
      if f then
        f:close()
        os.execute('mkdir "' .. target:gsub("/", "\\") .. '" 2>nul')
        os.execute('xcopy "' .. legacy:gsub("/", "\\") .. '" "' .. target:gsub("/", "\\") .. '" /E /I /Y >nul 2>&1')
        return
      end
    end
  end
end

function M.load()
  _migrate_legacy_storage()

  local out = M.defaults()
  local path = M.settings_path()
  if not path then return out end

  local f = io.open(path, "r")
  if not f then return out end
  local chunk = f:read("*a")
  f:close()

  local fn, err = loadstring(chunk)
  if not fn then
    util.warn("settings load failed: " .. tostring(err))
    return out
  end

  local ok, data = pcall(fn)
  if ok and type(data) == "table" then
    if type(data.zone_prefix) == "string" and data.zone_prefix ~= "" then
      out.zone_prefix = data.zone_prefix
    end
    if type(data.config_path) == "string" and data.config_path ~= "" then
      out.config_path = _normalize_file(data.config_path) or out.config_path
    end
    if type(data.dcs_install_path) == "string" then
      out.dcs_install_path = _normalize_dir(data.dcs_install_path) or ""
    end
    if type(data.saved_games_root) == "string" then
      out.saved_games_root = _normalize_dir(data.saved_games_root) or ""
    end
    if data.show_all_zones == true then
      out.show_all_zones = true
    end
    if data.show_link_overlay == true then
      out.show_link_overlay = true
    end
  end

  return out
end

function M.validate(data)
  data = data or M.load()
  local warnings = {}

  local cfg = _normalize_file(data.config_path)
  if not cfg then
    warnings[#warnings + 1] = "Confini export path not set"
  else
    local dir = cfg:match("^(.*)\\[^\\]+$")
    if dir then
      local probe = io.open(dir .. "\\.", "r")
      if not probe then
        warnings[#warnings + 1] = "Export folder not found: " .. dir
      else
        probe:close()
      end
    end
  end

  local sg = _normalize_dir(data.saved_games_root)
  if sg then
    local probe = io.open(sg .. "\\.", "r")
    if not probe then
      warnings[#warnings + 1] = "Custom Saved Games folder not found: " .. sg
    else
      probe:close()
    end
  end

  local install = _normalize_dir(data.dcs_install_path)
  if install then
    local probe = io.open(install .. "\\.", "r")
    if not probe then
      warnings[#warnings + 1] = "DCS install directory not found: " .. install
    else
      probe:close()
    end
  end

  if type(data.zone_prefix) ~= "string" or data.zone_prefix == "" then
    warnings[#warnings + 1] = "Zone prefix is empty"
  end

  return warnings
end

function M.save(data)
  if type(data) ~= "table" then return false end
  local path = M.settings_path()
  local dir = _bootstrap_settings_dir()
  if not path or not dir then return false end

  os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')

  local lines = {
    "return {",
    '  zone_prefix = ' .. string.format("%q", data.zone_prefix or M.DEFAULT_ZONE_PREFIX) .. ",",
    '  config_path = ' .. string.format("%q", _normalize_file(data.config_path) or M.DEFAULT_CONFIG_PATH) .. ",",
    '  dcs_install_path = ' .. string.format("%q", _normalize_dir(data.dcs_install_path) or "") .. ",",
    '  saved_games_root = ' .. string.format("%q", _normalize_dir(data.saved_games_root) or "") .. ",",
    "  show_all_zones = " .. tostring(data.show_all_zones == true) .. ",",
    "  show_link_overlay = " .. tostring(data.show_link_overlay == true) .. ",",
    "}",
  }

  local f, err = io.open(path, "w")
  if not f then
    util.error("settings save failed: " .. tostring(err))
    return false
  end
  f:write(table.concat(lines, "\n"))
  f:close()
  util.info("settings saved: " .. path)
  return true
end

return M
