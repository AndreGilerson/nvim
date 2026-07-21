return {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
        "hrsh7th/cmp-nvim-lsp",   -- LSP completions
        "hrsh7th/cmp-buffer",     -- words from open buffers
        "hrsh7th/cmp-path",       -- filesystem paths
        "L3MON4D3/LuaSnip",       -- snippet engine
        "saadparwaiz1/cmp_luasnip", -- snippet completions
        -- Phone-keyboard-style predictive text for prose (see prose.lua):
        "f3fora/cmp-spell",       -- correct-word completion from the spell engine
        "uga-rosa/cmp-dictionary", -- completion from a plain wordlist (:DictSync)
    },
    config = function()
        local cmp = require("cmp")
        local luasnip = require("luasnip")

        -- Predictive dictionary source. `paths` points at a plain newline-
        -- separated wordlist; run :DictSync (defined in config/writing.lua)
        -- once to generate it from aspell. cmp-dictionary throws if a path is
        -- missing, so we only pass it when the file exists — :DictSync calls
        -- setup() again to hot-load it after writing.
        local dict_path = vim.fn.stdpath("data") .. "/dict/en.dict"
        require("cmp_dictionary").setup({
            paths = vim.fn.filereadable(dict_path) == 1 and { dict_path } or {},
            exact_length = 2,            -- start matching after 2 chars
            first_case_insensitive = true, -- "recei" also completes "Receive"
        })

        -- cmp-spell turns Neovim's spell engine into a completion source: as you
        -- type it offers correctly-spelled words, and any word you `zg` into your
        -- personal spellfile becomes a candidate — that's the "self-learning".
        local spell_source = {
            name = "spell",
            option = {
                keep_all_entries = false,
                preselect_correct_word = true,
            },
        }

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

        -- Prose buffers get the predictive-text sources instead. Spell and
        -- dictionary lead; the LSP (ltex/harper/vale) here provides diagnostics
        -- and fixes, not completion, so we don't lean on it for words.
        cmp.setup.filetype(
            { "markdown", "tex", "plaintex", "text", "gitcommit", "rst", "typst", "mail", "org" },
            {
                sources = cmp.config.sources({
                    spell_source,
                    { name = "dictionary", keyword_length = 2 },
                    { name = "luasnip" },
                }, {
                    { name = "buffer", keyword_length = 4 },
                    { name = "path" },
                }),
            }
        )
    end,
}
