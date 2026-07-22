-- Writing support: built-in spell setup, the Vale ruleset location, and the
-- wordlist generator that feeds predictive completion. The grammar/style
-- language servers themselves are configured in lua/plugins/lsp.lua; the
-- predictive completion sources are in lua/plugins/cmp.lua. Loaded eagerly
-- from init.lua so VALE_CONFIG_PATH and the spellfile are set before any LSP
-- or completion starts.

-- --- Spell (built-in) -------------------------------------------------------
-- Spell drives both the squiggles and, via cmp-spell, the predictive
-- corrections. Words added with `zg` are written to the spellfile below and
-- immediately become completion candidates — that's the "self-learning" part.
-- The spellfile lives under the data dir (not this repo) so personal words
-- don't get committed.
local spell_dir = vim.fn.stdpath("data") .. "/spell"
vim.fn.mkdir(spell_dir, "p")
vim.o.spellfile = spell_dir .. "/en.utf-8.add"
vim.o.spelllang = "en_us"

-- Enable spell only for prose/markup buffers (code gets it via harper on
-- comments instead). z= suggests fixes, zg marks a word good, zw marks wrong.
vim.api.nvim_create_autocmd("FileType", {
    pattern = {
        "markdown", "tex", "plaintex", "text", "gitcommit",
        "rst", "typst", "mail", "org", "quarto", "asciidoc",
    },
    callback = function()
        vim.opt_local.spell = true
    end,
})

-- --- Vale ruleset -----------------------------------------------------------
-- Point vale (via vale-ls) at the .vale.ini shipped with this config so its
-- style/voice rules apply everywhere, not only inside projects that carry
-- their own .vale.ini. Run `vale sync` once to fetch the styles — see
-- README → "Writing: spell, grammar & style".
vim.env.VALE_CONFIG_PATH = vim.fn.stdpath("config") .. "/vale/.vale.ini"

-- :ValeSync — download the style packages named in .vale.ini into StylesPath.
-- Required once (and after adding packages), else vale-ls errors with
-- "style '…' does not exist on StylesPath". Runs vale with the config above
-- (inherited via VALE_CONFIG_PATH) and reloads the server on success.
vim.api.nvim_create_user_command("ValeSync", function()
    if vim.fn.executable("vale") ~= 1 then
        vim.notify("ValeSync: `vale` not on PATH (install via packages.nix)", vim.log.levels.ERROR)
        return
    end
    vim.notify("ValeSync: downloading Vale style packages…")
    vim.system({ "vale", "sync" }, { text = true }, function(res)
        vim.schedule(function()
            if res.code ~= 0 then
                vim.notify("ValeSync failed: " .. (res.stderr or res.stdout or ""), vim.log.levels.ERROR)
                return
            end
            vim.notify("ValeSync: styles synced; reloading vale_ls")
            pcall(vim.cmd, "LspRestart vale_ls")
        end)
    end)
end, { desc = "Download Vale style packages (vale sync)" })

-- --- Predictive-completion wordlist ----------------------------------------
-- cmp-dictionary (plugins/cmp.lua) reads a plain, one-word-per-line list.
-- Build it from aspell's English dictionary. Fully offline once aspell +
-- aspellDicts.en (packages.nix) are installed; re-run after changing dicts.
vim.api.nvim_create_user_command("DictSync", function()
    local out_dir = vim.fn.stdpath("data") .. "/dict"
    vim.fn.mkdir(out_dir, "p")
    local out = out_dir .. "/en.dict"
    vim.notify("DictSync: building completion wordlist with aspell…")
    vim.system(
        { "sh", "-c", "aspell -d en dump master | aspell -l en expand" },
        { text = true },
        function(res)
            vim.schedule(function()
                if res.code ~= 0 then
                    vim.notify("DictSync failed: " .. (res.stderr or ""), vim.log.levels.ERROR)
                    return
                end
                -- `expand` prints affix-expanded words, space-separated per
                -- line; re-split to one word per line for cmp-dictionary.
                local words = {}
                for tok in (res.stdout or ""):gmatch("%S+") do
                    words[#words + 1] = tok
                end
                local f = io.open(out, "w")
                if not f then
                    vim.notify("DictSync: cannot write " .. out, vim.log.levels.ERROR)
                    return
                end
                f:write(table.concat(words, "\n"))
                f:close()
                -- Hot-load the freshly written list into cmp-dictionary so it
                -- takes effect without a restart.
                pcall(function()
                    require("cmp_dictionary").setup({
                        paths = { out },
                        exact_length = 2,
                        first_case_insensitive = true,
                    })
                end)
                vim.notify(("DictSync: wrote %d words to %s"):format(#words, out))
            end)
        end
    )
end, { desc = "Rebuild the cmp-dictionary wordlist from aspell" })
