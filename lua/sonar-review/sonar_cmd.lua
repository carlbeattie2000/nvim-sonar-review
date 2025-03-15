local utils = require 'utils'

local M = {}

function M.scan()
  local project_key = utils.get_sonar_project_key()

  if not project_key then return end

  local sonar_token, sonar_address = utils.get_env_value("SONAR_TOKEN"), utils.get_env_value("SONAR_ADDRESS")

  if not sonar_token or not sonar_address then return end

  local cmd = string.format("sonar-scanner -Dsonar.projectKey=%s -Dsonar.sources=. -Dsonar.host.url=%s -Dsonar.exclusions=**/node_modules/** -Dsonar.token=%s", project_key, sonar_address, sonar_token)
  vim.fn.system({ "sh", "-c", cmd })
end

return M
