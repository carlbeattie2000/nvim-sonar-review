# nvim-sonar-review **WIP**

A Neovim plugin for managing SonarQube reports in your editor.

**This is my first plugin for neovim, it's most likely rough around the edges, all support is welcomed.**

## Features
Optionally you can enable telescope when setting up the plugin.
Without telescope the quick fix list is populated.

```lua
require('sonar-review').setup {
    use_telescope = true
}
```

Open reports for the current file
`:lua require('sonar-review.ui').show_buffer_reports()`

Open all reports with fuzzy finder
`:lua require('sonar-review.ui').show_file_reports()`

Run sonar scanner
`:lua require('sonar-review.sonar_cmd').scan()`


## Installation
With Packer:
`use "carlbeattie2000/nvim-sonar-review"`

## Requirements
- SonarQube: Running locally or on a custom server.
- sonar-scanner cli
- Environment Variables: SONAR_TOKEN, and optionally SONAR_ADDRESS.
- Optional: telescope.nvim for a searchable UI.

## Setup
1. Install SonarQube:
   - Use Docker for a local setup: docker run -d -p 9000:9000 sonarqube
   - Visit http://localhost:9000, log in (default: admin/admin), and set a new password.

2. Scan Your Project:
   - Install sonar-scanner (e.g., brew install sonar-scanner).
   - In your project root, create sonar-project.properties:
     sonar.projectKey=[your project]
     sonar.sources=.
   - Run: sonar-scanner

3. Set Environment Variables:
    - Create a .env file in the same DIR as sonar-project.properties
    - Add `SONAR_TOKEN` and optionally `SONAR_ADDRESS`

4. Install the Plugin:
   - Add to your Packer config:
     require("packer").startup(function(use)
       use "wbthomason/packer.nvim"
       use "carlbeattie2000/nvim-sonar-review"
     end)
   - Run :PackerSync and restart Neovim.

5. Optional: Enhance with Telescope:
   - Install telescope.nvim: use "nvim-telescope/telescope.nvim"

### Optional Config
- `opts.only_show_owned_issues` - Show only issues that you authored
- `opts.include_security_hotspots_insecure` - Show hotspot issues, requires greater permissions and can provide
sensitive information.


### Running tests
Running tests: (luarocks path --lua-version 5.1 --bin) && busted --run unit

#### TODO
- Rewrite UI + testing for UI functions
- Jump to next/prev issues in current buffer
- Jump to next/prev across all buffers
- Open window with full details about current issue

Please if this is useful in anyway and you feel like a feature is missing, or a current feature is implemented incorrectly; create an issue.
