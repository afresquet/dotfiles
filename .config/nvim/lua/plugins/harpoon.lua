return {
  {
    "ThePrimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = function()
      local mark_status, mark = pcall(require, "harpoon.mark")
      local ui_status, ui = pcall(require,"harpoon.ui")

      if not mark_status or not ui_status then
        return
      end

      return {
        { "<leader>a", mark.add_file, desc = "Harpoon: Add File" },
        { "<C-e>", ui.toggle_quick_menu, desc = "Harpoon: Toggle Quick Menu" },
      }
    end,
  },
}
