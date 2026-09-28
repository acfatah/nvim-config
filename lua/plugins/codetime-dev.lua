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
