local sonarReview = require 'sonar-review'
local utils = require 'sonar-review.utils'

local M = {}

function M.get_hotspots(query)
  if not query then return {} end

  local env, _ = utils.load_env()
  local token = env.SONAR_TOKEN or "admin"
  local sonar_address = os.getenv("SONAR_ADDRESS") or "http://localhost:9000"

  if not env or not token or not sonar_address then
    vim.notify("Could not get required enviroment variables.", vim.log.levels.INFO)
    return {}
  end

  local hotspot_query = query:gsub("componentKeys=", "project=")
  local cmd = string.format("curl -s --max-time 2 -u %s: '%s/api/hotspots/search?%s'", token, sonar_address,
    hotspot_query)
  local result = vim.fn.system({ "sh", "-c", cmd })
  local ok, decoded = pcall(vim.fn.json_decode, result)

  if decoded.errors or not ok then
    return nil
  end

  return ok and decoded.hotspots or {}
end

function M.get_issues(query)
  if not query then return {} end

  local env = utils.load_env()
  local token = env.SONAR_TOKEN or "admin"
  local sonar_address = os.getenv("SONAR_ADDRESS") or "http://localhost:9000"

  if not env or not token or not sonar_address then
    vim.notify("Could not get required enviroment variables.", vim.log.levels.INFO)
    return {}
  end

  local cmd = string.format('curl -s --max-time 2 -u %s: "%s/api/issues/search?%s"', token, sonar_address, query)
  local result = vim.fn.system({ "sh", "-c", cmd })
  local ok, decoded = pcall(vim.fn.json_decode, result)

  if not ok then
    return nil
  end

  return ok and decoded.issues or {}
end

function M.get_issues_and_hotspots(query)
  local config = sonarReview.get_config()
  local issues = M.get_issues(query)

  if not issues then
    vim.notify("Issue fetching results from sonar server.", vim.log.levels.ERROR)
    return {}
  end

  if not config.include_security_hotspots_insecure then
    return issues
  end

  local hotspots = M.get_hotspots(query)
  local combined_issues = {}

  for _, issue in ipairs(issues) do table.insert(combined_issues, issue) end

  if hotspots then
    for _, issue in ipairs(hotspots) do table.insert(combined_issues, issue) end
  end

  return combined_issues
end

return M
