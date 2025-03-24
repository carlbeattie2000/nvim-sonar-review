local sonar_review = require 'sonar-review'
local utils = require 'sonar-review.utils'
local git = require 'sonar-review.git'
local sonar_api = require 'sonar-review.sonar_api'
local sonar_telescope = require "sonar-review.telescope"

local M = {}

local config = sonar_review.get_config()

local show_buffer_reports_telescope = function(opts)
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  local _, finders = pcall(require, 'telescope.finders')
  local _, conf = pcall(require, 'telescope.config')
  local _, actions = pcall(require, 'telescope.actions')
  local _, action_state = pcall(require, 'telescope.actions.state')


  if not has_telescope then
    return false
  end

  opts = opts or {}

  for _, issue in ipairs(opts.issues) do
    local short_path = issue.component:gsub(opts.project_key .. ":", "")
    local filepath = opts.root .. "/" .. short_path
    issue.filepath = filepath
    issue.short_path = short_path
  end

  opts = opts or {}
  opts.is_buffer = true
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, sonar_telescope.gen_from_issues(opts))
  opts.previewer = sonar_telescope.sonar_previewer(opts)

  pickers.new(opts, {
    prompt_title = "Sonar Issues - [Current Buffer]",
    finder = finders.new_table({ results = opts.issues, entry_maker = opts.entry_maker }),
    previewer = opts.previewer,
    sorter = conf.values.file_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end
      end)
      return true
    end
  }):find()

  return true
end

M.show_buffer_reports = function()
  local _, root = utils.load_env()
  local project_key = utils.get_sonar_project_key()

  if not root or not project_key then return end

  local file = vim.fn.expand("%:p")

  if not file or file == "" or not file:match(root) then
    vim.notify("No valid project file found, or not valid file", vim.log.levels.ERROR)
    return
  end

  file = file:gsub(root .. "/", "")
  local issues = sonar_api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&files=" .. file .. "&ps=500")

  if not issues then
    return
  end

  issues = utils.table_filter(issues, function(item)
    return item.status ~= "CLOSED"
  end)

  if config.use_telescope and show_buffer_reports_telescope({ root = root, issues = issues, project_key = project_key }) then
    return
  end


  local quickfix_items = {}
  local bufnr = vim.api.nvim_get_current_buf()

  for _, issue in ipairs(issues) do
    table.insert(quickfix_items, {
      bufnr = bufnr,
      lnum = issue.textRange.startLine,
      end_lnum = issue.textRange.endLine,
      text = issue.message,
    })
  end

  vim.fn.setqflist({}, ' ', {
    title = "Sonar Review Issues - [Buffer Reports]",
    items = quickfix_items
  })

  vim.cmd [[botright copen]]
end

local show_file_reports_telescope = function(opts)
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  local _, finders = pcall(require, 'telescope.finders')
  local _, conf = pcall(require, 'telescope.config')
  local _, actions = pcall(require, 'telescope.actions')
  local _, action_state = pcall(require, 'telescope.actions.state')


  if not has_telescope then
    return false
  end

  opts = opts or {}

  for _, issue in ipairs(opts.issues) do
    local short_path = issue.component:gsub(opts.project_key .. ":", "")
    local filepath = opts.root .. "/" .. short_path
    issue.filepath = filepath
    issue.short_path = short_path
  end

  opts = opts or {}
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, sonar_telescope.gen_from_issues(opts))
  opts.previewer = sonar_telescope.sonar_previewer(opts)

  pickers.new(opts, {
    prompt_title = "Sonar Issues - [Files]",
    finder = finders.new_table({ results = opts.issues, entry_maker = opts.entry_maker }),
    previewer = opts.previewer,
    sorter = conf.values.file_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          vim.cmd("edit " .. vim.fn.fnameescape(selection.filepath))
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end
      end)
      return true
    end
  }):find()

  return true
end

M.show_file_reports = function()
  local _, root = utils.load_env()
  local project_key = utils.get_sonar_project_key()

  if not root or not project_key then return end

  local issues = sonar_api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&ps=500")

  if not issues then
    return
  end

  issues = utils.table_filter(issues, function(item)
    return item.status ~= "CLOSED"
  end)

  if config.use_telescope and show_file_reports_telescope({ root = root, issues = issues, project_key = project_key }) then
    return
  end


  local quickfix_items = {}

  for i, issue in ipairs(issues) do
    local file_path = root .. "/" .. issue.component:gsub(project_key .. ":", "")
    table.insert(quickfix_items, {
      filename = file_path,
      lnum = issue.textRange.startLine,
      end_lnum = issue.textRange.endLine,
      text = issue.message,
    })
  end

  vim.fn.setqflist({}, ' ', {
    title = "Sonar Review Issues - [File Reports]",
    items = quickfix_items
  })

  vim.cmd [[botright copen]]
end

return M
