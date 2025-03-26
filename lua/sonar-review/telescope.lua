local M = {}

-- Requires telescope for any of this file to be valid
-- Should not call any of these functions unless you know what you're doing
-- This file is only required when telescope has been confirmed to be installed

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require "telescope.previewers"
local entry_display = require("telescope.pickers.entry_display")
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

---comment
---@param opts any
---@return function
function M.gen_from_issues(opts)
  opts = opts or {}

  local displayer

  if opts.is_buffer then
    displayer = entry_display.create {
      separator = " ",
      items = {
        { width = 8 },
        { remaining = true },
      },
    }
  else
    displayer = entry_display.create {
      separator = " ",
      items = {
        { width = 8 },
        { width = 25 },
        { remaining = true }
      }
    }
  end

  local make_display

  if opts.is_buffer then
    make_display = function(entry)
      return displayer {
        { entry.severity, "TelescopeResultsIdentifier" },
        { entry.message },
      }
    end
  else
    make_display = function(entry)
      return displayer {
        { entry.severity, "TelescopeResultsIdentifier" },
        { entry.filepath },
        { entry.message },
      }
    end
  end

  return function(entry)
    if not entry or not entry.filepath then
      return nil
    end

    local ordinal

    if opts.is_buffer then
      ordinal = entry.message .. " " .. entry.severity
    else
      ordinal = entry.short_path .. " " .. entry.message .. " " .. entry.severity
    end

    return {
      value = entry.filepath,
      ordinal = ordinal,
      display = make_display,
      filepath = entry.filepath,
      short_path = entry.short_path,
      message = entry.message,
      severity = entry.severity,
      lnum = entry.textRange.startLine,
      textRange = entry.textRange,
      status = entry.status,
      effort = entry.effort,
      debt = entry.debt,
      author = entry.author
    }
  end
end

---comment
---@param opts any
---@return table
M.sonar_previewer = function(opts)
  return previewers.new_buffer_previewer {
    title = "Issue Preview",
    define_preview = function(self, entry, status)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})

      local lines = {
        "Issue: " .. entry.message,
        "Severity: " .. entry.severity,
        "Status: " .. entry.status,
        "Effort: " .. entry.effort,
        "Debt: " .. entry.debt,
        "Author: " .. entry.author,
        ""
      }

      local ok, file_lines = pcall(vim.fn.readfile, entry.filepath)
      if not ok then
        table.insert(lines, "Error: Could not read file " .. entry.filepath)
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        return
      end

      local start_line = math.max(1, entry.textRange.startLine - 2)       -- 2 lines before
      local end_line = math.min(#file_lines, entry.textRange.endLine + 2) -- 2 lines after

      for i = start_line, end_line do
        local prefix = (i >= entry.textRange.startLine and i <= entry.textRange.endLine) and ">> " or "   "
        table.insert(lines, prefix .. i .. ": " .. (file_lines[i] or ""))
      end

      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  }
end

---comment
---@param entry any
---@return { bufnr: string | nil, filename: string, lnum: number, text: string }
local entry_to_qf = function(entry)
  return {
    bufnr = entry.bufnr,
    filename = entry.short_path,
    lnum = entry.lnum,
    text = entry.message
  }
end

---comment
---@param prompt_bufnr any
---@param mode " " | "a"
local send_selected_to_qflist_action = function(prompt_bufnr, mode)
  local picker = action_state.get_current_picker(prompt_bufnr)

  local qf_entries = {}
  for _, entry in ipairs(picker:get_multi_selection()) do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  local prompt = picker:_get_prompt()
  actions.close(prompt_bufnr)

  vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
  local qf_title = string.format("[[%s (%s)]]", picker.prompt_title, prompt)

  vim.fn.setqflist(qf_entries, mode)
  vim.fn.setqflist({}, "a", { title = qf_title })
  vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end

---comment
---@param prompt_bufnr any
---@param mode " " | "a"
local send_all_to_qflist_action = function(prompt_bufnr, mode)
  local picker = action_state.get_current_picker(prompt_bufnr)
  local manager = picker.manager

  local qf_entries = {}
  for entry in manager:iter() do
    table.insert(qf_entries, entry_to_qf(entry))
  end

  local prompt = picker:_get_prompt()
  actions.close(prompt_bufnr)

  vim.api.nvim_exec_autocmds("QuickFixCmdPre", {})
  local qf_title = string.format("[[%s (%s)]]", picker.prompt_title, prompt)

  vim.fn.setqflist(qf_entries, mode)
  vim.fn.setqflist({}, "a", { title = qf_title })
  vim.api.nvim_exec_autocmds("QuickFixCmdPost", {})
end

---comment
---@param prompt_bufnr any
---@param mode " " | "a"
local function smart_send(prompt_bufnr, mode)
  local picker = action_state.get_current_picker(prompt_bufnr)

  if #picker:get_multi_selection() > 0 then
    send_selected_to_qflist_action(prompt_bufnr, mode)
  else
    send_all_to_qflist_action(prompt_bufnr, mode)
  end
end

---comment
---@param opts any
---@param type "buffer" | nil
M.show_issues = function(opts, type)
  opts = opts or {}

  if type == "buffer" then
    opts.is_buffer = true
  end

  for _, issue in ipairs(opts.issues) do
    local short_path = issue.component:gsub(opts.project_key .. ":", "")
    local filepath = opts.root .. "/" .. short_path
    issue.filepath = filepath
    issue.short_path = short_path
  end

  opts = opts or {}
  opts.is_buffer = true
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, M.gen_from_issues(opts))
  opts.previewer = M.sonar_previewer(opts)

  pickers.new(opts, {
    prompt_title = "Sonar Issues - [Current Buffer]",
    finder = finders.new_table({ results = opts.issues, entry_maker = opts.entry_maker }),
    previewer = opts.previewer,
    sorter = conf.file_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)

        if selection then
          if not type or type ~= "buffer" then
            vim.cmd("edit " .. vim.fn.fnameescape(selection.filepath))
          end
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end
      end)
      actions.send_to_qflist:replace(function()
        send_all_to_qflist_action(prompt_bufnr, " ")
      end)
      actions.add_to_qflist:replace(function()
        send_all_to_qflist_action(prompt_bufnr, "a")
      end)
      actions.send_selected_to_qflist:replace(function()
        send_selected_to_qflist_action(prompt_bufnr, " ")
      end)
      actions.add_selected_to_qflist:replace(function()
        send_selected_to_qflist_action(prompt_bufnr, "a")
      end)
      actions.smart_send_to_qflist:replace(function()
        smart_send(prompt_bufnr, " ")
      end)
      actions.smart_add_to_qflist:replace(function()
        smart_send(prompt_bufnr, "a")
      end)

      return true
    end
  }):find()
end

return M
