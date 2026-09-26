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
  },
}
