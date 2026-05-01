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

local image_exts = {
    jpg = true, jpeg = true, png = true, gif = true, bmp = true,
    webp = true, tiff = true, tif = true, svg = true, ico = true,
    avif = true, heic = true,
}

local function is_image(path)
    local ext = path:match("%.([^%.]+)$")
    return ext ~= nil and image_exts[ext:lower()] == true
end

local function on_attach(bufnr)
    local api = require("nvim-tree.api")
    api.config.mappings.default_on_attach(bufnr)

    local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    local function open_smart()
        local node = api.tree.get_node_under_cursor()
        if node and node.type == "file" and is_image(node.absolute_path) then
            vim.fn.jobstart({ "xdg-open", node.absolute_path }, { detach = true })
            return
        end
        if not has_editor_window() then
            -- No editor window exists — create an empty one to the right of
            -- the tree so the terminal at the bottom isn't disturbed and
            -- nvim-tree's normal open flow has a window to target.
            local tree_win = vim.api.nvim_get_current_win()
            local tree_width = vim.api.nvim_win_get_width(tree_win)
            vim.cmd("rightbelow vnew")
            vim.api.nvim_set_current_win(tree_win)
            vim.api.nvim_win_set_width(tree_win, tree_width)
        end
        api.node.open.edit()
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
