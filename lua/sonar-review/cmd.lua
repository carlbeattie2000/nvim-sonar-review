local utils = require("sonar-review.utils")

local M = {}

---comment
---@param verbose boolean
function M.scan(verbose)
	vim.notify("Scan Started")
	local root = utils.find_project_root() or ("" .. "/.")
	local project_key = utils.get_sonar_project_key()

	if not project_key then
		return
	end

	local sonar_token, sonar_address = utils.get_env_value("SONAR_TOKEN"), utils.get_env_value("SONAR_ADDRESS")

	if not sonar_token or not sonar_address then
		return
	end

	local cmd = string.format(
		"sonar-scanner -Dproject.settings=%s -Dsonar.host.url=%s -Dsonar.token=%s",
		utils.get_sonar_properties_file_path(),
		sonar_address,
		sonar_token
	)
	local sonar_scan_output = vim.fn.system(cmd)

	if verbose then
		vim.notify(sonar_scan_output)
	else
		vim.notify("Scaning " .. root .. " has finished")
	end

	utils.clear_quickfix_list()
end

---comment
---@param verbose boolean
function M.scan_async(verbose)
	if not utils.neovim_is_above_or_equal_version("0.10.0") then
		vim.notify("You need neovim 0.10.* or higher to use vim.system", vim.log.levels.INFO)
		return
	end

	local function on_exit(obj)
		if verbose then
			vim.print(obj.stdout)
		end

		vim.print("Scan Completed with exit code: " .. tostring(obj.code))
	end

	local root = utils.find_project_root() or ("" .. "/.")
	local project_key = utils.get_sonar_project_key()

	if not project_key then
		return
	end

	local sonar_token, sonar_address = utils.get_env_value("SONAR_TOKEN"), utils.get_env_value("SONAR_ADDRESS")

	if not sonar_token or not sonar_address then
		return
	end

	---@type string[]
	local cmd = {
		"sonar-scanner",
		string.format("-Dproject.settings=%s", utils.get_sonar_properties_file_path()),
		string.format("-Dsonar.host.url=%s", sonar_address),
		string.format("-Dsonar.token=%s", sonar_token),
	}

	vim.system(cmd, { text = false }, on_exit)

	vim.print("Scan Started")
end

return M
