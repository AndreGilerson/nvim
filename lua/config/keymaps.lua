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

-- Easier window navigation, normal mode
map("n", "<c-h>", "<c-w>h", {desc = "Easier window movement, to the left"})
map("n", "<c-j>", "<c-w>j", {desc = "Easier window movement, to the down"})
map("n", "<c-k>", "<c-w>k", {desc = "Easier window movement, to the up"})
map("n", "<c-l>", "<c-w>l", {desc = "Easier window movement, to the right"})

-- Easier window navigation, insert mode
map("i", "<c-h>", "<esc><c-w>h", {desc = "Easier window movement, to the left"})
map("i", "<c-j>", "<esc><c-w>j", {desc = "Easier window movement, to the down"})
map("i", "<c-k>", "<esc><c-w>k", {desc = "Easier window movement, to the up"})
map("i", "<c-l>", "<esc><c-w>l", {desc = "Easier window movement, to the right"})

-- Nvim-tree specific
map("n", "<c-e>", ":NvimTreeToggle<CR>")