# Neovim setup: Neo-tree, git tools, coding time (AstroNvim)

> Everything below is already in this repo (`acfatah/nvim-config`); after
> cloning to `~/.config/nvim` only the machine-level steps are needed:
> Nerd Font (step 0) and the codetime.dev token. The file snippets
> document what each plugin file does.

How to make Neo-tree open at the directory you launched Neovim with
(`nvim <dir>`), and show `__git_ps1`-style flags (`*+$%`) on git
repo/worktree root folders. `<Space>e` keeps AstroNvim's default: toggle
the tree at the cwd and highlight the currently open file.

## Problem

- `nvim ~/some/project/` does **not** change Neovim's cwd. The cwd stays at
  wherever the shell was (e.g. `~`).
- AstroNvim's default `<Leader>e` is plain `Neotree toggle`, which opens at the
  cwd, so the tree shows `~` instead of the project.
- AstroNvim's rooter has `autochdir = false` by default, so it does not fix
  this either.

## Prerequisites

- AstroNvim (v5+) config at `~/.config/nvim`, using lazy.nvim.
- `neo-tree.nvim` installed (bundled with AstroNvim).
- User plugin specs loaded from `~/.config/nvim/lua/plugins/` (AstroNvim
  template default).
- A Nerd Font set in the terminal (see step 0).

## Steps

### 0. Install a Nerd Font (WSL / Windows Terminal)

AstroNvim, Neo-tree and the dashboard use Nerd Font icons. Without one, the
icons render as `�` or boxes.

1. Install a Nerd Font on **Windows** (not inside WSL; Windows renders the
   text). Download one from https://www.nerdfonts.com/font-downloads
   (this setup uses **0xProto**), or:

   ```powershell
   winget install DEVCOM.JetBrainsMonoNerdFont
   ```

   Right-click the `.ttf` files → *Install for all users*.

2. Windows Terminal → Settings → **Defaults** → Appearance → Font face →
   `0xProto Nerd Font Mono`. Setting it on Defaults makes every profile
   inherit it. Or edit `settings.json`:

   ```json
   "profiles": {
       "defaults": {
           "font": { "face": "0xProto Nerd Font Mono" }
       }
   }
   ```

   Remove any per-profile `"font": { "face": ... }` override (e.g.
   `Kode Mono`), or the profile keeps using that font.

3. VS Code integrated terminal, if used: add
   `"terminal.integrated.fontFamily": "0xProto Nerd Font Mono"` to settings.

4. Fully restart the terminal app, then test in the tab you run nvim from:

   ```bash
   printf '   \n'
   ```

   All four should show icons, not `�` or boxes.

Font gotchas:

- Use the **Mono** variant. Plain and *Propo* variants draw icons wider than
  one cell, so they overlap or misalign.
- The profile you actually open matters. Starting `wsl` from a PowerShell
  tab uses the PowerShell profile's font, not the WSL profile's.
- No font available? Set `icons_enabled = false` in
  `~/.config/nvim/lua/lazy_setup.lua` to switch AstroNvim to text-only.

### 1. Create the override file

Create `~/.config/nvim/lua/plugins/neo-tree.lua`:

