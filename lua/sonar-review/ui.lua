local sonar_review = require 'sonar-review'
local utils = require 'sonar-review.utils'
local git = require 'sonar-review.git'
local sonar_api = require 'sonar-review.sonar_api'

local M = {}

local config = sonar_review.get_config()

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

local function show_issue_details(file, issue)
  local issue_type = issue.type or "UNKNOWN"
  local type_display = (issue_type == "SECURITY_HOTSPOT" and "Security Hotspot") or issue_type
  local issue_status = issue.issueStatus or issue.status

  local lines = {
    "# Issue Details: " .. file,
    "",
    "**Type**: " .. type_display,
    "**Message**: " .. issue.message,
    "**Line**: " .. (issue.line or "N/A"),
    "**Created**: " .. (issue.creationDate:match("^%d%d%d%d%-%d%d%-%d%d") or "unknown"),
    "**Status**: " .. issue_status,
    "**Author**: " .. (issue.author or "unknown"),
    "**Effort**: " .. (issue.effort or "N/A"),
  }

  if issue.quickFixAvailable then
    table.insert(lines, "**Quick Fix**: Available")
  end

  if #issue.flows > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Flows")

    for i, flow in ipairs(issue.flows) do
      table.insert(lines, "- Flow " .. i .. ": " .. (flow.description or "N/A"))
    end
  end

  local width = math.min(80, vim.o.columns - 4)
  local height = math.min(#lines + 2, vim.o.lines - 4)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
  })

  vim.keymap.set("n", "q", ":q<CR>", { buffer = buf, silent = true })
  vim.keymap.set("n", "<CR>", function()
    if issue.line then
      vim.api.nvim_win_close(win, true)
      vim.cmd("edit " .. file)
      vim.api.nvim_win_set_cursor(0, { tonumber(issue.line), 0 })
    end
  end, { buffer = buf, silent = true })
end

local function show_issue_titles(file, titles, issue_details)
  local has_telescope, telescope = pcall(require, "telescope.pickers")

  if has_telescope then
    telescope.new({
      prompt_title = "Issues for " .. file,
      finder = require("telescope.finders").new_table({ results = titles }),
      sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        map("i", "<CR>", function()
          if utils.table_len(issue_details) == 0 then
            return
          end

          local title = require("telescope.actions.state").get_selected_entry()[1]
          require("telescope.actions").close(prompt_bufnr)
          show_issue_details(file, issue_details[title])
        end)

        return true
      end,
    }, {}):find()
  end
end

function M.show_buffer_reports()
  local _, root = utils.load_env()
  local project_key = utils.get_sonar_project_key()

  if not root or not project_key then return end

  local file = vim.fn.expand("%:p")

  if not file or file == "" or not file:match(root) then
    vim.notify("No valid project file in buffer", vim.log.levels.WARN)
    return
  end

  file = file:gsub(root .. "/", "")

  local issues = sonar_api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&files=" .. file)
  local titles = {}
  local issue_details = {}

  for _, issue in ipairs(issues) do
    if issue.issueStatus ~= "FIXED" then
      if config.only_show_owned_issues and issue.author == git.get_user_email() then
        local title = string.format(
          "[%s] %s (Line %s)",
          issue.type == "SECURITY_HOTSPOT" and "Hotspot" or issue.type,
          issue.message,
          issue.line or "N/A")

        table.insert(titles, title)
        issue_details[title] = issue
      end
    end
  end

  if #titles == 0 then table.insert(titles, "No active issues found.") end

  show_issue_titles(file, titles, issue_details)
end

function M.show_file_reports()
  local project_key = utils.get_sonar_project_key()

  if not project_key then return end

  local files = {}
  local seen = {}
  local issues = sonar_api.get_issues_and_hotspots("componentKeys=" .. project_key)

  for _, issue in ipairs(issues) do
    if issue.issueStatus ~= "FIXED" then
      if config.only_show_owned_issues and issue.author == git.get_git_email() then
        local file = issue.component:match(project_key .. ":(.+)") or issue.component

        if not seen[file] then
          table.insert(files, file)
          seen[file] = true
        end
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
          issues = sonar_api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&files=" .. file)
          local titles = {}
          local issue_details = {}

          for _, issue in ipairs(issues) do
            if issue.issueStatus ~= "FIXED" then
              local title = string.format(
                "[%s] %s (Line %s)",
                issue.type == "SECURITY_HOTSPOT" and "Hotspot" or issue.type,
                issue.message,
                issue.line or "N/A")

              table.insert(titles, title)
              issue_details[title] = issue
            end
          end

          if #titles == 0 then titles = { "No active issues." } end

          show_issue_titles(file, titles, issue_details)
        end)
        return true
      end,
    }, {}):find()
  else
    show_reports("Files with Reports", files, {}, function(sel)
      issues = sonar_api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&files=" .. sel)
      local titles = {}
      local issue_details = {}

      for _, issue in ipairs(issues.issues) do
        if issue.issueStatus ~= "FIXED" then
          local title = string.format(
            "[%s] %s (Line %s)",
            issue.type == "SECURITY_HOTSPOT" and "Hotspot" or issue.type,
            issue.message,
            issue.line or "N/A")

          table.insert(titles, title)
          issue_details[issue] = issue
        end
      end

      if #titles == 0 then titles = { "No active issues." } end

      show_issue_titles(sel, titles, issue_details)
    end, nil, false)
  end
end

return M
