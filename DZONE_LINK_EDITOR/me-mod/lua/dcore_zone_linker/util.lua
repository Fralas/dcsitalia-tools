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

return M
