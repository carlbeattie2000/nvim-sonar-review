local M = {}

function M.get_user_email()
  local email = vim.fn.system("git config user.email")

  if not email:match("@") then
    return nil
  end

  return vim.fn.system("git config user.email"):gsub("%s+", "") or nil
end

return M
