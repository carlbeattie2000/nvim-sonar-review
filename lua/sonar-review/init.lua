local git = require 'sonar-review.git'
local utils = require 'sonar-review.utils'

local M = {}

M.git = git
M.utils = utils

local DefaultConfig = {
  only_show_owned_options = false,
  include_security_hotspots_insecure = false,
  use_telescope = false
}

local SonarReviewConfig = vim.tbl_deep_extend('force', DefaultConfig, {})

function M.setup(opts)
  if not opts then
    opts = {}
  end

  local complete_config = vim.tbl_deep_extend('force', DefaultConfig, opts)

  SonarReviewConfig = complete_config
end

function M.get_config()
  return SonarReviewConfig
end

M.setup()

return M
