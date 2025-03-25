local yd = require 'yo-dawg'
local sonarReview = require('sonar-review')
local utils = require 'sonar-review.utils'
local sonar_api = require 'sonar-review.api'
local stub = require 'luassert.stub'

describe('Queries sonar review API, getting issues and hotspots', function()
  local nvim
  local getenv_stub
  local system_stub
  local load_env_stub
  local config_stub

  before_each(function()
    nvim = yd.start()

    getenv_stub = stub(os, "getenv")
    system_stub = stub(vim.fn, "system")

    load_env_stub = stub(utils, "load_env")
    config_stub = stub(sonarReview, "get_config")

    load_env_stub.returns({ SONAR_TOKEN = "example_token" })
    getenv_stub.returns("http://localhost:9000")
    config_stub.returns({ include_security_hotspots_insecure = true })
  end)

  after_each(function()
    yd.stop(nvim)

    getenv_stub:revert()
    system_stub:revert()
    load_env_stub:revert()
    config_stub:revert()
  end)

  it('Fetches hotspots', function()
    system_stub.returns('{"hotspots":[{"key": "d6384a0c-4e52-4a4d-90a9-8c2bba2bd122"}]}')

    local hotspots = sonar_api.get_hotspots("")

    assert.is.equal(1, #hotspots)
  end)

  it('Fetches hotspots, handles invalid response', function()
    system_stub.returns("")

    local hotspots = sonar_api.get_hotspots("")

    assert.is.equal(nil, hotspots)
  end)

  it('Fetches issues', function()
    system_stub.returns('{"issues": [{"key": "cf417d4b-5d44-43db-8f7e-af1c3885ace9"}]}')

    local issues = sonar_api.get_issues("")

    assert.is.equal(1, #issues)
  end)

  it('Fetches issues, handles invalid response', function()
    system_stub.returns("")

    local issues = sonar_api.get_issues("")

    assert.is.equal(nil, issues)
  end)

  it('Fetches issues and hotspots, when config allows hotspots', function()
    system_stub.returns('{"issues": [{"key": "92bacc01-a9e2-4a8c-b953-c79dd383f0fc"}]}')
    system_stub.on_call_with({ "sh", "-c",
      "curl -s --max-time 2 -u example_token: 'http://localhost:9000/api/hotspots/search?project=example_service'" })
        .returns('{"hotspots": [{"key": "92bacc01-a9e2-4a8c-b953-c79dd383f0fc"}]}')

    local issues = sonar_api.get_issues_and_hotspots("componentKeys=example_service")

    assert.is.equal(2, #issues)
  end)
end)