```lua
-- per-repo-root cache: { flags = "*+$%", time = ms, running = bool }
local git_summary = {}
-- per-directory cache: path -> has .git (dir or worktree file)
local repo_roots = {}

-- flag order mirrors __git_ps1 (SHOWDIRTYSTATE/UNTRACKEDFILES/STASHSTATE);
-- first match colors name + flags; stash alone is not uncommitted work
local flag_hl = {
  { "*", "NeoTreeGitModified" },
  { "+", "NeoTreeGitStaged" },
  { "%", "NeoTreeGitUntracked" },
}

local function parse_git_flags(stdout)
  local w, i, s, u = "", "", "", ""
  for line in stdout:gmatch "[^\n]+" do
    if line:match "^# stash " then
      s = "$"
    elseif line:sub(1, 1) == "?" then
      u = "%"
    elseif line:match "^[12u] " then
      if line:sub(3, 3) ~= "." then i = "+" end
      if line:sub(4, 4) ~= "." then w = "*" end
    end
  end
  return w .. i .. s .. u
end

local function refresh_git_summary(root, force)
  local entry = git_summary[root] or {}
  git_summary[root] = entry
  if entry.running then return end
  if not force and entry.time and vim.uv.now() - entry.time < 1000 then return end
  entry.running = true
  vim.system(
    { "git", "-C", root, "status", "--porcelain=v2", "--show-stash" },
    { text = true },
    function(res)
      local flags = res.code == 0 and parse_git_flags(res.stdout) or ""
      vim.schedule(function()
        local changed = entry.flags ~= flags
        entry.flags, entry.time, entry.running = flags, vim.uv.now(), false
        if changed then require("neo-tree.sources.manager").redraw "filesystem" end
      end)
    end
  )
end

local function is_repo_root(path)
  if repo_roots[path] == nil then repo_roots[path] = vim.uv.fs_stat(path .. "/.git") ~= nil end
  return repo_roots[path]
end

local function refresh_all_git_summaries()
  for root in pairs(git_summary) do
    refresh_git_summary(root, true)
  end
end

-- name component + inline git flags on repo/worktree root directories
local function name_with_git_flags(config, node, state)
  local result = require("neo-tree.sources.filesystem.components").name(config, node, state)
  if node.type ~= "directory" or not is_repo_root(node.path) then return result end

  refresh_git_summary(node.path)
  local flags = (git_summary[node.path] or {}).flags or ""
  if flags == "" then return result end

  local hl = "NeoTreeDimText"
  for _, pair in ipairs(flag_hl) do
    if flags:find(pair[1], 1, true) then
      hl = pair[2]
      result.highlight = hl
      break
    end
  end
  -- one chunk: neo-tree's container pads a space between adjacent chunks
  return { result, { text = flags, highlight = hl } }
end

return {
  "nvim-neo-tree/neo-tree.nvim",
  specs = {
    {
      "AstroNvim/astrocore",
      opts = {
        autocmds = {
          -- neo-tree's git watcher misses repos nested under a non-git tree root
          neotree_repo_git_flags = {
            {
              event = { "FocusGained", "BufWritePost", "TermClose", "ShellCmdPost" },
              desc = "Refresh git flags on repo root directories in Neo-tree",
              callback = function() refresh_all_git_summaries() end,
            },
          },
          cd_to_dir_arg = {
            {
              event = "VimEnter",
              desc = "cd into directory passed as argument (nvim <dir>)",
              callback = function()
                local arg = vim.fn.argv(0)
                if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
                  vim.cmd.cd(vim.fn.fnameescape(arg))
                end
              end,
            },
          },
        },
      },
    },
  },
  opts = function(_, opts)
    local fs = opts.filesystem or {}
    opts.filesystem = fs
    fs.bind_to_cwd = true
    fs.follow_current_file = { enabled = true }
    -- always show dotfiles and gitignored files; `H` still toggles per session
    fs.filtered_items = vim.tbl_deep_extend("force", fs.filtered_items or {}, {
      hide_dotfiles = false,
      hide_gitignored = false,
    })

    fs.components = fs.components or {}
    fs.components.name = name_with_git_flags

    -- git state changed (neo-tree file watcher): refresh every known repo root
    opts.event_handlers = opts.event_handlers or {}
    table.insert(opts.event_handlers, {
      event = "git_event",
      handler = refresh_all_git_summaries,
    })
  end,
}
```

Or in one shot from a shell:

```bash
mkdir -p ~/.config/nvim/lua/plugins
cat > ~/.config/nvim/lua/plugins/neo-tree.lua <<'EOF'
-- paste the Lua block above here
EOF
```

### 2. Restart Neovim

Fully quit and reopen. `:Lazy reload neo-tree.nvim` is not enough for the
`VimEnter` autocmd, since that event only fires at startup.

### 3. Verify

Headless check that cwd follows the directory argument:

