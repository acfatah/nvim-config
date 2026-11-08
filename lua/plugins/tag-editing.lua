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
