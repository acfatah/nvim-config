-- Open terminals floating by default (toggleterm's default is horizontal).
-- Explicit directions (<Leader>th / <Leader>tv, neo-tree Th / Tv) still win.
---@type LazySpec
return {
  "akinsho/toggleterm.nvim",
  opts = { direction = "float" },
}
