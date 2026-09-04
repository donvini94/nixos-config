-- Modus Vivendi palette (protesilaos/modus-themes)
-- WCAG-compliant, high-contrast colors designed for readability
return {
  black = 0xff000000,     -- bg-main
  white = 0xffffffff,     -- fg-main
  red = 0xffff5f59,       -- red
  green = 0xff44bc44,     -- green
  blue = 0xff2fafff,      -- blue
  yellow = 0xffd0bc00,    -- yellow
  orange = 0xffffa849,    -- yellow-warmer
  magenta = 0xfffeacd0,   -- magenta
  cyan = 0xff00d3d0,      -- cyan
  grey = 0xffa8a8a8,      -- fg-dim
  transparent = 0x00000000,

  bar = {
    bg = 0xf0000000,      -- bg-main with slight alpha
    border = 0xff646464,  -- border
  },
  popup = {
    bg = 0xe0000000,      -- bg-main with alpha
    border = 0xff646464,  -- border
  },
  bg1 = 0xff1e1e1e,      -- bg-dim
  bg2 = 0xff535353,       -- bg-active

  with_alpha = function(color, alpha)
    if alpha > 1.0 or alpha < 0.0 then return color end
    return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
  end,
}
