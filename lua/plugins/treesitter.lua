return {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local parsers = {
            "lua", "vim", "vimdoc",
            "nix",
            "python",
            "bash",
            "json", "yaml", "toml",
            "markdown", "markdown_inline",
        }

        require("nvim-treesitter").install(parsers)

        local filetypes = {
            "lua", "vim", "help",
            "nix",
            "python",
            "bash", "sh",
            "json", "yaml", "toml",
            "markdown",
        }

        vim.api.nvim_create_autocmd("FileType", {
            pattern = filetypes,
            callback = function(args)
                local ok = pcall(vim.treesitter.start, args.buf)
                if ok then
                    vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end
            end,
        })
    end,
}
