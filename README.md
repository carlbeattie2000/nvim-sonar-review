# nvim-sonar-review **WIP**

A Neovim plugin for managing SonarQube reports in your editor.

**This is my first plugin for neovim, it's most likely rough around the edges, all support is welcomed.**

## Features
- <leader>br: Show reports for the current buffer.
- <leader>cr: View commit-based reports with read tracking.
- <leader>fr: Search files and see their reports across commits.
- <leader>d: Dismiss reports.

## Installation
With Packer:
use "carlbeattie2000/nvim-sonar-review"

## Requirements
- SonarQube: Running locally or on a custom server.
- Environment Variables: SONAR_USER, SONAR_PASS, and optionally SONAR_ADDRESS.
- Optional: telescope.nvim for a searchable UI.

## Setup
1. Install SonarQube:
   - Use Docker for a local setup: docker run -d -p 9000:9000 sonarqube:lts-community
   - Visit http://localhost:9000, log in (default: admin/admin), and set a new password.

2. Scan Your Project:
   - Install sonar-scanner (e.g., brew install sonar-scanner).
   - In your project root, create sonar-project.properties:
     sonar.projectKey=myproject
     sonar.sources=.
   - Run: sonar-scanner

3. Set Environment Variables:
   - Add to your shell config (e.g., ~/.bashrc or ~/.zshrc):
     export SONAR_USER="admin"
     export SONAR_PASS="your-new-password"
     export SONAR_ADDRESS="http://localhost:9000"  # Optional, defaults to this if unset
   - Reload shell: source ~/.bashrc
   - Note: Use SONAR_ADDRESS to point to a custom SonarQube server (e.g., http://your-server:9000).

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
- <leader>d: Dismiss a report to remove it.
