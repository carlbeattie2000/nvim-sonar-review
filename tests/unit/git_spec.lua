local yd = require 'yo-dawg'
local git = require'sonar-review.git'

describe('Git CLI functions', function ()
  local nvim

  local original_system_fn

  before_each(function ()
    nvim = yd.start()
  end)

  after_each(function ()
    yd.stop(nvim)

    vim.fn.system = original_system_fn
  end)

  it('Returns expected git email from user config', function ()
    vim.fn.system = function (cmd)
      if cmd == "git config user.email" then
        return "test@example.com  "
      end

      return ""
    end

    local git_user_email = git.get_user_email()

    assert.is.equal("test@example.com", git_user_email)
  end)

  it('Returns nil when git is not installed or git config is not set', function ()
    vim.fn.system = function(cmd)
      if cmd == "git config user.email" then
        return "zsh: command not found"
      end

      return ""
    end

    local git_user_email = git.get_user_email()

    assert.is.equal(nil, git_user_email)
  end)
end)
