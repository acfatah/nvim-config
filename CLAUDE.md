# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

Personal AstroNvim v6 config (`~/.config/nvim`), plugins managed by
lazy.nvim. Remote: https://github.com/acfatah/nvim-config (`origin`).
`docs/SETUP.md` is the human setup guide for other machines.

## Commands

No build or test suite. Verify changes by running Neovim headless against
the real config:

```bash
# install / sync plugins to lazy-lock.json
nvim --headless "+Lazy! install" +qa
nvim --headless "+Lazy! restore" +qa        # match lockfile exactly

# smoke test: load config, fire VeryLazy, check messages + statusline
nvim --headless +'lua vim.defer_fn(function()
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy" })
  vim.defer_fn(function()
    print(vim.fn.execute("messages"))
    print(vim.api.nvim_eval_statusline(vim.o.statusline, {}).str)
    vim.cmd "qa!"
  end, 1500)
end, 1000)'

# format / lint (configured, not installed on this machine)
stylua lua/ init.lua
selene lua/
```

- `VeryLazy` never fires in headless mode (no UI); trigger it manually as
  above or plugins with `event = "VeryLazy"` stay unloaded.
- Keymaps: check with `vim.fn.maparg("<Space>e", "n", false, true)`.
- Style (`.stylua.toml`): 2 spaces, 120 cols, double quotes, no call
  parentheses for single string/table args (`require "x"`).

## Architecture

Load order: `init.lua` bootstraps lazy.nvim → `lua/lazy_setup.lua` imports
`astronvim.plugins` (AstroNvim v6, pinned `version = "^6"`), then
`community` (astrocommunity), then `plugins` (every file in
`lua/plugins/`) → `lua/polish.lua` last.

**Template stubs are inert.** `lua/community.lua`, `lua/polish.lua` and
`lua/plugins/{astrocore,astrolsp,astroui,mason,none-ls,treesitter,user}.lua`
start with `if true then return {} end`; edits there do nothing until that
line is removed. Active custom files:

| File | Purpose |
|---|---|
| `plugins/neo-tree.lua` | cd into `nvim <dir>` arg; `__git_ps1` flags on repo roots; tracks neo-tree `main` |
| `plugins/diffview.lua` | diffview.nvim + `<Leader>gD/gh/gH/gm` |
| `plugins/codetime-dev.lua` | codetime.dev dashboard client (acfatah) + heirline statusline item |

**Extending AstroNvim, not replacing it.** Keymaps and autocmds go through
an `AstroNvim/astrocore` entry in the plugin's `specs` (`opts.mappings`,
`opts.autocmds`), keeping them next to the plugin they belong to. Plugin
`opts` merge over AstroNvim's defaults; use `opts = function(_, opts)` and
mutate when list fields matter, because lazy's table merge replaces lists
by index. AstroNvim's own plugin specs live in
`~/.local/share/nvim/lazy/AstroNvim/lua/astronvim/plugins/` — read them
before overriding (e.g. gitsigns keymaps, neo-tree source selector, heirline
statusline).

**Cross-file couplings:**

- Statusline item (`plugins/codetime-dev.lua`) is inserted at
  `#opts.statusline - 4`, which assumes AstroNvim v6's tail
  `fill, lsp, virtual_env, treesitter, nav, mode`. It shows
  `codetime_dev.format_today()`, empty until the first dashboard fetch.
- Neo-tree repo-root flags wrap the filesystem `name` component
  (`opts.filesystem.components.name`); flags are a single chunk because
  neo-tree's container pads a space between adjacent chunks. Neo-tree's
  `git_event` misses repos nested under a non-git root, hence the extra
  `FocusGained/BufWritePost/TermClose/ShellCmdPost` refresh autocmd.
- neo-tree has `version = false` until a release includes upstream
  `162f9b9` (E95 stale-tab render fix); remove it then.
- Heirline's winbar is free for unlisted buffers, but Neo-tree's winbar is
  taken by its source selector tabs.

**Owned plugin** (edit upstream, not here): `acfatah/codetime-dev.nvim`
(`~/personal/codetime-dev.nvim`). The codetime.dev token lives in
`~/.codetime/config.json` or `$CODETIME_TOKEN`, never in this repo.

## Conventions

- Commit `lazy-lock.json` with any plugin add/update.
- Keep `docs/SETUP.md` in sync when a plugin file changes: it embeds each
  file's full Lua and is hard-wrapped at 80 columns.
- `plans/` is local-only (excluded via `.git/info/exclude`).
