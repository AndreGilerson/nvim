return { 
    "nvim-tree/nvim-web-devicons",
    config=function() 
        require('nvim-web-devicons').setup({
            default = true,
            color_icons = true,
            strict = true,
        });
        vim.cmd("colorscheme kanagawa");
    end,
}