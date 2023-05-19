-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- Move selected block and auto indent
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move Block Down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move Block Up" })

-- Keep cursor at same spot when joining lines
map("n", "J", "mzJ`z", { desc = "Join Lines" })

-- Center cursor vertically when half-page jumping
map("n", "<C-d>", "<C-d>zz", { desc = "Jump Half Page Down" })
map("n", "<C-u>", "<C-u>zz", { desc = "Jump Half Page Up" })

-- Center search results
map({ "n", "x", "o" }, "n", "nzzzv", { desc = "Next Result" })
map({ "n", "x", "o" }, "N", "Nzzzv", { desc = "Previous Result" })

-- Paste over selection while keeping the current clipboard
map("x", "<leader>p", '"_dP', { desc = "Paste and keep clipboard" })

-- Void when using x
map("n", "x", '"_x', { desc = "Delete At Cursor" })

-- Tmux Navigator
map("n", "<C-h>", "<cmd>TmuxNavigateLeft<CR>", { desc = "window left" })
map("n", "<C-l>", "<cmd>TmuxNavigateRight<CR>", { desc = "window right" })
map("n", "<C-j>", "<cmd>TmuxNavigateDown<CR>", { desc = "window down" })
map("n", "<C-k>", "<cmd>TmuxNavigateUp<CR>", { desc = "window up" })
