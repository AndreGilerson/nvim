return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",   -- LSP completions
        "hrsh7th/cmp-buffer",     -- words from open buffers
        "hrsh7th/cmp-path",       -- filesystem paths
        "L3MON4D3/LuaSnip",       -- snippet engine
        "saadparwaiz1/cmp_luasnip", -- snippet completions
        -- Phone-keyboard-style predictive text for prose (prefix completion
        -- from a real wordlist — see config/writing.lua :DictSync):
        "uga-rosa/cmp-dictionary",
    },
    config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")

        -- Predictive dictionary source — this is what actually gives
        -- phone-keyboard prefix completion ("recei" → receive, receiver, …).
        -- It reads plain newline-separated wordlists:
        --   • the aspell-generated list (run :DictSync once to build it), and
        --   • your personal spellfile, so words you `zg` also get completed
        --     — the "self-learning" bit (picked up on next start / :DictSync).
        -- Missing files are skipped: cmp-dictionary throws on a nonexistent
        -- path, so we only pass ones that exist.
        local dict_paths = {}
        for _, p in ipairs({
            vim.fn.stdpath("data") .. "/dict/en.dict",
            vim.o.spellfile,
        }) do
            if p ~= "" and vim.fn.filereadable(p) == 1 then
                dict_paths[#dict_paths + 1] = p
            end
        end
        require("cmp_dictionary").setup({
            paths = dict_paths,
            exact_length = 2,            -- start matching after 2 chars
            first_case_insensitive = true, -- "recei" also completes "Receive"
        })

        cmp.setup({
            snippet = {
                expand = function(args) luasnip.lsp_expand(args.body) end,
            },
            mapping = cmp.mapping.preset.insert({
                ["<C-Space>"] = cmp.mapping.complete(),
                ["<C-e>"]     = cmp.mapping.abort(),
                ["<CR>"]      = cmp.mapping.confirm({ select = false }),
                ["<Tab>"] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_next_item()
                    elseif luasnip.expand_or_jumpable() then
                        luasnip.expand_or_jump()
                    else
                        fallback()
                    end
                end, { "i", "s" }),
                ["<S-Tab>"] = cmp.mapping(function(fallback)
                    if cmp.visible() then
                        cmp.select_prev_item()
                    elseif luasnip.jumpable(-1) then
                        luasnip.jump(-1)
                    else
                        fallback()
                    end
                end, { "i", "s" }),
            }),
            -- Default (code) sources: LSP-first, snippets, then buffer/path.
            -- `buffer` is intentionally demoted with keyword_length = 4 so it
            -- stops parroting half-typed words (including typos) — the old
            -- behaviour you saw. LSP now drives code completion.
            sources = cmp.config.sources({
                { name = "nvim_lsp" },
                { name = "luasnip" },
            }, {
                { name = "buffer", keyword_length = 4 },
                { name = "path" },
            }),
        })

        -- Prose buffers: same as the default sources PLUS the predictive
        -- dictionary. Crucially this keeps `nvim_lsp` first, so an LSP attached
        -- to prose (e.g. texlab for LaTeX \ref/\cite label completion) still
        -- works — dropping it was what broke that. Buffer stays a low-priority
        -- fallback so it no longer dominates the menu with previously-typed
        -- words. ltex/harper/vale don't complete; they diagnose (<leader>ca).
        cmp.setup.filetype(
            { "markdown", "tex", "plaintex", "text", "gitcommit", "rst", "typst", "mail", "org" },
            {
                sources = cmp.config.sources({
                    { name = "nvim_lsp" },
                    { name = "luasnip" },
                    { name = "dictionary", keyword_length = 2 },
                }, {
                    { name = "buffer", keyword_length = 4 },
                    { name = "path" },
                }),
            }
        )
    end,
}
