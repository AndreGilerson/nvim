return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function ()
        require("toggleterm").setup({
            open_mapping = [[<c-/>]],
            hide_numers = true,
            direction = 'horizontal',
            size = 15,
            close_on_exit = true,
            auto_scroll = true,
            on_open = function()
                vim.cmd("wincmd J")
                vim.cmd("setlocal winfixheight")
            end,
        })

        -- Inside toggleterm buffers, let <Esc> and jk exit terminal mode.
        -- Scoped to toggleterm only so other :terminal usage keeps Esc intact
        -- for shell apps (fzf, less, vim-in-shell, etc.).
        vim.api.nvim_create_autocmd("TermOpen", {
            pattern = "term://*#toggleterm#*",
            callback = function(args)
                local opts = { buffer = args.buf }
                vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
                vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
            end,
        })
    end
}

