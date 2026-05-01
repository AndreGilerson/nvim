return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
        local wk = require("which-key")
        wk.setup({
            preset = "modern",
            delay = 300,
        })

        -- Group labels so the popup explains what each prefix is for
        wk.add({
            { "<leader>f", group = "find" },
            { "<leader>t", group = "terminal" },
            { "<leader>q", group = "quit" },
        })

        local function show_all()
            wk.show({ global = true })
        end

        vim.keymap.set("n", "<leader>?", show_all, { desc = "Show all keymaps" })
        vim.keymap.set("n", "<C-?>",     show_all, { desc = "Show all keymaps" })
    end,
}
