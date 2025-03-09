if vim.g.loaded_sonar_review then return end
vim.g.loaded_sonar_review = 1

local sonar = require("sonar-review")

vim.keymap.set("n", "<leader>br", sonar.show_buffer_reports, { desc = "Buffer Reports" })
vim.keymap.set("n", "<leader>fr", sonar.show_file_reports, { desc = "File Reports" })
