return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local lspconfig = require("lspconfig")

        -- Lua: configured to know about the neovim runtime so vim.api etc.
        -- aren't flagged as undefined when editing this config.
        lspconfig.lua_ls.setup({
            settings = {
                Lua = {
                    runtime = { version = "LuaJIT" },
                    diagnostics = { globals = { "vim" } },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                    telemetry = { enable = false },
                },
            },
        })

        -- Nix
        lspconfig.nil_ls.setup({})

        -- Bash
        lspconfig.bashls.setup({})

        -- Buffer-local LSP keymaps, only attached when a server is active.
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                local opts = function(desc)
                    return { buffer = args.buf, desc = "LSP: " .. desc }
                end
                vim.keymap.set("n", "gd",         vim.lsp.buf.definition,      opts("Go to definition"))
                vim.keymap.set("n", "gD",         vim.lsp.buf.declaration,     opts("Go to declaration"))
                vim.keymap.set("n", "gi",         vim.lsp.buf.implementation,  opts("Go to implementation"))
                vim.keymap.set("n", "gr",         vim.lsp.buf.references,      opts("Go to references"))
                vim.keymap.set("n", "K",          vim.lsp.buf.hover,           opts("Hover docs"))
                vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename,          opts("Rename symbol"))
                vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action,     opts("Code action"))
                vim.keymap.set("n", "[d",         vim.diagnostic.goto_prev,    opts("Previous diagnostic"))
                vim.keymap.set("n", "]d",         vim.diagnostic.goto_next,    opts("Next diagnostic"))
                vim.keymap.set("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, opts("Format buffer"))
            end,
        })
    end,
}
