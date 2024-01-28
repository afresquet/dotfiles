local wezterm = require 'wezterm'

local xcursor_size = nil
local xcursor_theme = nil

local cursor_theme_success, cursor_theme_stdout, _ = wezterm.run_child_process({ "gsettings", "get", "org.gnome.desktop.interface",
  "cursor-theme" })
if cursor_theme_success then
  xcursor_theme = cursor_theme_stdout:gsub("'(.+)'\n", "%1")
end

local cursor_size_success, cursor_size_stdout, _ = wezterm.run_child_process({ "gsettings", "get", "org.gnome.desktop.interface",
  "cursor-size" })
if cursor_size_success then
  xcursor_size = tonumber(cursor_size_stdout)
end

return {
  color_scheme = "Catppuccin Mocha",
  window_background_opacity = 0.95,
  hide_tab_bar_if_only_one_tab = true,
  window_close_confirmation = "NeverPrompt",
  window_padding = {
    left = 0,
    right = 0,
    top = 0,
    bottom = 0,
  },

  xcursor_theme = xcursor_theme,
  xcursor_size = xcursor_size,
}