```bash
cd /tmp && nvim --headless ~/some/project/ \
  +'lua vim.defer_fn(function() print(vim.fn.getcwd()); vim.cmd("qa!") end, 1500)'
```

Expected output: the project path, not `/tmp`.

Manual check:

1. `nvim ~/some/project/`
2. `:pwd` shows `~/some/project`.
3. Open a file in a subfolder, then press `<Space>e`. The tree opens at the
   project root (cwd), expanded down to that file with the cursor on it.
4. In a folder containing several repos/worktrees, a dirty one shows as
   `feat-x *+%` with a colored name; clean ones look unchanged.

## Repo root git flags

Neo-tree colors files/folders *inside* a repo, but not the repo root folder
itself or folders above it. The config wraps Neo-tree's `name` component:
any folder with a `.git` dir/file (repo or worktree) gets flags appended,
matching the shell prompt (`GIT_PS1_SHOWDIRTYSTATE`, `SHOWUNTRACKEDFILES`,
`SHOWSTASHSTATE`):

| Flag | Meaning |
|---|---|
| `*` | unstaged changes (or merge conflict) |
| `+` | staged changes |
| `$` | stash exists |
| `%` | untracked files |

Name and flags take one color, first match wins:

| Condition | Color (highlight group) |
|---|---|
| has `*` | orange (`NeoTreeGitModified`) |
| has `+` | teal (`NeoTreeGitStaged`) |
| has `%` | gold (`NeoTreeGitUntracked`) |
| only `$` | name normal, flags dim (`NeoTreeDimText`) |

Per-file markers inside a repo (AstroNvim defaults):

| Marker | Meaning |
|---|---|
| orange square | modified |
| `✓` (teal) | staged |
| `✗` (gold) | unstaged |
| `★` (gold) | untracked |
| `➜` | renamed |
| `◌` | ignored |

Refresh: async `git status --porcelain=v2 --show-stash` per repo root,
cached 1s, re-run on Neo-tree's `git_event`, `FocusGained`,
`BufWritePost`, `TermClose` (e.g. lazygit) and `ShellCmdPost`.

## Git tools

### gitsigns.nvim (built into AstroNvim, no config needed)

Gutter signs for added/changed/deleted lines. Keymaps are buffer-local,
active in files inside a git repo:

| Key | Action |
|---|---|
| `]g` / `[g` | next / previous hunk |
| `]G` / `[G` | last / first hunk |
| `<Leader>gp` | preview hunk inline |
| `<Leader>gs` / `<Leader>gS` | stage (toggle) hunk / stage buffer |
| `<Leader>gr` / `<Leader>gR` | reset hunk / reset buffer |
| `<Leader>gl` / `<Leader>gL` | blame line / full blame |
| `<Leader>gd` | diff current buffer vs index |
| `ig` | text object: inside hunk (e.g. `vig`, `dig`) |

Visual mode `<Leader>gs` / `<Leader>gr` stage / reset only selected lines.

### diffview.nvim

Create `~/.config/nvim/lua/plugins/diffview.lua`:

```lua
-- first existing ref wins; origin/HEAD is often unset (fix: git remote set-head origin -a)
local base_candidates = { "origin/HEAD", "origin/main", "origin/master", "main", "master" }

local function review_base()
  for _, ref in ipairs(base_candidates) do
    vim.fn.system { "git", "rev-parse", "--verify", "--quiet", ref }
    if vim.v.shell_error == 0 then return ref end
  end
end

local function close_or(cmd)
  return function()
    if require("diffview.lib").get_current_view() then
      vim.cmd "DiffviewClose"
    else
      vim.cmd(cmd)
    end
  end
end

return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
    "DiffviewFileHistory",
  },
  specs = {
    {
      "AstroNvim/astrocore",
      opts = {
        mappings = {
          n = {
            ["<Leader>gD"] = { close_or "DiffviewOpen", desc = "Diffview toggle (changes)" },
            ["<Leader>gh"] = { close_or "DiffviewFileHistory %", desc = "Diffview file history" },
            ["<Leader>gH"] = { close_or "DiffviewFileHistory", desc = "Diffview repo history" },
            ["<Leader>gm"] = {
              function()
                local base = review_base()
                if not base then
                  vim.notify("No base branch found (" .. table.concat(base_candidates, ", ") .. ")", vim.log.levels.WARN)
                  return
                end
                close_or("DiffviewOpen " .. base .. "...HEAD")()
              end,
              desc = "Diffview vs merge-base (review)",
            },
          },
        },
      },
    },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      merge_tool = { layout = "diff3_mixed" },
    },
    keymaps = {
      view = { { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } } },
      file_panel = { { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } } },
      file_history_panel = { { "n", "q", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } } },
    },
  },
}
```

