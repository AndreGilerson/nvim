-- In-buffer git diff: shows which *lines* changed, complementing the
-- which-files view nvim-tree already gives.
--
-- By default gitsigns diffs against the index (i.e. unstaged changes). This
-- config keeps that default but adds a base picker (<leader>gb) so the diff can
-- be taken against HEAD, HEAD~N, or the branch point with main/master — that is
-- what makes "everything I changed in the last few commits" visible at once.

-- Human-readable label for the base currently in effect, for notifications and
-- so the picker can tell you where you are.
local current_base = "index (unstaged changes)"

local function notify_base()
    vim.notify("Git diff base: " .. current_base, vim.log.levels.INFO)
end

-- rev = nil restores gitsigns' default (the index).
local function set_base(rev, label)
    -- `true` = apply globally, not just to the current buffer, so every file
    -- you open afterwards is diffed against the same base.
    require("gitsigns").change_base(rev, true)
    current_base = label
    notify_base()
end

-- Merge base with the repo's integration branch: everything the current branch
-- added, ignoring commits that landed on main in the meantime.
local function branch_point()
    for _, branch in ipairs({ "main", "master" }) do
        local out = vim.system(
            { "git", "merge-base", "HEAD", branch },
            { cwd = vim.fn.expand("%:p:h"), text = true }
        ):wait()
        if out.code == 0 then
            local rev = vim.trim(out.stdout)
            if rev ~= "" then
                return rev, branch
            end
        end
    end
    return nil
end

local function pick_base()
    local choices = {
        { label = "Index — unstaged changes only (default)", rev = nil },
        { label = "HEAD — changes since the last commit", rev = "HEAD" },
        { label = "HEAD~1 — last 1 commit + working tree", rev = "HEAD~1" },
        { label = "HEAD~3 — last 3 commits + working tree", rev = "HEAD~3" },
        { label = "HEAD~5 — last 5 commits + working tree", rev = "HEAD~5" },
        { label = "Branch point with main/master", rev = "@branch-point" },
        { label = "Other revision…", rev = "@prompt" },
    }

    vim.ui.select(choices, {
        prompt = "Diff against (current: " .. current_base .. ")",
        format_item = function(item)
            return item.label
        end,
    }, function(choice)
        if not choice then
            return
        end

        if choice.rev == "@branch-point" then
            local rev, branch = branch_point()
            if not rev then
                vim.notify("No main/master branch found in this repo", vim.log.levels.WARN)
                return
            end
            set_base(rev, "branch point with " .. branch .. " (" .. rev:sub(1, 8) .. ")")
        elseif choice.rev == "@prompt" then
            vim.ui.input({ prompt = "Git revision: " }, function(rev)
                if rev and rev ~= "" then
                    set_base(rev, rev)
                end
            end)
        else
            set_base(choice.rev, choice.rev or "index (unstaged changes)")
        end
    end)
end

return {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local gs = require("gitsigns")

        gs.setup({
            -- Signs in the sign column mark every changed hunk. `signcolumn` is
            -- already always-on in options.lua, so nothing shifts around.
            signs = {
                add          = { text = "┃" },
                change       = { text = "┃" },
                delete       = { text = "▁" },
                topdelete    = { text = "▔" },
                changedelete = { text = "~" },
                untracked    = { text = "┆" },
            },
            -- Newly created files show as fully added rather than being ignored.
            attach_to_untracked = true,
            -- Off by default (full-line highlight is loud while writing code);
            -- <leader>gl turns it on when you actually want to review changes.
            linehl = false,
            numhl = false,
            word_diff = false,
            current_line_blame_opts = {
                delay = 300,
                virt_text_pos = "eol",
            },
            on_attach = function(bufnr)
                local function nmap(lhs, rhs, desc)
                    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
                end

                -- Hunk navigation. nav_hunk wraps at the end of the buffer and
                -- respects a count, so `3]h` jumps three hunks forward.
                nmap("]h", function() gs.nav_hunk("next") end, "Next git hunk")
                nmap("[h", function() gs.nav_hunk("prev") end, "Previous git hunk")

                -- Inspecting changes
                nmap("<leader>gp", gs.preview_hunk, "Preview hunk")
                nmap("<leader>gd", function() gs.diffthis(nil, { split = "belowright" }) end, "Diff file against base")
                nmap("<leader>gB", function() gs.blame_line({ full = true }) end, "Blame line (full)")

                -- Toggles: what gets highlighted
                nmap("<leader>gl", gs.toggle_linehl, "Toggle changed-line highlight")
                nmap("<leader>gn", gs.toggle_numhl, "Toggle changed-line numbers")
                nmap("<leader>gw", gs.toggle_word_diff, "Toggle intra-line word diff")
                nmap("<leader>gc", gs.toggle_current_line_blame, "Toggle inline blame")

                -- Lists of changes
                nmap("<leader>gq", function() gs.setqflist() end, "Hunks in this file → quickfix")
                nmap("<leader>gQ", function() gs.setqflist("all") end, "Hunks in whole repo → quickfix")

                -- Diff base
                nmap("<leader>gb", pick_base, "Pick git diff base")
                nmap("<leader>gr", function() set_base(nil, "index (unstaged changes)") end, "Reset diff base to index")
            end,
        })

        -- Same picker as <leader>gb, plus `:GitBase HEAD~4` for an explicit rev.
        vim.api.nvim_create_user_command("GitBase", function(opts)
            if opts.args == "" then
                pick_base()
            else
                set_base(opts.args, opts.args)
            end
        end, { nargs = "?", desc = "Set the gitsigns diff base (no arg = pick from a list)" })
    end,
}
