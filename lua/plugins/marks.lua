-- Swap ' and ` for marks: ' jumps to the exact line and column (Vim's `),
-- and ` jumps to the first non-blank of the line (Vim's ').
-- The exact jump is the more useful one, and ' is easier to reach.
local swap = {
  ["'"] = { "`", desc = "Jump to mark (exact position)" },
  ["`"] = { "'", desc = "Jump to mark (line)" },
}

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    mappings = {
      n = swap,
      x = swap,
      o = swap,
    },
  },
}
