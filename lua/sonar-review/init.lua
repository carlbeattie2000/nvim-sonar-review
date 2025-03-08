local M = {}

local read_file = vim.fn.stdpath("cache") .. "/sonar-review-read.json"
local dismissed_file = vim.fn.stdpath("cache") .. "/sonar-review-dismissed.json"

local function read_state(file)
  if vim.fn.filereadable(file) == 1 then
    return vim.fn.json_decode(table.concat(vim.fn.readFile(file), "\n")) or {}
  end
end

local function save_state(state, file)
  vim.fn.writefile({vim.fn.json_encode(state)}, file)
end

function M.setup(opts) end

return M
