# nvim-sonar-review
> Unstable --- Breaking changes and bugs are common

## Installation
<details>
  <summary>Packer</summary>

  ```lua
    use "carlbeattie2000/nvim-sonar-review"
  ```
</details>

<details open>
  <summary>Lazy</summary>

  ```lua
    -- init.lua
    {
        "carlbeattie2000/nvim-sonar-review"
    }

    -- plugins/sonar-review.lua
    return {
        "carlbeattie2000/nvim-sonar-review"
        -- If you would like to use telescope
        dependencies = { 'nvim-telescope/telescope.nvim' }
    }
  ```
</details>

## Usage
```lua
-- UI Displaying Issues
local sonar_ui = require("sonar-review.ui")
vim.keymap.set("n", "some_keybind", sonar_ui.show_buffer_reports())
vim.keymap.set("n", "some_keybind", sonar_ui.show_file_reports())

-- Sonar Commands
local sonar_cmd = require("sonar-review.cmd")
vim.keymap.set("n", "some_keybind", sonar_cmd.scan())

-- You can also run sonar-scanner async, requires Neovim v0.10.0+
vim.keymap.set("n", "some_keybind", sonar_cmd.scan_async())
```


## Configuration
##### Neovim
```lua
require("sonar-review").setup {
    use_telescope = false, -- Use telescope instead of quickfix list
    include_security_hotspots_insecure = false, -- Show hotspot issues, requires high permissions.
    only_show_owned_options = false, -- Only show issues you authored
    page_size = 500 -- Set limit of issues returned from API
}
```
##### Local Project
You will need to create two files at the root of your project.

First a `.env` file with two values:
```env
SONAR_TOKEN=??
SONAR_ADDRESS=??
```

You will also need a `sonar-project.properties` file containing the following:
```bash
sonar.projectKey=??
sonar.sources=./
sonar.exclusions=??
```

You can read more about sonar-project.properties file [here](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/scanners/sonarscanner/)
## Requirements
 - [SonarQube](https://docs.sonarsource.com/sonarqube-server/10.8/)
 - [sonar-scanner](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/scanners/sonarscanner/)
 - [Telescope](https://github.com/nvim-telescope/telescope.nvim) <span style="font-size: 12px; color: #ccc;">Optional</span>

### SonarQube Installation
###### SonarQube Server
```bash
docker run -d -p 9000:9000 sonarqube
```
###### sonar-scanner 
```bash
# Example, please refer to the offical documentation
brew install sonar-scanner
```
### Running tests
Running tests: (luarocks path --lua-version 5.1 --bin) && busted --run unit

#### TODO
- Open window with full details about current issue

Please if this is useful in anyway and you feel like a feature is missing, or a current feature is implemented incorrectly; create an issue.
