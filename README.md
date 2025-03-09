# nvim-sonar-review **WIP**

A Neovim plugin for managing SonarQube reports in your editor.

**This is my first plugin for neovim, it's most likely rough around the edges, all support is welcomed.**

## Features
- <leader>br: Show reports for the current buffer.
- <leader>fr: Search files and see their reports across commits.
- <leader>d: Dismiss reports.

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
   - Install telescope.nvim:
     use "nvim-telescope/telescope.nvim"
   - When present, <leader>cr and <leader>fr use Telescope for a fuzzy-searchable, interactive UI. Without it, a basic buffer UI is used.

## Usage
- <leader>br: Reports for the current file.
- <leader>fr: Search files with issues, then view reports.

### Optional Config
`opts.only_show_owned_issues` - Show only issues that you authored
`opts.include_security_hotspots_insecure` - Show hotspot issues, requires greater permissions and can provide
sensitive information.
