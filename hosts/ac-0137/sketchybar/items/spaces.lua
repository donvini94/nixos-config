local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}
local brackets = {}
local paddings = {}
local workspaces = {}
local focused_workspace = nil

-- Retry on empty result: at login, sketchybar can start before AeroSpace's
-- daemon is ready to answer queries. Without retry, the workspace list is
-- empty, no items get created, and the bar stays broken until the sketchybar
-- process is fully restarted. Total worst case: 10 * 0.2s = 2s blocking.
-- AeroSpace is a Homebrew cask (hosts/ac-0137/homebrew.nix), and the launchd agent's
-- PATH is [sketchybar] ++ extraPackages ++ environment.systemPath — no brew prefix. Every
-- aerospace call in this file is therefore absolute.
local function aerospace_query(args)
  for _ = 1, 10 do
    local file = io.popen("/opt/homebrew/bin/aerospace " .. args)
    local result = file:read("*a")
    file:close()
    if result and result:match("%S") then return result end
    os.execute("sleep 0.2")
  end
  return ""
end

local function get_workspaces()
  local ws = {}
  for name in aerospace_query("list-workspaces --all"):gmatch("[^\r\n]+") do
    table.insert(ws, name)
  end
  return ws
end

local function get_current_workspace()
  return aerospace_query("list-workspaces --focused"):match("[^\r\n]+")
end

-- Instant highlight update — no subprocess, just color swaps
local function highlight(new_focused)
  focused_workspace = new_focused
  for i, workspace in ipairs(workspaces) do
    if workspace == "0" or not spaces[i] then goto next end
    local is_selected = workspace == new_focused
    spaces[i]:set({
      icon = { highlight = is_selected },
      label = { highlight = is_selected },
      background = {
        border_color = is_selected and colors.blue or colors.bg2,
      },
    })
    brackets[i]:set({
      background = {
        border_color = is_selected and colors.grey or colors.bg2,
      },
    })
    -- Always show focused workspace even if empty
    if is_selected then
      spaces[i]:set({ drawing = true })
      brackets[i]:set({ drawing = true })
      paddings[i]:set({ drawing = true })
    end
    ::next::
  end
end

-- Async icon + visibility refresh for a single workspace
local function refresh_workspace(i, workspace)
  sbar.exec(
    "/opt/homebrew/bin/aerospace list-windows --workspace " .. workspace .. " --format '%{app-name}' --json",
    function(apps)
      local is_selected = focused_workspace == workspace
      local has_windows = #apps > 0
      local visible = is_selected or has_windows

      local icon_line = ""
      for _, app in ipairs(apps) do
        local lookup = app_icons[app["app-name"]]
        icon_line = icon_line .. " " .. (lookup or app_icons["Default"])
      end
      if not has_windows then
        icon_line = " —"
      end

      sbar.animate("tanh", 10, function()
        spaces[i]:set({ drawing = visible, label = icon_line })
        brackets[i]:set({ drawing = visible })
        paddings[i]:set({ drawing = visible })
      end)
    end
  )
end

-- Refresh all workspace icons and visibility
local function refresh_all()
  for i, workspace in ipairs(workspaces) do
    if workspace ~= "0" and spaces[i] then
      refresh_workspace(i, workspace)
    end
  end
end

workspaces = get_workspaces()
focused_workspace = get_current_workspace()

for i, workspace in ipairs(workspaces) do
  if workspace == "0" then goto continue end
  local selected = workspace == focused_workspace

  local space = sbar.add("item", "space." .. workspace, {
    icon = {
      font = { family = settings.font.numbers },
      string = workspace,
      padding_left = 15,
      padding_right = 8,
      color = colors.white,
      highlight_color = colors.blue,
      highlight = selected,
    },
    label = {
      padding_right = 20,
      color = colors.grey,
      highlight_color = colors.white,
      font = "sketchybar-app-font:Regular:16.0",
      y_offset = -1,
      highlight = selected,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.bg1,
      border_width = 1,
      height = 26,
      border_color = selected and colors.blue or colors.bg2,
    },
    popup = { background = { border_width = 5, border_color = colors.black } }
  })

  spaces[i] = space

  brackets[i] = sbar.add("bracket", { space.name }, {
    background = {
      color = colors.transparent,
      border_color = selected and colors.grey or colors.bg2,
      height = 28,
      border_width = 2,
    }
  })

  paddings[i] = sbar.add("item", "space.padding." .. workspace, {
    width = settings.group_paddings,
  })

  local space_popup = sbar.add("item", {
    position = "popup." .. space.name,
    padding_left = 5,
    padding_right = 0,
    background = {
      drawing = true,
      image = { corner_radius = 9, scale = 0.2 },
    }
  })

  space:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "other" then
      space_popup:set({ background = { image = "space." .. workspace } })
      space:set({ popup = { drawing = "toggle" } })
    else
      sbar.exec("/opt/homebrew/bin/aerospace workspace " .. workspace)
    end
  end)

  space:subscribe("mouse.exited", function(_)
    space:set({ popup = { drawing = false } })
  end)
  ::continue::
end

-- Initial state
refresh_all()

-- Central event handler
local observer = sbar.add("item", {
  drawing = false,
  updates = true,
})

observer:subscribe("aerospace_workspace_change", function(env)
  highlight(env.FOCUSED_WORKSPACE)  -- instant
  refresh_all()                      -- async icon + visibility update
end)

observer:subscribe("space_windows_change", function(env)
  refresh_all()
end)

-- Spaces/menus toggle indicator
local spaces_indicator = sbar.add("item", {
  padding_left = -3,
  padding_right = 0,
  icon = {
    padding_left = 8,
    padding_right = 9,
    color = colors.grey,
    string = icons.switch.on,
  },
  label = {
    width = 0,
    padding_left = 0,
    padding_right = 8,
    string = "Spaces",
    color = colors.bg1,
  },
  background = {
    color = colors.with_alpha(colors.grey, 0.0),
    border_color = colors.with_alpha(colors.bg1, 0.0),
  }
})

spaces_indicator:subscribe("swap_menus_and_spaces", function(env)
  local currently_on = spaces_indicator:query().icon.value == icons.switch.on
  spaces_indicator:set({
    icon = currently_on and icons.switch.off or icons.switch.on
  })
end)

spaces_indicator:subscribe("mouse.entered", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 1.0 },
        border_color = { alpha = 1.0 },
      },
      icon = { color = colors.bg1 },
      label = { width = "dynamic" }
    })
  end)
end)

spaces_indicator:subscribe("mouse.exited", function(env)
  sbar.animate("tanh", 30, function()
    spaces_indicator:set({
      background = {
        color = { alpha = 0.0 },
        border_color = { alpha = 0.0 },
      },
      icon = { color = colors.grey },
      label = { width = 0 }
    })
  end)
end)

spaces_indicator:subscribe("mouse.clicked", function(env)
  sbar.trigger("swap_menus_and_spaces")
end)
