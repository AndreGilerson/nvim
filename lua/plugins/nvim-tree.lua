local function has_editor_window()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype or ""
        local bt = vim.bo[buf].buftype or ""
        if ft ~= "NvimTree" and ft ~= "toggleterm" and bt ~= "terminal" then
            return true
        end
    end
    return false
end

local function on_attach(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)

    local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    local function open_smart()
        local node = api.tree.get_node_under_cursor()
        if not node then return end
        -- Directories: just expand/collapse via the default
        if node.type == "directory" then
            api.node.open.edit()
            return
        end
        if has_editor_window() then
            api.node.open.edit()
        else
            -- No editor window exists — create a vsplit beside the tree so the
            -- terminal at the bottom isn't disturbed.
            vim.cmd("vsplit " .. vim.fn.fnameescape(node.absolute_path))
        end
    end

    -- Define nvim-tree specific keymappings. These will only be active inside the nvim-tree buffer
    vim.keymap.set("n", "l", open_smart, opts("Open"))
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
            actions = {
                open_file = {
                    window_picker = {
                        exclude = {
                            filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame", "toggleterm" },
                            buftype = { "nofile", "terminal", "help" },
                        },
                    },
                },
            },
            on_attach = on_attach,
        })
    end,
}