Restart Neovim; lazy.nvim installs it (or run `:Lazy install`).

| Key | Action |
|---|---|
| `<Leader>gD` | toggle whole-repo diff (working tree + staged vs HEAD) |
| `<Leader>gh` | history of current file |
| `<Leader>gH` | history of the repo |
| `<Leader>gm` | diff vs merge-base with `origin/HEAD`/`origin/main`/`main` (PR review) |
| `q` | close Diffview (any Diffview panel/buffer) |

Inside Diffview (defaults): `<Tab>` / `<S-Tab>` next / previous file,
`-` stage/unstage entry in the file panel, `S` stage all, `X` restore
entry, `gf` open file in previous tab, `g?` help, `g<C-x>` cycle layout.
Merge conflicts open a 3-way view (`diff3_mixed`): `<leader>co` /
`<leader>ct` / `<leader>cb` / `<leader>ca` choose ours / theirs / base /
all for the conflict under cursor, `]x` / `[x` jump between conflicts.

Git tools gotchas:

- Diffview opens in a **new tab**. `q` or the same `<Leader>g` key closes
  it; `:tabclose` leaves Diffview state behind, prefer `q`.
- Inside Diffview, its buffer-local `<leader>e` (focus file panel) and
  `<leader>b` (toggle panel) shadow Neo-tree `<Leader>e` / buffer keys.
- `<Leader>gd` (gitsigns) diffs one buffer; `<Leader>gD` (diffview) shows
  every changed file.
- `<Leader>gm` and `<Leader>gD` use Neovim's **cwd** repo, not the current
  file's repo. With a non-git cwd (e.g. `~/personal/vue-ui`), `:cd` into
  the worktree first (or `:DiffviewOpen -C<path>`).
- `origin/HEAD` is often unset in clones; `git remote set-head origin -a`
  sets it. The keymap falls back to `origin/main`, `origin/master`,
  `main`, `master`.
- Plugin version pinned in `lazy-lock.json`; copy that file too for an
  identical setup, `:Lazy update` to bump.

## Coding time (codetime.dev)

