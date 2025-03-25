local M = {}

M.set_files_issues_quickfix_list = function(opts)
  opts = opts or { issues = {}, project_key = '', root = '' }

  if #opts.issues == 0 then
    return
  end

  local quickfix_items = {}

  for _, issue in ipairs(opts.issues) do
    local file_path = opts.root .. "/" .. issue.component:gsub(opts.project_key .. ":", "")
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

M.set_buffer_issues_quickfix_list = function(opts)
  opts = opts or { issues = {} }

  if #opts.issues == 0 then
    return
  end

  local quickfix_items = {}

  local bufnr = vim.api.nvim_get_current_buf()

  for _, issue in ipairs(opts.issues) do
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

return M
