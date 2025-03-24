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

  vim.notify("project key not found in " .. root, vim.log.levels.INFO)
  return nil
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

function M.get_env_value(key)
  local env = M.load_env()

  return env[key]
end

local function is_table(table)
  return type(table) == "table"
end

local function get_tabs_string(depth)
  if depth == 0 then
    return ""
  end

  local tab_string = ""

  for _ = 1, depth do
    tab_string = tab_string .. "  "
  end

  return tab_string
end

function M.print_table(table, pfn, depth)
  depth = depth or 0
  local _print = pfn or print

  if not is_table(table) then
    return
  end

  if #table > 0 then
    for _, value in ipairs(table) do
      if is_table(value) then
        M.print_table(value, pfn, depth + 1)
      else
        _print(get_tabs_string(depth), value)
      end
    end
    return
  end

  for k, v in pairs(table) do
    if is_table(v) then
      _print(get_tabs_string(depth), k)
      M.print_table(v, pfn, depth + 1)
    else
      _print(get_tabs_string(depth), k .. " = " .. tostring(v))
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

function M.print_dict_keys(table, pfn)
  pfn = pfn or print

  if not is_table(table) then
    return
  end

  if #table > 0 then
    return
  end

  for k, v in pairs(table) do
    pfn(k)

    if is_table(v) then
      M.print_dict_keys(v, pfn)
    end
  end
end

function M.clear_quickfix_list()
  vim.fn.setqflist({})
end

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

return M
