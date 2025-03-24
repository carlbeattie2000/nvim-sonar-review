local M = {}

-- Requires telescope for any of this file to be valid
-- Should not call any of these functions unless you know what you're doing
-- This file is only required when telescope has been confirmed to be installed

local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require "telescope.previewers"
local entry_display = require("telescope.pickers.entry_display")
local conf = require("telescope.config").values

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

return M
