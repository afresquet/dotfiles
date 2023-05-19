return {
  {
    "vuki656/package-info.nvim",
    dependencies = { "MunifTanjim/nui.nvim" },
    ft = "json",
    opts = {
      hide_up_to_date = true,
      package_manager = "pnpm",
    },
    keys = function()
      local status, packageInfo = pcall(require, "package-info")

      if not status then
        return
      end

      return {
        {
          "<leader>ns",
          function()
            packageInfo.show({ force = true })
          end,
          desc = "Package Info: Show",
        },
        {
          "<leader>nu",
          packageInfo.update,
          desc = "Package Info: Update",
        },
        {
          "<leader>nd",
          packageInfo.delete,
          desc = "Package Info: Delete",
        },
        {
          "<leader>nv",
          packageInfo.change_version,
          desc = "Package Info: Change Version",
        },
        {
          "<leader>ni",
          packageInfo.install,
          desc = "Package Info: Install",
        },
      }
    end,
  },
}
