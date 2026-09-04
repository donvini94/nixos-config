-- Keep the macOS display awake during an mpv session WITHOUT stealing focus.
--
-- Why this exists:
--   mpv's built-in screensaver defeat (stop-screensaver=yes) works by *declaring user
--   activity*, which re-activates mpv as the frontmost app. Under AeroSpace, a window on a
--   hidden workspace grabbing focus makes the WM switch to that workspace -> rapid 1<->8
--   flicker while a backgrounded video plays.
--
--   So mpv.conf sets stop-screensaver=no (kills the focus steal), and this script instead
--   holds a PASSIVE power assertion via `caffeinate -d`, which prevents display sleep but
--   never touches app activation. Net result: the screen stays on for the entire session,
--   with zero flicker -- regardless of how mpv was launched (terminal, yazi, Finder).
--
--   `caffeinate -w <pid>` self-terminates when this mpv process exits, so nothing leaks.

local utils = require "mp.utils"

mp.command_native({
    name = "subprocess",
    args = { "/usr/bin/caffeinate", "-d", "-w", tostring(utils.getpid()) },
    detach = true,          -- fire-and-forget; -w handles teardown on mpv exit
    playback_only = false,  -- hold the assertion for the entire mpv lifetime
})
