return {
    'akinsho/toggleterm.nvim',
    version = "*",
    config = function ()
        require("toggleterm").setup({
            open_mapping = [[<c-_>]],
            hide_numers = true,
            direction = 'float',
            close_on_exit = true,
            auto_scroll = true
        })
    end
}

