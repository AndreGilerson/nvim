return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
        -- nvim 0.11+ deprecated the `require("lspconfig").<server>.setup{}`
        -- framework in favour of the native `vim.lsp.config()` / `vim.lsp.enable()`
        -- API. We keep the nvim-lspconfig plugin installed only for the per-server
        -- defaults it ships as `lsp/<name>.lua` runtime files (cmd, root markers,
        -- filetypes) and for `:LspRestart`; all *configuration* now goes through
        -- the native API, which deep-merges our tables over those defaults.

        -- Tell servers what completion features cmp can handle (snippets,
        -- resolve support, etc.). Without this, completion items are limited.
        -- Applied to every server via the "*" wildcard config.
        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        vim.lsp.config("*", { capabilities = capabilities })

        -- Lua: configured to know about the neovim runtime so vim.api etc.
        -- aren't flagged as undefined when editing this config.
        vim.lsp.config("lua_ls", {
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

        -- Nix (nil_ls) and Bash (bashls) use the plugin defaults as-is;
        -- capabilities come from the "*" config above.

        -- Python: discover the project's interpreter (venv, then PATH) so
        -- basedpyright resolves imports against the right environment.
        local function venvs_in(dir)
            local matches = {}
            local handle = vim.uv.fs_scandir(dir)
            if not handle then return matches end
            while true do
                local name, kind = vim.uv.fs_scandir_next(handle)
                if not name then break end
                if (kind == "directory" or kind == "link")
                    and (name:match("^%.?venv") or name == ".direnv") then
                    table.insert(matches, dir .. "/" .. name)
                end
            end
            return matches
        end

        local function python_in(venv_dir)
            -- direnv stores its python under .direnv/python-<ver>/, look one level deeper
            if venv_dir:match("/%.direnv$") then
                local handle = vim.uv.fs_scandir(venv_dir)
                if handle then
                    while true do
                        local name = vim.uv.fs_scandir_next(handle)
                        if not name then break end
                        if name:match("^python") then
                            local p = venv_dir .. "/" .. name .. "/bin/python"
                            if vim.fn.executable(p) == 1 then return p end
                        end
                    end
                end
                return nil
            end
            local p = venv_dir .. "/bin/python"
            return vim.fn.executable(p) == 1 and p or nil
        end

        local function find_venv_python(start_dir)
            local dir = start_dir
            local prev = ""
            while dir ~= prev and dir ~= "" do
                for _, candidate in ipairs(venvs_in(dir)) do
                    local p = python_in(candidate)
                    if p then return p end
                end
                prev = dir
                dir = vim.fn.fnamemodify(dir, ":h")
            end
            return nil
        end

        -- Per-project overrides: key = project root dir, value = python path.
        local python_overrides = {}
        local root_markers = { "pyproject.toml", "setup.py", "Pipfile", ".git" }

        local function project_root_for(path)
            return vim.fs.root(path, root_markers)
        end

        -- Walk upward from start_dir. At each level: an explicit override wins
        -- over an auto-detected venv (so child venvs shadow parent overrides
        -- naturally — they're hit first as we walk up from the file).
        local function discover_python(start_dir)
            local dir = start_dir
            local prev = ""
            while dir ~= prev and dir ~= "" do
                if python_overrides[dir] then return python_overrides[dir] end
                for _, pattern in ipairs({ ".venv*", "venv*", ".direnv/python*" }) do
                    for _, candidate in ipairs(vim.fn.glob(dir .. "/" .. pattern, false, true)) do
                        local p = candidate .. "/bin/python"
                        if vim.fn.executable(p) == 1 then return p end
                    end
                end
                prev = dir
                dir = vim.fn.fnamemodify(dir, ":h")
            end
            return (vim.fn.exepath("python")  ~= "" and vim.fn.exepath("python"))
                or (vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3"))
                or nil
        end

        -- Path of `target` written relative to `base` ('.' if equal, absolute
        -- as a fallback when target isn't under base).
        local function relative_path(target, base)
            target = vim.fn.fnamemodify(target, ":p"):gsub("/$", "")
            base   = vim.fn.fnamemodify(base, ":p"):gsub("/$", "")
            if target == base then return "." end
            if target:sub(1, #base + 1) == base .. "/" then
                return target:sub(#base + 2)
            end
            return target
        end

        local function render_pyrightconfig(venv_path_rel, venv_name, extras)
            local lines = { "{",
                '    "venvPath": ' .. vim.json.encode(venv_path_rel) .. "," }
            if #extras > 0 then
                local items = {}
                for _, p in ipairs(extras) do
                    table.insert(items, vim.json.encode(p))
                end
                table.insert(lines, '    "venv": ' .. vim.json.encode(venv_name) .. ",")
                table.insert(lines, '    "extraPaths": [' .. table.concat(items, ", ") .. "]")
            else
                table.insert(lines, '    "venv": ' .. vim.json.encode(venv_name))
            end
            table.insert(lines, "}")
            return table.concat(lines, "\n") .. "\n"
        end

        -- Append `entry` to .gitignore at gi_path. Skips duplicates and ensures
        -- the existing file ends with a newline before appending.
        local function append_gitignore_entry(gi_path, entry)
            local content = ""
            if vim.fn.filereadable(gi_path) == 1 then
                local rf = io.open(gi_path, "r")
                if rf then content = rf:read("*a"); rf:close() end
            end
            for line in (content .. "\n"):gmatch("([^\n]*)\n") do
                if vim.trim(line) == entry then
                    return false, "already present"
                end
            end
            local prefix = (content ~= "" and not content:match("\n$")) and "\n" or ""
            local f, err = io.open(gi_path, "a")
            if not f then return false, err end
            f:write(prefix .. entry .. "\n")
            f:close()
            return true
        end

        local function offer_gitignore(config_path, on_done)
            on_done = on_done or function() end
            local config_dir  = vim.fn.fnamemodify(config_path, ":h")
            local config_name = vim.fn.fnamemodify(config_path, ":t")
            local default_gi  = config_dir .. "/.gitignore"

            vim.ui.select({ "Yes", "No" }, {
                prompt = "Add " .. config_name .. " to .gitignore?",
            }, function(choice)
                if choice ~= "Yes" then on_done(); return end
                vim.ui.input({
                    prompt = ".gitignore path: ",
                    default = default_gi,
                    completion = "file",
                }, function(gi_path)
                    if not gi_path or gi_path == "" then on_done(); return end
                    gi_path = vim.fn.expand(gi_path)
                    local entry = relative_path(config_path, vim.fn.fnamemodify(gi_path, ":h"))
                    local ok, msg = append_gitignore_entry(gi_path, entry)
                    if ok then
                        vim.notify("Added '" .. entry .. "' to " .. gi_path)
                    else
                        vim.notify(".gitignore: " .. tostring(msg), vim.log.levels.WARN)
                    end
                    on_done()
                end)
            end)
        end

        -- Optional UI flow that mirrors a hand-written pyrightconfig.json:
        -- needed because basedpyright's LSP doesn't accept the venv folder
        -- name as a workspace setting, only via this on-disk config.
        local function offer_pyrightconfig(python_path, root, on_done)
            on_done = on_done or function() end

            local bin_dir     = vim.fn.fnamemodify(python_path, ":h")
            local venv_dir    = vim.fn.fnamemodify(bin_dir, ":h")
            local venv_name   = vim.fn.fnamemodify(venv_dir, ":t")
            local venv_parent = vim.fn.fnamemodify(venv_dir, ":h")
            local default_cfg = root .. "/pyrightconfig.json"

            vim.ui.select({ "Yes", "No" }, {
                prompt = "Persist via pyrightconfig.json so basedpyright auto-detects this interpreter?",
            }, function(choice)
                if choice ~= "Yes" then on_done(); return end
                vim.ui.input({
                    prompt = "pyrightconfig.json path: ",
                    default = default_cfg,
                    completion = "file",
                }, function(config_path)
                    if not config_path or config_path == "" then on_done(); return end
                    config_path = vim.fn.expand(config_path)
                    local config_dir   = vim.fn.fnamemodify(config_path, ":h")
                    local venv_path_rel = relative_path(venv_parent, config_dir)
                    local extras = {}
                    if vim.fn.isdirectory(config_dir .. "/src") == 1 then
                        table.insert(extras, "src")
                    end
                    local content = render_pyrightconfig(venv_path_rel, venv_name, extras)

                    local write_and_continue = function()
                        vim.fn.mkdir(config_dir, "p")
                        local f, err = io.open(config_path, "w")
                        if not f then
                            vim.notify("Failed to write " .. config_path .. ": " .. tostring(err),
                                vim.log.levels.ERROR)
                            on_done(); return
                        end
                        f:write(content); f:close()
                        vim.notify("Wrote " .. config_path)
                        offer_gitignore(config_path, on_done)
                    end

                    if vim.fn.filereadable(config_path) == 1 then
                        vim.ui.select({ "Overwrite", "Cancel" }, {
                            prompt = config_path .. " exists. Overwrite?",
                        }, function(c)
                            if c ~= "Overwrite" then on_done(); return end
                            write_and_continue()
                        end)
                    else
                        write_and_continue()
                    end
                end)
            end)
        end

        -- Pyright only reads python.pythonPath at startup, so we restart the
        -- server instead of trying to live-update it. The override is keyed
        -- by the current buffer's project root so it scopes naturally.
        -- After applying, offer to persist the choice via pyrightconfig.json
        -- — the only surface basedpyright reads the venv folder name from —
        -- and restart once the (async) prompt chain finishes.
        local function apply_python(python_path)
            local buf_path = vim.fn.expand("%:p")
            local root = project_root_for(buf_path)
                or vim.fn.fnamemodify(buf_path, ":h")
            if root == "" then root = vim.fn.getcwd() end
            python_overrides[root] = python_path

            offer_pyrightconfig(python_path, root, function()
                vim.cmd("LspRestart basedpyright")
                vim.notify("basedpyright @ " .. root .. " → " .. python_path)
            end)
        end

        -- Run the chosen python and capture its sys.path. Used by :PythonDebug
        -- to compare what the interpreter sees vs. what basedpyright resolves;
        -- not fed into extraPaths because dumping stdlib paths there caused
        -- basedpyright to mis-resolve site-packages against the nix-store
        -- python install instead of the venv.
        local function get_sys_path(python_path)
            local out = vim.fn.system({
                python_path, "-c",
                "import sys; print(chr(10).join(p for p in sys.path if p))",
            })
            if vim.v.shell_error ~= 0 then return {} end
            local paths = {}
            for line in (out or ""):gmatch("[^\r\n]+") do
                table.insert(paths, line)
            end
            return paths
        end

        -- Mirror what a hand-written pyrightconfig.json would put in extraPaths:
        -- top-level source-layout dirs that aren't on sys.path automatically.
        local function project_extra_paths(root)
            if not root or root == "" then return {} end
            local paths = {}
            if vim.fn.isdirectory(root .. "/src") == 1 then
                table.insert(paths, root .. "/src")
            end
            return paths
        end

        vim.lsp.config("basedpyright", {
            before_init = function(_, config)
                local root = config.root_dir or vim.fn.getcwd()
                local python = discover_python(root)
                if python then
                    -- Only `python.pythonPath` is set: basedpyright honors it
                    -- from LSP and walks up from the interpreter to find
                    -- site-packages. Setting `python.venvPath` *without*
                    -- a venv name (basedpyright ignores `python.venv` from
                    -- LSP — it can only come from pyrightconfig.json) leaves
                    -- the venv half-resolved and breaks third-party import
                    -- detection for non-standard venv folder names like
                    -- `.venv-cuda`.
                    config.settings = vim.tbl_deep_extend("force",
                        config.settings or {},
                        {
                            python = { pythonPath = python },
                            basedpyright = {
                                analysis = {
                                    extraPaths = project_extra_paths(root),
                                    useLibraryCodeForTypes = true,
                                    diagnosticMode = "workspace",
                                    autoSearchPaths = true,
                                },
                            },
                        })
                end
            end,
        })

        -- === Writing: grammar / spell / style language servers ==========
        -- Check prose (LaTeX, Markdown, git commits) and code comments, and
        -- surface fixes as LSP code actions (your <leader>ca mapping). Roles
        -- are split so they don't flag the same text twice:
        --   • ltex_plus (LanguageTool) — grammar + spelling for prose/markup
        --   • harper_ls                — grammar in *code comments* only
        --   • vale_ls                  — style / voice / tone (Grammarly-like)
        -- The binaries come from packages.nix; spell setup, the Vale ruleset
        -- path, and :DictSync live in lua/config/writing.lua.

        -- harper: restrict to code filetypes so it doesn't double up with ltex
        -- on Markdown/gitcommit. Passing `filetypes` replaces the bundled
        -- default list outright (cmd/root_markers are kept).
        vim.lsp.config("harper_ls", {
            filetypes = {
                "c", "cpp", "cs", "go", "java", "javascript", "typescript",
                "typescriptreact", "lua", "nix", "python", "ruby", "rust",
                "swift", "toml", "haskell", "cmake", "php", "dart", "clojure", "sh",
            },
            settings = {
                ["harper-ls"] = {
                    userDictPath = vim.fn.stdpath("data") .. "/harper/dict.txt",
                },
            },
        })

        -- ltex-ls-plus: LanguageTool for prose/markup. Optionally load the
        -- offline n-gram data set for context-aware real-word errors
        -- (their/there, its/it's). It's a large separate download, so we only
        -- wire it when the directory exists — a missing data set must never
        -- break startup. Expected layout: <dir>/en/ (README → "n-gram data").
        local ltex = { settings = { ltex = { language = "en-US" } } }
        local ngram_dir = vim.fn.expand("~/.local/share/ltex/ngrams")
        if vim.fn.isdirectory(ngram_dir) == 1 then
            ltex.settings.ltex.additionalRules = { languageModel = ngram_dir }
        end
        vim.lsp.config("ltex_plus", ltex)

        -- vale_ls needs no settings here: its ruleset comes from the .vale.ini
        -- shipped with this config, located via VALE_CONFIG_PATH (writing.lua).

        -- Activate the servers. Their default cmd/root_dir/filetypes come from
        -- nvim-lspconfig's bundled `lsp/<name>.lua`; the `vim.lsp.config` tables
        -- above are merged on top.
        vim.lsp.enable({ "lua_ls", "nil_ls", "bashls", "basedpyright" })
        vim.lsp.enable({ "harper_ls", "ltex_plus", "vale_ls" })

        -- :PythonSelect — pick venv / flake / system / custom path
        vim.api.nvim_create_user_command("PythonSelect", function()
            local items = {}
            local seen = {}
            local function add(label, path, kind)
                if not path or seen[path] then return end
                seen[path] = true
                table.insert(items, { label = label, path = path, kind = kind })
            end

            local dir = vim.fn.expand("%:p:h")
            if dir == "" then dir = vim.fn.getcwd() end
            local prev = ""
            while dir ~= prev and dir ~= "" do
                for _, candidate in ipairs(venvs_in(dir)) do
                    local p = python_in(candidate)
                    if p then add("venv: " .. p, p, "path") end
                end
                if vim.fn.filereadable(dir .. "/flake.nix") == 1 then
                    add("nix develop @ " .. dir, dir, "flake")
                end
                prev = dir
                dir = vim.fn.fnamemodify(dir, ":h")
            end
            for _, exe in ipairs({ "python", "python3" }) do
                local p = vim.fn.exepath(exe)
                if p ~= "" then add("PATH: " .. p, p, "path") end
            end
            table.insert(items, { label = "Custom path...", kind = "custom" })

            vim.ui.select(items, {
                prompt = "Python interpreter for basedpyright:",
                format_item = function(it) return it.label end,
            }, function(choice)
                if not choice then return end
                if choice.kind == "custom" then
                    vim.ui.input({ prompt = "Path to python: ", completion = "file" }, function(input)
                        if input and input ~= "" then apply_python(vim.fn.expand(input)) end
                    end)
                elseif choice.kind == "flake" then
                    vim.notify("Querying nix develop in " .. choice.path .. "...")
                    vim.system({ "nix", "develop", "--command", "which", "python" }, { cwd = choice.path },
                        function(result)
                            vim.schedule(function()
                                if result.code == 0 then
                                    local p = (result.stdout or ""):gsub("%s+$", "")
                                    if vim.fn.executable(p) == 1 then
                                        apply_python(p)
                                    else
                                        vim.notify("nix develop returned no usable python", vim.log.levels.ERROR)
                                    end
                                else
                                    vim.notify("nix develop failed: " .. (result.stderr or ""), vim.log.levels.ERROR)
                                end
                            end)
                        end)
                else
                    apply_python(choice.path)
                end
            end)
        end, { desc = "Select Python interpreter for basedpyright" })

        -- :PythonDebug — dump basedpyright/venv state into a scratch buffer.
        vim.api.nvim_create_user_command("PythonDebug", function()
            local buf_path = vim.fn.expand("%:p")
            local buf_dir  = vim.fn.expand("%:p:h")
            local lines = {}
            local function add(s) table.insert(lines, s) end

            add("=== Python LSP Debug ===")
            add("Buffer:           " .. buf_path)
            add("Buffer dir:       " .. buf_dir)
            add("Project root:     " .. tostring(project_root_for(buf_path)))
            add("cwd:              " .. vim.fn.getcwd())
            add("")
            add("--- Auto-detection ---")
            add("find_venv_python(buf_dir):  " .. tostring(find_venv_python(buf_dir)))
            add("discover_python(buf_dir):   " .. tostring(discover_python(buf_dir)))
            add("")
            add("--- Stored overrides ---")
            local any = false
            for root, p in pairs(python_overrides) do
                add("  " .. root .. " -> " .. p)
                any = true
            end
            if not any then add("  (none)") end
            add("")
            add("--- Active basedpyright clients ---")
            local clients = vim.lsp.get_clients({ name = "basedpyright" })
            if #clients == 0 then add("  (none running)") end
            for _, client in ipairs(clients) do
                add("client.id:    " .. client.id)
                add("  root_dir:   " .. (client.config.root_dir or "?"))
                add("  settings:")
                for line in vim.inspect(client.config.settings or {}):gmatch("[^\n]+") do
                    add("    " .. line)
                end
                add("  attached buffers:")
                for bufnr in pairs(client.attached_buffers or {}) do
                    add("    [" .. bufnr .. "] " .. vim.api.nvim_buf_get_name(bufnr))
                end
            end

            add("")
            add("--- get_sys_path() for the discovered python ---")
            local discovered = discover_python(buf_dir)
            if discovered then
                for _, p in ipairs(get_sys_path(discovered)) do
                    add("  " .. p)
                end
            else
                add("  (no python discovered)")
            end

            vim.cmd("new")
            vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
            vim.bo.buftype = "nofile"
            vim.bo.bufhidden = "wipe"
            vim.bo.swapfile = false
        end, { desc = "Dump python LSP debug info" })

        -- Auto-show diagnostic float when the cursor lingers on a squiggle.
        -- Triggered by CursorHold (governed by 'updatetime' in options.lua).
        vim.api.nvim_create_autocmd("CursorHold", {
            callback = function()
                vim.diagnostic.open_float(nil, {
                    focusable = false,
                    close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
                    scope = "cursor",
                    border = "rounded",
                })
            end,
        })

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
                vim.keymap.set("n", "<leader>e",  vim.diagnostic.open_float,   opts("Show diagnostic"))
                vim.keymap.set("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, opts("Format buffer"))
            end,
        })
    end,
}
