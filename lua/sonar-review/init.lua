local M = {}

local read_file = vim.fn.stdpath("cache") .. "/sonar-review-read.json"
local dismissed_file = vim.fn.stdpath("cache") .. "/sonar-review-dismissed.json"

local function load_state(file)
  if vim.fn.filereadable(file) == 1 then
    return vim.fn.json_decode(table.concat(vim.fn.readFile(file), "\n")) or {}
  end
end

local function save_state(state, file)
  vim.fn.writefile({ vim.fn.json_encode(state) }, file)
end

local function get_issues(query)
  local user = os.getenv("SONAR_USER") or "admin"
  local pass = os.getenv("SONAR_PASS") or "admin"
  local sonar_address = os.getenv("SONAR_ADDRESS") or "http://localhost:9000"

  local cmd = string.format('curl -s -u %s:%s "%s/api/issues/search?%s"', user, pass, sonar_address, query)
  local result = vim.fn.system(cmd)

  return vim.fn.json_decode(result) or { issues = {} }
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
  local file = vim.fn.expand("%:p"):gsub(vim.fn.getcwd() .. "/", "")
  if not file or file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local dismissed = load_state(dismissed_file)
  local read = load_state(read_file)
  local issues = get_issues("componentKeys=myproject&files=" .. file)
  local lines = {}
  local issue_keys = {}

  for _, issue in ipairs(issues.issues) do
    if not dismissed[issue.key] then
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
      dismissed[key] = true
      read[key] = true

      save_state(dismissed, dismissed_file)
      save_state(read, read_file)
      M.show_buffer_reports()
    end,
    false)
end

function M.show_commit_reports()
  local read = load_state(read_file)
  local dismissed = load_state(dismissed_file)
  local commits = vim.fn.systemlist("git log --pretty=format: '%h - %ad - %s' --date=short -n 10")
  local lines = {}
  local issue_keys = {}

  for _, commit_line in ipairs(commits) do
    local commit_hash = commit_line:match("^(%w+)")
    local files = vim.fn.systemlist("git diff-tree --no-commit-id --name-only -r " .. commit_hash)
    local file_issues = {}

    for _, file in ipairs(files) do
      local issues = get_issues("componentKeys=myproject&files=" .. file)
      local reports = {}

      for _, issue in ipairs(issues.issue) do
        if not dismissed[issue.key] then
          local key = commit_hash .. ":" .. issue.key
          local is_read = read[key] and "[X]" or "[  ]"

          table.insert(reports,
            {
              text = is_read .. " " .. issue.message .. " (Line " .. (issue.line or "N/A") .. ")",
              key = key,
              issue_key =
                  issue.key
            })
        end
      end
      if #reports > 0 then file_issues[file] = reports end
    end

    if next(file_issues) then
      local all_read = true

      for _, reports in pairs(file_issues) do
        for _, report in ipairs(reports) do
          if not read[report.key] then
            all_read = false
            break
          end
        end
      end

      table.insert(lines, (all_read and "[x] " or "[ ] ") .. commit_line)

      for file, reports in pairs(file_issues) do
        table.insert(lines, " " .. file)
        for _, report in ipairs(reports) do
          table.insert(lines, "   " .. report.text)
          issue_keys[lines[#lines]] = report.key
        end
      end
    end
  end

  show_reports("Commit Reports ", lines, issue_keys,
    function(sel, key)
      if not sel:match("^%s%s%s%s") then return end

      if key then
        read[key] = true
        save_state(read, read_file)
        M.show_commit_reports()
      end
    end,
    function(sel, key)
      if not sel:match("^%s%s%s%s") then return end

      if key then
        dismissed[key:match(":(.+)$")] = true
        read[key] = true
        save_state(read, read_file)
        save_state(dismissed, dismissed_file)
        M.show_commit_reports()
      end
    end,
    true)
end

function M.show_file_reports()
  local dismissed = load_state(dismissed_file)
  local read = load_state(read_file)
  local files = {}
  local seen = {}
  local all_issues = get_issues("componentKeys=myproject")

  for _, issue in ipairs(all_issues.issues) do
    if not dismissed[issue.key] then
      local file = issue.component:match("myproject:(.+)") or issue.component

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
          local issues = get_issues("componentKeys=myproject&files=" .. file)
          local report_lines = {}
          local issue_keys = {}

          for _, issue in ipairs(issues.issues) do
            if not dismissed[issue.key] then
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
              dismissed[key] = true
              read[key] = true
              save_state(dismissed, dismissed_file)
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
