local M = {}

---comment
---@return string | nil
function M.find_project_root()
  local dir = vim.fn.expand("%:p:h")
  local sonar_file = vim.fn.findfile("sonar-project.properties", dir .. ";")

  if sonar_file == "" then
    sonar_file = vim.fn.findfile("sonar-project.properties", vim.fn.getcwd() .. ";")

    if sonar_file == "" then
      vim.notify("No sonar-project.properties found", vim.log.levels.WARN)

      return nil
    end
  end

  return vim.fn.fnamemodify(sonar_file, ":p:h")
end

---comment
---@return nil | string
function M.get_sonar_project_key()
  local root = M.find_project_root()

  if not root then return nil end

  local sonar_path = root .. "/sonar-project.properties"

  if vim.fn.filereadable(sonar_path) == 1 then
    for _, line in ipairs(vim.fn.readfile(sonar_path)) do
      local key = line:match("^sonar%.projectKey=(.+)$")

      if key then return key end
    end
  else
    vim.notify("sonar-project.properties file not found in " .. root, vim.log.levels.INFO)

    return nil
  end

  vim.notify("project key not found in " .. root, vim.log.levels.INFO)
  return nil
end

---comment
---@return table | nil
function M.load_env()
  local root = M.find_project_root()

  if not root then return {}, nil end

  local env_path = root .. "/.env"
  local env = {}

  if vim.fn.filereadable(env_path) == 1 then
    for _, line in ipairs(vim.fn.readfile(env_path)) do
      local key, value = line:match("^(.+)=(.+)$")

      if key and value then
        env[key] = value
      end
    end
  else
    vim.notify(".env not found in " .. root, vim.log.levels.INFO)
  end

  return env, root
end

---comment
---@param key string
---@return string | nil
function M.get_env_value(key)
  local env = M.load_env()

  return env[key]
end

---comment
---@param table any
---@return boolean
local function is_table(table)
  return type(table) == "table"
end

function M.clear_quickfix_list()
  vim.fn.setqflist({})
end

---comment
---@param t table
---@param filter_fn function
---@return table
function M.table_filter(t, filter_fn)
  if not is_table(t) or #t == 0 then
    return {}
  end

  local new_table = {}

  for _, item in ipairs(t) do
    if filter_fn(item) then
      table.insert(new_table, item)
    end
  end

  return new_table
end

---comment
---@return unknown
M.get_neovim_version = function()
  return vim.version()
end

---comment
---@param version_t { major: number?, minor: number?, patch: number? } | string
---@return boolean
M.neovim_is_above_or_equal_version = function(version_t)
  local version = M.get_neovim_version()

  if type(version_t) == "string" then
    return vim.version.ge(version, version_t)
  end

  return vim.version.ge(version, { version_t.major, version_t.minor, version_t.patch })
end

return M
