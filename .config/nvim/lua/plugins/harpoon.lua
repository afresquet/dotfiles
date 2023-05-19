return {
  {
    "ThePrimeagen/harpoon",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = function()
      local mark = require("harpoon.mark")
      local ui = require("harpoon.ui")

      return {
        { "<leader>a", mark.add_file, desc = "Harpoon: Add File" },
        { "<C-e>", ui.toggle_quick_menu, desc = "Harpoon: Toggle Quick Menu" },
      }
    end,
  },
}
