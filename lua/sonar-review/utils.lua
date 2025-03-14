local M = {}

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
end

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

local function is_table(table)
  return type(table) == "table"
end

function M.print_table(table, pfn)
  local _print = pfn or print

  if not is_table(table) then
    return
  end

  if #table > 0 then
    for _, value in ipairs(table) do
      if is_table(value) then
        M.print_table(value)
      else
        _print(value)
      end
    end
    return
  end

  for k, v in pairs(table) do
    if is_table(v) then
      _print(k)
      M.print_table(v)
    else
      _print(k)
      _print(v)
    end
  end
end

function M.table_len(tbl)
  if not is_table(tbl) then
    return 0
  end

  if #tbl > 0 then
    return #tbl
  end

  local len = 0

  for _, _ in pairs(tbl) do
    len = len + 1
  end

  return len
end

return M
