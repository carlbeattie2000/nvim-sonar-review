local M = {}

local read_file = vim.fn.stdpath("cache") .. "/sonar-review-read.json"

local function find_project_root()
  local dir = vim.fn.expand("%:p:h")
  local sonar_file = vim.fn.findfile("sonar-project.properties", dir .. ";")

  if sonar_file == "" then
    sonar_file = vim.fn.findfile("sonar-project.prompt_title", vim.fn.getcwd() .. ";")

    if sonar_file == "" then
      vim.notify("No sonar-project.properties found", vim.log.levels.WARN)

      return nil
    end
  end

  return vim.fn.fnamemodify(sonar_file, ":p:h")
end

local function get_sonar_project_key()
  local root = find_project_root()

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

local function load_env()
  local root = find_project_root()

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

local function load_state(file)
  if vim.fn.filereadable(file) == 1 then
    return vim.fn.json_decode(table.concat(vim.fn.readfile(file), "\n")) or {}
  end

  return {}
end

local function save_state(state, file)
  vim.fn.writefile({ vim.fn.json_encode(state) }, file)
end

local function get_issues(query)
  local env, _ = load_env()
  local token = env.SONAR_TOKEN or "admin"
  local sonar_address = os.getenv("SONAR_ADDRESS") or "http://localhost:9000"
  local cmd = string.format('curl -s -u %s: "%s/api/issues/search?%s"', token, sonar_address, query)
  local result = vim.fn.system({ "sh", "-c", cmd })
  local ok, decoded = pcall(vim.fn.json_decode, result)

  return ok and decoded or { issues = {} }
end

local function clear_outdated_cache_results()
  local project_key = get_sonar_project_key()
  vim.print(tostring(vim.fn.filereadable(read_file)))
  vim.print(vim.fn.json_decode(table.concat(vim.fn.readfile(read_file), "\n")))
  vim.print(project_key)
  local issues = get_issues("componentKeys=" .. project_key)
  vim.print(issues)
end


local function show_reports(title, lines, issue_keys, on_select, on_dismiss, use_telescope)
  local has_telescope, telescope = pcall(require, "telescope.pickers")

  if use_telescope and has_telescope then
    telescope.new({
      prompt_title = title,
      finder = require("telescope.finders").new_table({ results = lines }),
      sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<CR>", function()
          local sel = require("telescope.actions.state").get_selected_entry()[1]
          if on_select then on_select(sel, issue_keys[sel]) end
          require("telescope.actions").close(prompt_bufnr)
        end)
        map("i", "<leader>d", function()
          local sel = require("telescope.actions.state").get_selected_entry()[1]
          if on_dismiss and issue_keys[sel] then
            on_dismiss(sel, issue_keys[sel])
            require("telescope.actions").close(prompt_bufnr)
          end
        end)
        return true
      end,
    }, {}):find()
  else
    vim.cmd("vsplit | enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { title, "" })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, lines)
    vim.bo.filetype = "markdown"
    vim.bo.buftype = "nofile"
    vim.keymap.set("n", "<CR>", function()
      local sel = vim.fn.getline(".")
      if on_select then on_select(sel, issue_keys[sel]) end
      vim.cmd("wincmd q")
    end, { buffer = 0 })
    vim.keymap.set("n", "<leader>d", function()
      local sel = vim.fn.getline(".")
      if on_dismiss and issue_keys[sel] then on_dismiss(sel, issue_keys[sel]) end
    end, { buffer = 0 })
  end
end

function M.show_buffer_reports()
  clear_outdated_cache_results()
  local env, root = load_env()
  local project_key = get_sonar_project_key()

  if not root or not project_key then return end

  local file = vim.fn.expand("%:p")

  if not file or file == "" or not file:match(root) then
    vim.notify("No valid project file in buffer", vim.log.levels.WARN)
    return
  end

  file = file:gsub(root .. "/", "")

  local read = load_state(read_file)
  local issues = get_issues("componentKeys=" .. project_key .. "&files=" .. file)
  local lines = {}
  local issue_keys = {}

  for _, issue in ipairs(issues.issues) do
    if issue.issueStatus ~= "FIXED" then
      local is_read = read[issue.key] and "[X]" or "[  ]"
      local line = string.format(
        "%s - %s - %s %s (Line %s)",
        issue.revision or "unknown",
        issue.creationDate:match("^%d%d%d%d%-%d%d%-%d%d"),
        is_read,
        issue.message,
        issue.line or "N/A"
      )

      table.insert(lines, line)
      issue_keys[line] = issue.key
    end
  end

  if #lines == 0 then table.insert(lines, "No active issues found.") end

  show_reports("Reports for " .. file, lines, issue_keys,
    function(_, key)
      local file_line = vim.fn.getline("."):match("Line (%d+)")

      if file_line then
        vim.api.nvim_win_set_cursor(0, { tonumber(file_line), 0 })
      end

      if key then
        read[key] = true
        save_state(read, read_file)
      end
    end,
    function(_, key)
      read[key] = true

      save_state(read, read_file)
      M.show_buffer_reports()
    end,
    false)
end

function M.show_file_reports()
  local project_key = get_sonar_project_key()

  if not project_key then return end

  local read = load_state(read_file)
  local files = {}
  local seen = {}
  local all_issues = get_issues("componentKeys="..project_key)

  for _, issue in ipairs(all_issues.issues) do
    if issue.issueStatus ~= "FIXED" then
      local file = issue.component:match(project_key .. ":(.+)") or issue.component

      if not seen[file] then
        table.insert(files, file)
        seen[file] = true
      end
    end
  end

  local has_telescope, telescope = pcall(require, "telescope.pickers")

  if has_telescope then
    telescope.new({
      prompt_title = "Files with Reports",
      finder = require("telescope.finders").new_table({ results = files }),
      sorter = require("telescope.sorters").get_fuzzy_file(),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<CR>", function()
          local file = require("telescope.actions.state").get_selected_entry()[1]
          require("telescope.actions").close(prompt_bufnr)
          local issues = get_issues("componentKeys=" .. project_key .. "&files=" .. file)
          local report_lines = {}
          local issue_keys = {}

          for _, issue in ipairs(issues.issues) do
            if issue.issueStatus ~= "FIXED" then
              local is_read = read[issue.key] and "[x]" or "[ ]"
              local line = string.format(
                "%s - %s - %s %s (Line %s)",
                issue.revision or "unknown",
                issue.creationDate:match("^%d%d%d%d%-%d%d%-%d%d"),
                is_read,
                issue.message,
                issue.line or "N/A"
              )
              table.insert(report_lines, line)
              issue_keys[line] = issue.key
            end
          end

          if #report_lines == 0 then table.insert(report_lines, "No active issues.") end

          show_reports("Reports for " .. file, report_lines, issue_keys,
            function(_, key)
              local file_line = vim.fn.getline("."):match("Line (%d+)")

              if key then
                read[key] = true
                save_state(read, read_file)
              end

              if file_line then
                vim.cmd("edit " .. file)
                vim.api.nvim_win_set_cursor(0, { tonumber(file_line), 0 })
              end
            end,
            function(_, key)
              read[key] = true
              save_state(read, read_file)
              M.show_file_reports()
            end,
            true)
        end)
        return true
      end,
    }, {}):find()
  else
    show_reports("Files with Reports", files, {},

      function(sel)
        vim.cmd("edit " .. sel)
        M.show_buffer_reports() -- Fallback to buffer reports
      end, nil, false)
  end
end

function M.setup(opts) end

return M
