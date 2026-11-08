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
