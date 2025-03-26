local yd = require 'yo-dawg'
local utils = require 'sonar-review.utils'

describe('Util functions', function()
  local nvim

  local orignal_expand_fn
  local orignal_findfile_fn
  local orignal_fnamemodify_fn
  local orignal_getcwd_fn
  local orignal_filereadable_fn
  local orignal_readfile_fn
  local orignal_version_fn
  local orignal_version_ge_fn

  before_each(function()
    nvim = yd.start()

    orignal_expand_fn = vim.fn.expand
    orignal_findfile_fn = vim.fn.findfile
    orignal_fnamemodify_fn = vim.fn.fnamemodify
    orignal_getcwd_fn = vim.fn.getcwd
    orignal_filereadable_fn = vim.fn.filereadable
    orignal_readfile_fn = vim.fn.readfile
    orignal_version_fn = vim.version
    orignal_version_ge_fn = vim.version.ge
  end)

  after_each(function()
    yd.stop(nvim)

    vim.fn.expand = orignal_expand_fn
    vim.fn.findfile = orignal_findfile_fn
    vim.fn.fnamemodify = orignal_fnamemodify_fn
    vim.fn.getcwd = orignal_getcwd_fn
    vim.fn.filereadable = orignal_filereadable_fn
    vim.fn.readfile = orignal_readfile_fn
    vim.version = orignal_version_fn
  end)

  it('Returns project root dir', function()
    vim.fn.expand = function(string)
      if string ~= "" then
        return "/example/project/dir"
      end

      return ""
    end

    vim.fn.findfile = function(file, path)
      if file and path then
        return file
      end

      return ""
    end

    vim.fn.fnamemodify = function(fileName, mods)
      return "/example/project/dir"
    end

    local root_dir = utils.find_project_root()

    assert.is.equal("/example/project/dir", root_dir)
  end)

  it('Returns project property key', function()
    utils.find_project_root = function()
      return ""
    end

    vim.fn.filereadable = function(file)
      return 1
    end

    vim.fn.readfile = function(fname)
      return { "sonar.projectKey=exampleKey" }
    end

    local project_key = utils.get_sonar_project_key()

    assert.is.equal("exampleKey", project_key)
  end)

  it('Returns project property key, but find project root is nil', function()
    utils.find_project_root = function()
      return nil
    end

    local project_key = utils.get_sonar_project_key()

    assert.is.Nil(project_key)
  end)

  it('Returns project property key, but file is not readable', function()
    utils.find_project_root = function()
      return ""
    end

    utils.filereadable = function(fname)
      return 0
    end

    local project_key = utils.get_sonar_project_key()

    assert.is.Nil(project_key)
  end)

  it('Returns project property key, but file content is invalid', function()
    utils.find_project_root = function()
      return ""
    end

    vim.fn.filereadable = function(file)
      return 1
    end

    vim.fn.readfile = function(fname)
      return { "sonar.projectXey=exampleKey" }
    end

    local project_key = utils.get_sonar_project_key()

    assert.is.Nil(project_key)
  end)

  it('Returns env file values as table', function()
    utils.find_project_root = function()
      return ""
    end

    vim.fn.filereadable = function(file)
      return 1
    end

    vim.fn.readfile = function(fileName)
      return { "exampleKey=exampleValue" }
    end

    local env = utils.load_env()
    local length = 0

    for _, _ in pairs(env) do
      length = length + 1
    end

    assert.is.equal(1, length)
    assert.is.equal(env.exampleKey, "exampleValue")
  end)

  it('Returns empty table and nil when root is nil', function()
    utils.find_project_root = function()
      return nil
    end

    local env, root = utils.load_env()
    local length = 0

    for _, _ in pairs(env) do
      length = length + 1
    end

    assert.is.equal(0, length)
    assert.is.equal(nil, root)
  end)

  it('Returns empty table if root is valid, but .env file is not found/readable', function()
    utils.find_project_root = function()
      return ""
    end

    vim.fn.filereadable = function(file)
      return 0
    end

    local env = utils.load_env()
    local length = 0

    for _, _ in pairs(env) do
      length = length + 1
    end

    assert.is.equal(0, length)
  end)

  it('Returns empty table when .env file contains no kvs', function()
    utils.find_project_root = function()
      return ""
    end

    vim.fn.filereadable = function(file)
      return 1
    end

    vim.fn.readfile = function(fileName)
      return {}
    end

    local env = utils.load_env()
    local length = 0

    for _, _ in pairs(env) do
      length = length + 1
    end

    assert.is.equal(0, length)
  end)

  ---comment
  ---@param version_str string
  local mock_version_fn = function(version_str)
    vim.version = {}

    setmetatable(vim.version, {
      __call = function()
        return version_str
      end
    })

    vim.version.ge = orignal_version_ge_fn
  end

  it('Checks if version of neovim is above required', function()
    mock_version_fn("0.9.0")
    assert.is.truthy(utils.neovim_is_above_or_equal_version({ minor = 9 }))
    assert.is.truthy(utils.neovim_is_above_or_equal_version('0.9.0'))
    mock_version_fn("0.9.3")
    assert.is.falsy(utils.neovim_is_above_or_equal_version({ minor = 9, patch = 4 }))
    assert.is.falsy(utils.neovim_is_above_or_equal_version('0.9.4'))
    mock_version_fn("0.10.0")
    assert.is.truthy(utils.neovim_is_above_or_equal_version({ minor = 10 }))
    assert.is.truthy(utils.neovim_is_above_or_equal_version('0.10.0'))
  end)
end)
