local git = require 'sonar-review.git'
local utils = require 'sonar-review.utils'

local M = {}

M.git = git
M.utils = utils

local DefaultConfig = {
  only_show_owned_options = false,
  include_security_hotspots_insecure = false,
  use_telescope = false,
  page_size = 500
}

local SonarReviewConfig = vim.tbl_deep_extend('force', DefaultConfig, {})

function M.setup(opts)
  if not opts then
    opts = {}
  end

  local complete_config = vim.tbl_deep_extend('force', DefaultConfig, opts)

  if complete_config.page_size > 500 or complete_config.page_size < 0 or type(complete_config.page_size) ~= 'number' then
    vim.notify("Invalid Config -> page_size must be a non negative number no greater than 500.", vim.log.levels.INFO)
    complete_config.page_size = 500
  end

  SonarReviewConfig = complete_config
end

function M.get_config()
  return SonarReviewConfig
end

M.setup()

return M
