--------------------------------------------------------------------------------------------------------------------------------
-- util.lua - Logging e helper comuni
--------------------------------------------------------------------------------------------------------------------------------

local M = {}

M.LOG_CHANNEL = "dcore.zone_linker"

function M.log(level, msg)
  pcall(function()
    log.write(M.LOG_CHANNEL, level or log.INFO, tostring(msg))
  end)
end

function M.info(msg)
  M.log(log.INFO, msg)
end

function M.error(msg)
  M.log(log.ERROR, msg)
end

function M.warn(msg)
  M.log(log.WARNING, msg)
end

function M.safe_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if ok then return result, nil end
  return nil, result
end

function M.table_copy_shallow(t)
  local out = {}
  if type(t) ~= "table" then return out end
  for k, v in pairs(t) do out[k] = v end
  return out
end

function M.sorted_keys(t)
  local keys = {}
  if type(t) ~= "table" then return keys end
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

local function _lfs()
  local ok, mod = pcall(require, "lfs")
  if ok then return mod end
  return nil
end

function M.dir_exists(path)
  if type(path) ~= "string" or path == "" then return false end
  path = path:gsub("/", "\\"):gsub("\\+$", "")

  local lfs = _lfs()
  if lfs and lfs.attributes then
    local attr = lfs.attributes(path)
    return attr ~= nil and attr.mode == "directory"
  end

  local probe = io.open(path .. "\\.", "r")
  if probe then
    probe:close()
    return true
  end
  return false
end

function M.ensure_dir(path)
  if type(path) ~= "string" or path == "" then return false end
  path = path:gsub("/", "\\"):gsub("\\+$", "")

  if M.dir_exists(path) then return true end

  local parent = path:match("^(.*)\\[^\\]+$")
  if parent and parent ~= "" and parent ~= path then
    M.ensure_dir(parent)
  end

  local lfs = _lfs()
  if lfs and lfs.mkdir then
    pcall(function() lfs.mkdir(path) end)
  end

  return M.dir_exists(path)
end

function M.dir_has_files_matching(dir, pattern)
  if type(dir) ~= "string" or dir == "" or type(pattern) ~= "string" then
    return false
  end

  local lfs = _lfs()
  if not (lfs and lfs.dir) then return false end

  for name in lfs.dir(dir) do
    if name ~= "." and name ~= ".." and name:match(pattern) then
      return true
    end
  end
  return false
end

function M.copy_tree(src, dst)
  if type(src) ~= "string" or type(dst) ~= "string" then return false end
  src = src:gsub("/", "\\"):gsub("\\+$", "")
  dst = dst:gsub("/", "\\"):gsub("\\+$", "")

  if not M.dir_exists(src) then return false end
  M.ensure_dir(dst)

  local lfs = _lfs()
  if not (lfs and lfs.dir and lfs.attributes) then return false end

  for name in lfs.dir(src) do
    if name ~= "." and name ~= ".." then
      local from = src .. "\\" .. name
      local to = dst .. "\\" .. name
      local attr = lfs.attributes(from)
      if attr and attr.mode == "directory" then
        M.copy_tree(from, to)
      else
        local inf = io.open(from, "rb")
        if inf then
          local data = inf:read("*a")
          inf:close()
          local outf = io.open(to, "wb")
          if outf then
            outf:write(data or "")
            outf:close()
          end
        end
      end
    end
  end

  return true
end

return M
