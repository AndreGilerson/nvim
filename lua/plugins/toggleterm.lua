return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function ()
        -- State for cycling between numbered terminals
        local term_active = 1
        local term_max = 1

        local function switch_terminal(id)
            local terms = require("toggleterm.terminal").get_all()
            for _, t in ipairs(terms) do
                if t:is_open() then t:close() end
            end
            vim.cmd(id .. "ToggleTerm direction=horizontal")
            term_active = id
            if id > term_max then term_max = id end
        end

        local function next_terminal()
            if term_max == 1 then return end
            local next_id = term_active + 1
            if next_id > term_max then next_id = 1 end
            switch_terminal(next_id)
        end

        local function prev_terminal()
            if term_max == 1 then return end
            local prev_id = term_active - 1
            if prev_id < 1 then prev_id = term_max end
            switch_terminal(prev_id)
        end

        -- Winbar: lists all open numbered terminals with the active one highlighted.
        -- Exposed as a global so the winbar string can call it via v:lua.
        _G.toggleterm_winbar = function()
            local terms = require("toggleterm.terminal").get_all()
            table.sort(terms, function(a, b) return (a.id or 0) < (b.id or 0) end)
            local current_buf = vim.api.nvim_get_current_buf()
            local parts = {}
            for _, t in ipairs(terms) do
                local label = " Term " .. (t.id or "?") .. " "
                if t.bufnr == current_buf then
                    table.insert(parts, "%#TabLineSel#" .. label)
                else
                    table.insert(parts, "%#TabLine#" .. label)
                end
            end
            table.insert(parts, "%#TabLineFill#")
            return table.concat(parts, "")
        end

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
                vim.opt_local.winbar = "%{%v:lua.toggleterm_winbar()%}"
            end,
        })

        -- Inside toggleterm buffers: let <Esc>/jk exit terminal mode, and override
        -- H/L in normal mode to cycle terminals (instead of the global buffer cycle).
        vim.api.nvim_create_autocmd("TermOpen", {
            pattern = "term://*#toggleterm#*",
            callback = function(args)
                local opts = { buffer = args.buf }
                vim.keymap.set("t", "<esc>", [[<C-\><C-n>]], opts)
                vim.keymap.set("t", "jk", [[<C-\><C-n>]], opts)
                vim.keymap.set("n", "H", prev_terminal,
                    vim.tbl_extend("force", opts, { desc = "Previous terminal" }))
                vim.keymap.set("n", "L", next_terminal,
                    vim.tbl_extend("force", opts, { desc = "Next terminal" }))
            end,
        })

        -- Leader keymaps still available globally
        vim.keymap.set("n", "<leader>tn", function()
            switch_terminal(term_max + 1)
        end, { desc = "New terminal" })
        vim.keymap.set("n", "<leader>tl", next_terminal, { desc = "Next terminal" })
        vim.keymap.set("n", "<leader>th", prev_terminal, { desc = "Previous terminal" })
    end
}
