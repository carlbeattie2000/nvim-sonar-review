local sonar_review = require 'sonar-review'
local utils = require 'sonar-review.utils'
local git = require 'sonar-review.git'
local api = require 'sonar-review.api'

local M = {}

local config = sonar_review.get_config()

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
  local issues = api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&files=" .. file .. "&ps=500")

  if not issues then
    return
  end

  issues = utils.table_filter(issues, function(item)
    if config.only_show_owned_options and item.author ~= git.get_user_email() then
      return false
    end

    return item.status ~= "CLOSED"
  end)

  local has_telescope, _ = pcall(require, "telescope")
  if config.use_telescope and has_telescope then
    require("sonar-review.telescope").show_buffer_issues({ root = root, issues = issues, project_key = project_key })
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

M.show_file_reports = function()
  local _, root = utils.load_env()
  local project_key = utils.get_sonar_project_key()

  if not root or not project_key then return end

  local issues = api.get_issues_and_hotspots("componentKeys=" .. project_key .. "&ps=500")

  if not issues then
    return
  end

  issues = utils.table_filter(issues, function(item)
    if config.only_show_owned_options and item.author ~= git.get_user_email() then
      return false
    end

    return item.status ~= "CLOSED"
  end)

  local has_telescope, _ = pcall(require, "telescope")
  if config.use_telescope and has_telescope then
    require("sonar-review.telescope").show_file_issues({ root = root, issues = issues, project_key = project_key })
    return
  end

  local quickfix_items = {}

  for _, issue in ipairs(issues) do
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
