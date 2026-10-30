local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
local app_icons = require("helpers.app_icons")

local spaces = {}
local brackets = {}
local paddings = {}
local workspaces = {}
local focused_workspace = nil

-- Retry on empty result: at login sketchybar can start before AeroSpace's daemon is
-- ready to answer queries, and without the retry the workspace list comes back empty, no
-- items get created, and the bar stays broken until sketchybar is restarted. Worst case
-- 10 * 0.2s = 2s blocking.
-- The launchd agent's PATH has no Homebrew prefix, so every aerospace call in this file
-- is absolute.
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
    if is_selected then
      spaces[i]:set({ drawing = true })
      brackets[i]:set({ drawing = true })
      paddings[i]:set({ drawing = true })
    end
    ::next::
  end
end

local last_icons = {}

local function render(i, workspace, apps)
  local visible = focused_workspace == workspace or #apps > 0
  local icon_line = ""
  for _, app in ipairs(apps) do
    icon_line = icon_line .. " " .. (app_icons[app] or app_icons["Default"])
  end
  if #apps == 0 then icon_line = " —" end

  local state = icon_line .. (visible and "+" or "-")
  if last_icons[workspace] == state then return end
  last_icons[workspace] = state
  sbar.animate("tanh", 10, function()
    spaces[i]:set({ drawing = visible, label = icon_line })
    brackets[i]:set({ drawing = visible })
    paddings[i]:set({ drawing = visible })
  end)
end

-- One AeroSpace query covers every workspace. AeroSpace answers queries on the thread
-- that handles keybindings, so a query per workspace on every focus change delayed the
-- next keypress. Focus events that arrive while a query is running collapse into one
-- follow-up refresh.
local refreshing, dirty = false, false
local function refresh_all()
  if refreshing then dirty = true return end
  refreshing = true
  sbar.exec(
    "/opt/homebrew/bin/aerospace list-windows --all --format '%{workspace}%{app-name}%{workspace-is-focused}' --json",
    function(windows)
      local apps = {}
      local focused = nil
      if type(windows) == "table" then
        for _, w in ipairs(windows) do
          apps[w.workspace] = apps[w.workspace] or {}
          table.insert(apps[w.workspace], w["app-name"])
          if w["workspace-is-focused"] then focused = w.workspace end
        end
      end
      -- An empty focused workspace has no window to report it; the workspace-change
      -- event has already set the highlight in that case.
      if focused and focused ~= focused_workspace then highlight(focused) end
      for i, workspace in ipairs(workspaces) do
        if workspace ~= "0" and spaces[i] then render(i, workspace, apps[workspace] or {}) end
      end
      refreshing = false
      if dirty then dirty = false refresh_all() end
    end
  )
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

refresh_all()

local observer = sbar.add("item", {
  drawing = false,
  updates = true,
})

observer:subscribe("aerospace_workspace_change", function(env)
  highlight(env.FOCUSED_WORKSPACE)
  refresh_all()
end)

sbar.add("event", "aerospace_focus_change")
observer:subscribe("aerospace_focus_change", function(_)
  refresh_all()
end)

observer:subscribe("space_windows_change", function(env)
  refresh_all()
end)

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