Sends Neovim activity to https://codetime.dev (same dashboard as the
VS Code / Zed extensions) with
[acfatah/codetime-dev.nvim](https://github.com/acfatah/codetime-dev.nvim),
and shows **today's dashboard minutes** (all editors and machines) in the
statusline.

Create `~/.config/nvim/lua/plugins/codetime-dev.lua`:

```lua
-- token: $CODETIME_TOKEN or ~/.codetime/config.json (codetime-cli), never put it here
return {
  {
    "acfatah/codetime-dev.nvim",
    event = "VeryLazy",
    opts = {},
  },
  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      -- AstroNvim v6 statusline tail: fill, lsp, virtual_env, treesitter, nav, mode
      table.insert(opts.statusline, #opts.statusline - 4, {
        condition = function() return package.loaded.codetime_dev ~= nil end,
        provider = function()
          local text = require("codetime_dev").format_today()
          return text and ("󱑎 " .. text .. " ") or ""
        end,
      })

      -- refresh while idle; the value otherwise only redraws on other events
      local timer = vim.uv.new_timer()
      timer:start(60000, 60000, vim.schedule_wrap(function() vim.cmd.redrawstatus() end))
    end,
  },
}
```

Token (never put it in the config or dotfiles), first match wins:

1. `$CODETIME_TOKEN`
2. `~/.codetime/config.json`, written by codetime-cli:

   ```bash
   npm i -g codetime-cli
   codetime token set <token>   # from codetime.dev/dashboard/settings
   ```

Requires `curl`. Restart Neovim; lazy.nvim installs it. The statusline
shows `󱑎 1h 23m` (before the LSP section).

| Command | Action |
|---|---|
| `:CodeTimeDevStatus` | token source (masked), sent/queued, last error, today |
| `:CodeTimeDevDashboard` | open the dashboard in the browser |
| `:CodeTimeDevReload` | re-read token, resume after a 401 |

Sent per event (parity with VS Code): project (git root/cwd name),
filetype, relative + absolute path, editor `Neovim`, OS + arch, event
type/time, read/write, git `origin` URL and branch. No file contents.

codetime.dev gotchas:

- Absolute paths include your username and git remote URLs; both leave
  the machine.
- Offline: events queue in memory (max 500) and retry every minute;
  they are lost if Neovim exits first.
- A rejected token pauses sending with one warning; fix it, then
  `:CodeTimeDevReload`.
- `~/.codetime/config.json` is a secret: do not commit it to dotfiles.
- The statusline item is empty until the first dashboard fetch (a few
  seconds after startup) and while offline with no data yet.
- The statusline insert position assumes AstroNvim v6's layout
  (`#opts.statusline - 4`); recheck after a major AstroNvim upgrade.

## Tag editing (HTML, Vue)

VS Code-style pair-tag editing: rename an opening tag and the closing tag
follows; type `>` and the closing tag appears. AstroNvim already bundles
[windwp/nvim-ts-autotag](https://github.com/windwp/nvim-ts-autotag) for
this (loaded on `User AstroFile`), and it aliases `vue` to its `html`
rules, so Vue `<template>` blocks work too. It only acts when the
buffer's Treesitter parser exists; without the `html` parser it silently
does nothing until `auto_install` fetches it. So pin the parsers.

Create `~/.config/nvim/lua/plugins/tag-editing.lua`:

```lua
-- Pair-tag editing (HTML, Vue, JSX/TSX): nvim-ts-autotag ships with
-- AstroNvim and renames/closes tags; it needs the Treesitter parser of
-- the buffer's language, so pin the ones it uses here.
---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      ensure_installed = { "html", "vue", "css", "javascript", "typescript", "tsx" },
    },
  },
}
```

AstroCore declares `opts_extend = { "treesitter.ensure_installed" }`, so
this list is appended to AstroNvim's defaults, not a replacement. Restart
Neovim; missing parsers install on startup.

Usage:

- **Rename:** change the opening or closing tag name in insert mode (for
  example `ciw` on `div`, type `section`, `<Esc>`); the other tag follows.
- **Auto-close:** type `<div>` and get `<div></div>`, cursor inside.
- **Debug:** `:checkhealth nvim-treesitter` lists installed parsers;
  `:checkhealth nvim-ts-autotag` and `:InspectTree` show whether the
  buffer parses.

Tag editing gotchas:

- Normal-mode edits that never enter insert mode (`r`, `x`) do not sync
  the pair.
- A parse error near the tag (unclosed attribute quote, stray `<`) breaks
  pairing until it is fixed.

## Sessions: restore terminals

AstroNvim bundles
[stevearc/resession.nvim](https://github.com/stevearc/resession.nvim)
(`<Leader>S` keys; autosaves `Last Session` and a per-cwd dirsession on
exit), but a restored session drops toggleterm terminals. A small
resession extension saves them and reopens the ones that were open.

Create `~/.config/nvim/lua/plugins/resession.lua`:

```lua
---@type LazySpec
return {
  "stevearc/resession.nvim",
  opts = { extensions = { terminals = {} } },
}
```

Create `~/.config/nvim/lua/resession/extensions/terminals.lua` (resession
loads extension `terminals` from `resession.extensions.terminals` on the
runtimepath):

```lua
-- Save toggleterm terminals (cmd, cwd, layout); reopen them on load
local M = {}

M.on_save = function()
  local ok, tt = pcall(require, "toggleterm.terminal")
  if not ok then return {} end
  local out = {}
  for _, t in ipairs(tt.get_all(true)) do -- true = include hidden
    table.insert(out, {
      cmd = t.cmd,
      dir = t.dir, -- cwd the term was spawned in
      direction = t.direction,
      open = t:is_open(),
    })
  end
  return out
end

M.on_post_load = function(data)
  vim.schedule(function() -- wait until windows/buffers are restored
    for _, t in ipairs(data or {}) do
      if t.open then
        require("astrocore").toggle_term_cmd {
          cmd = t.cmd,
          dir = t.dir,
          direction = t.direction,
        }
      end
    end
  end)
end

return M
```

Usage: save with `<Leader>Ss` (or just quit; autosave runs on exit),
restore with `<Leader>Sl` (last session) or `<Leader>S.` (this cwd). Each
terminal that was open comes back with its command, directory and layout
(float, horizontal, vertical).

Session gotchas:

- **Commands restart.** A terminal reopens by running its command again
  in a new shell; scrollback and the running process are not restored.
- **Hidden terminals** are saved but only reopened if they were open at
  save time.
- **Plain shells** (no command) come back as a default shell terminal.

## What each piece does

| Piece | Effect |
|---|---|
| `VimEnter` autocmd `cd_to_dir_arg` | `nvim <dir>` sets cwd to `<dir>`; also fixes pickers/grep root |
| `bind_to_cwd = true` | Tree root and `:cd` stay in sync both ways |
| `follow_current_file` | Tree highlights the file you switch to |
| `filtered_items` | Dotfiles and gitignored files always shown (`H` toggles) |
| `components.name = name_with_git_flags` | Appends `*+$%` + color to repo/worktree root folders |
| autocmd `neotree_repo_git_flags` + `git_event` handler | Refresh flags after focus/save/terminal/git changes |
| `tag-editing.lua` parser pin | nvim-ts-autotag renames and closes tags in HTML, Vue, JSX/TSX |
| `resession.lua` + `extensions/terminals.lua` | Sessions save and reopen toggleterm terminals |

## Gotchas

- **Disabled template files.** AstroNvim template files such as
  `lua/plugins/astrocore.lua` and `lua/community.lua` start with
  `if true then return {} end`. Edits there do nothing until that line is
  removed. The new `neo-tree.lua` does not have this line, so it is active.
- **Two-way binding.** With `bind_to_cwd = true`, changing the tree root (`<BS>`
  or `.`) also runs `:cd`. Set it to `false` if you don't want that.
- **`<Space>e` is AstroNvim's default** (`<Cmd>Neotree toggle<CR>`): tree
  rooted at cwd, open file revealed via `follow_current_file`. For a tree
  rooted at the current file's folder, run `:Neotree dir=%:p:h` instead.
- **Alternative: AstroNvim rooter.** Set `rooter = { autochdir = true }` in
  astrocore opts (or toggle with `<Leader>uA`) to auto-`cd` to the git or
  `package.json` root on every buffer switch.
- **Sessions.** resession may restore an old tree root. Run `:Neotree close`
  and reopen it.
- **One-off commands** that work without any config: `:Neotree dir=%:p:h` and
  `:Neotree reveal_force_cwd`.
- **Flags use one color.** Neo-tree's container inserts a space between
  separately highlighted chunks, so per-flag colors would render `* + %`.
- **Narrow sidebar.** At the default 30 columns, long folder names push the
  flags off the right edge. Widen with `window = { width = 40 }` in opts.
- **External commits.** A `git commit` in another terminal shows up when
  Neovim regains focus (`FocusGained`) or on the next save/re-render.
- **New repos.** Whether a folder is a repo is cached per session; a
  `git init` inside the tree needs a Neovim restart to get flags.
- **Big monorepos.** Each visible repo root runs one `git status` per
  refresh; slow repos delay the flags, not the editor (it's async).
