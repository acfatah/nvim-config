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
