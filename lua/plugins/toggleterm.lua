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
    end
}

