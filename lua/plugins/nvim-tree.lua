local function on_attach(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)

    local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end
    
    -- Define nvim-tree specific keymappings
    vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
    vim.keymap.set("n", "v", api.node.open.vertical, opts("Open in new vertical split"))
    vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close directory"))
    vim.keymap.set("n", "<c-e>", ":NvimTreeToggle<CR>", opts("Toggle nvim-tre"))
end


return {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        require("nvim-tree").setup({
            sort = {
                sorter = "case_sensitive",
            },
            renderer = {
                group_empty = true,
            },
            filters = {
                dotfiles = true,
            },
            on_attach = on_attach,
        })
    end,
}
