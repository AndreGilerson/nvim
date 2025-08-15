-- Helper function to easiert create new keymappings
function map(mode, lhs, rhs, opts)
    local options = { noremap = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- Global, non plugin specific keymaps
map("i", "jk", "<esc>", {desc = "Easier escape inside insert mode"})

-- Nvim-tree specific
map("n", "<c-e>", ":NvimTreeToggle<CR>")