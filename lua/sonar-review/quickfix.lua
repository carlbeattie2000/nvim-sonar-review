local M = {}

---comment
---@param opts any
---@param search_type "buffer" | nil
M.set_qflist = function(opts, search_type)
  opts = opts or {}

  if #opts.issues == 0 then
    return
  end

  local quickfix_items = {}
  local bufnr = nil

  if search_type == "buffer" then
    bufnr = vim.api.nvim_get_current_buf()
  end

  for _, issue in ipairs(opts.issues) do
    local file_path = ''

    if search_type ~= "buffer" then
      file_path = opts.root .. "/" .. issue.component:gsub(opts.project_key .. ":", "")
    end

    table.insert(quickfix_items, {
      filename = file_path,
      lnum = issue.textRange.startLine,
      end_lnum = issue.textRange.endLine,
      text = issue.message,
      bufnr = bufnr
    })
  end

  local title = bufnr and "Sonar Review Issues - [Buffer Reports]" or "Sonar Review Issues - [File Reports]"
  vim.fn.setqflist({}, ' ', {
    title = title,
    items = quickfix_items
  })

  vim.cmd [[botright copen]]
end

return M
