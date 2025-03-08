local M = {}

local read_file = vim.fn.stdpath("cache") .. "/sonar-review-read.json"
local dismissed_file = vim.fn.stdpath("cache") .. "/sonar-review-dismissed.json"

local function load_state(file)
  if vim.fn.filereadable(file) == 1 then
    return vim.fn.json_decode(table.concat(vim.fn.readFile(file), "\n")) or {}
  end
end

local function save_state(state, file)
  vim.fn.writefile({vim.fn.json_encode(state)}, file)
end

local function get_issues(query)
  local user = os.getenv("SONAR_USER") or "admin"
  local pass = os.getenv("SONAR_PASS") or "admin"
  local sonar_address = os.getenv("SONAR_ADDRESS") or "http://localhost:9000"

  local cmd = string.format('curl -s -u %s:%s "%s/api/issues/search?%s"', user, pass, sonar_address, query)
  local result = vim.fn.system(cmd)

  return vim.fn.json_decode(result) or { issues = {} }
end

local function show_reports(title, lines, issue_keys, on_select, on_dismiss, use_telescope)
  local has_telescope, telescope = pcall(require, "telescope.pickers")

  if use_telescope and has_telescope then
    telescope.new({
      prompt_title = title,
      finder = require("telescope.finders").new_table({ results = lines }),
      sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
      attach_mappings = function (prompt_bufnr, map)
        map("i", "<CR>", function ()
          local sel = require("telescope.actions.state").get_selected_entry()[1]
          if on_select then on_select(sel, issue_keys[sel]) end
          require("telescope.actions").close(prompt_bufnr)
        end)
        map("i", "<leader>d", function ()
          local sel = require("telescope.actions.state").get_selected_entry()[1]
          if on_dismiss and issue_keys[sel] then
            on_dismiss(sel, issue_keys[sel])
            require("telescope.actions").close(prompt_bufnr)
          end
        end)
        return true
      end,
    }, {}):find()
  else
    vim.cmd("vsplit | enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { title, "" })
    vim.api.nvim_buf_set_lines(0, -1, -1, false, lines)
    vim.bo.filetype = "markdown"
    vim.bo.buftype = "nofile"
    vim.keymap.set("n", "<CR>", function ()
      local sel = vim.fn.getline(".")
      if on_select then on_select(sel, issue_keys[sel]) end
      vim.cmd("wincmd q")
    end, { buffer = 0 })
    vim.keymap.set("n", "<leader>d", function ()
      local sel = vim.fn.getline(".")
      if on_dismiss and issue_keys[sel] then on_dismiss(sel, issue_keys[sel]) end
    end, { buffer = 0 })
  end
end

function M.show_buffer_reports()
  local file = vim.fn.expand("%:p"):gsub(vim.fn.getcwd() .. "/", "")
  if not file or file == "" then
    vim.notify("No file in current buffer", vim.log.levels.WARN)
    return
  end

  local dismissed = load_state(dismissed_file)
  local read = load_state(read_file)
  local issues = get_issues("componentKeys=myproject&files=" .. file)
  local lines = {}
  local issue_keys = {}

  for _, issue in ipairs(issues.issues) do
    if not dismissed[issue.key] then
      local is_read = read[issue.key] and "[X]" or "[  ]"
      local line = string.format(
      "%s - %s - %s %s (Line %s)",
      issue.revision or "unknown",
      issue.creationDate:match("^%d%d%d%d%-%d%d%-%d%d"),
      is_read,
      issue.message,
      issue.line or "N/A"
      )

      table.insert(lines, line)
      issue_keys[line] = issue.key
    end
  end

  if #lines == 0 then table.insert(lines, "No active issues found.") end

  show_reports("Reports for " .. file, lines, issue_keys,
  function (_, key)
    local file_line = vim.fn.getline("."):match("Line (%d+)")

    if file_line then
      vim.api.nvim_win_set_cursor(0, { tonumber(file_line), 0 })
    end

    if key then
      read[key] = true
      save_state(read, read_file)
    end
  end,
  function (_, key)
    dismissed[key] = true
    read[key] = true

    save_state(dismissed, dismissed_file)
    save_state(read, read_file)
    M.show_buffer_reports()
  end,
  false)
end

function M.setup(opts) end

return M
