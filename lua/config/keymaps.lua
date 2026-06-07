-- Helper function to easiert create new keymappings
function map(mode, lhs, rhs, opts)
    local options = { noremap = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

-- Global, non plugin specific keymaps
-- jk escape: time-based (independent of timeoutlen) so we can keep timeoutlen high
-- for leader chords while jk stays snappy.
local jk_window_ms = 150
local last_j_ms = 0
vim.keymap.set("i", "j", function()
    last_j_ms = vim.loop.now()
    return "j"
end, { expr = true, desc = "Insert j (tracks time for jk escape)" })
vim.keymap.set("i", "k", function()
    if (vim.loop.now() - last_j_ms) < jk_window_ms then
        last_j_ms = 0
        return "<BS><Esc>"
    end
    return "k"
end, { expr = true, desc = "Insert k (or escape if jk pressed quickly)" })

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

-- Easier window navigation, terminal mode
map("t", "<c-h>", [[<c-\><c-n><c-w>h]], {desc = "Easier window movement, to the left"})
map("t", "<c-j>", [[<c-\><c-n><c-w>j]], {desc = "Easier window movement, to the down"})
map("t", "<c-k>", [[<c-\><c-n><c-w>k]], {desc = "Easier window movement, to the up"})
map("t", "<c-l>", [[<c-\><c-n><c-w>l]], {desc = "Easier window movement, to the right"})
map("t", "<c-/>", [[<c-\><c-n>:ToggleTerm<CR>]], {desc = "Toggle terminal from terminal mode"})

-- Move by visual lines on wrapped lines instead of actual document lines.
-- A count (e.g. `5j`) still moves by real lines so motions/`relativenumber`
-- jumps keep working as expected.
local function visual_move(key)
    return function()
        return vim.v.count == 0 and ("g" .. key) or key
    end
end

for _, m in ipairs({ "n", "v" }) do
    vim.keymap.set(m, "j", visual_move("j"), { expr = true, desc = "Down by visual line" })
    vim.keymap.set(m, "k", visual_move("k"), { expr = true, desc = "Up by visual line" })
    vim.keymap.set(m, "<Down>", visual_move("j"), { expr = true, desc = "Down by visual line" })
    vim.keymap.set(m, "<Up>", visual_move("k"), { expr = true, desc = "Up by visual line" })

    -- Start/end of visual line for home/end style keys
    vim.keymap.set(m, "0", "g0", { desc = "Start of visual line" })
    vim.keymap.set(m, "^", "g^", { desc = "First non-blank of visual line" })
    vim.keymap.set(m, "$", "g$", { desc = "End of visual line" })
    vim.keymap.set(m, "<Home>", "g<Home>", { desc = "Start of visual line" })
    vim.keymap.set(m, "<End>", "g<End>", { desc = "End of visual line" })
end

-- Insert mode arrows follow visual lines too
vim.keymap.set("i", "<Down>", "<C-o>gj", { desc = "Down by visual line" })
vim.keymap.set("i", "<Up>", "<C-o>gk", { desc = "Up by visual line" })
vim.keymap.set("i", "<Home>", "<C-o>g<Home>", { desc = "Start of visual line" })
vim.keymap.set("i", "<End>", "<C-o>g<End>", { desc = "End of visual line" })

-- Easier window navigation, normal mode
map("n", "L", ":bnext 1<CR>", {desc = "Switch to next buffer"})
map("n", "H", ":bprevious 1<CR>", {desc = "Switch to previous buffer"})

-- Nvim-tree specific
map("n", "<c-e>", ":NvimTreeToggle<CR>")

-- Quit all
map("n", "<leader>qq", ":qa<CR>", {desc = "Quit all"})
