return {
    "nvim-telescope/telescope.nvim",
    version = "*",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local telescope = require("telescope")
        telescope.setup({
            defaults = {
                -- Search starts from the cwd nvim was launched in by default.
                -- Hide common noise from results.
                file_ignore_patterns = { "%.git/", "node_modules/", "%.cache/" },
                layout_strategy = "horizontal",
                layout_config = { prompt_position = "top" },
                sorting_strategy = "ascending",
            },
        })

        local builtin = require("telescope.builtin")
        vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files (cwd)" })
        vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Live grep (cwd)" })
        vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Find buffer" })
        vim.keymap.set("n", "<leader>fr", builtin.oldfiles,   { desc = "Recent files" })
        vim.keymap.set("n", "<leader>fh", builtin.help_tags,  { desc = "Help tags" })
    end,
}
