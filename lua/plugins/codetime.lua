return {
  {
    "acfatah/codetime.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  {
    "rebelot/heirline.nvim",
    opts = function(_, opts)
      -- AstroNvim v6 statusline tail: fill, lsp, virtual_env, treesitter, nav, mode
      -- codetime.dev dashboard total (all editors/machines), local codetime.nvim total as fallback
      table.insert(opts.statusline, #opts.statusline - 4, {
        condition = function() return package.loaded.codetime_dev ~= nil or package.loaded.codetime ~= nil end,
        provider = function()
          local text = package.loaded.codetime_dev and require("codetime_dev").format_today()
          if not text and package.loaded.codetime then text = require("codetime").format_today() end
          return text and ("󱑎 " .. text .. " ") or ""
        end,
      })

      -- refresh while idle; the value otherwise only redraws on other events
      local timer = vim.uv.new_timer()
      timer:start(60000, 60000, vim.schedule_wrap(function() vim.cmd.redrawstatus() end))
    end,
  },
}
