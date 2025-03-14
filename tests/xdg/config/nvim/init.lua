vim.opt.runtimepath:append(vim.fn.getcwd())

local function on_buf_win_enter(_args)
  if vim.bo.filetype ~= '' then
    vim.treesitter.start()
  end
end

vim.api.nvim_create_autocmd('BufWinEnter', { pattern = '*', callback = on_buf_win_enter })
