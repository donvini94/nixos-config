# zellij

Open this any time with **`Ctrl g` `?`**.

---

## The one rule

It is vim, not tmux. Zellij starts **locked** and owns exactly one key —
everything else goes straight to whatever is running in the pane (nvim, fish, an
agent, another zellij).

```
Ctrl g          zellij layer ON   ->  the status bar now shows the whole keymap
Esc  (or Ctrl g)  zellij layer OFF ->  back to typing
```

While the layer is on, keys act on the workspace and **stay** on: `Ctrl g d d d`
is three splits, not one. Press `Esc` when you are done.

The exception is anything that hands the keyboard to something else — the
session manager, the file picker, this cheatsheet, `E` — which drops the layer
for you, because you are about to type into it.

Read the bottom bar. It changes with the mode and always lists what is available
right now. Nothing below needs memorising.

---

## `Ctrl g` then…

### Move around

| key | does |
| --- | --- |
| `h j k l` | move focus (left/down/up/right); `h`/`l` roll over to the next tab |
| `H J K L` | move the *pane itself* in that direction |
| `Tab` | last tab |
| `[` `]` | previous / next tab |
| `1`…`9` | jump to tab N |

### Make panes

| key | does |
| --- | --- |
| `n` | new pane, zellij picks the spot |
| `d` | split **d**own |
| `v` | split right (**v**ertical divider) |
| `x` | close the focused pane |
| `z` | **z**oom the focused pane fullscreen (toggle) |
| `f` | show/hide the **f**loating pane layer — opens one if there is none |
| `e` | **e**mbed a floating pane / float an embedded one |
| `i` | p**i**n a floating pane so it stays on top |
| `c` | new tab (**c**reate) |
| `Space` | cycle the tab through zellij's preset layouts |

### Resize

| key | does |
| --- | --- |
| `=` / `-` | grow / shrink the focused pane |
| `r` | sticky resize mode, for per-edge control |

### Scrollback

| key | does |
| --- | --- |
| `/` | search the scrollback |
| `E` | open the scrollback in your editor — then save it anywhere |
| `s` | sticky scroll mode (see below) |

### Sessions and help

| key | does |
| --- | --- |
| `w` | session manager: list, attach, rename, resurrect |
| `F` | file picker |
| `D` | **d**etach — the session keeps running without you |
| `?` | this cheatsheet |
| `Ctrl q` | quit and **kill** the session |

---

## Sticky modes

`Ctrl g` then the mode letter. Stay as long as you like; `Esc` returns to typing.
`Ctrl p`/`Ctrl t`/`Ctrl r`/`Ctrl m`/`Ctrl s`/`Ctrl o` hop straight between modes
once you are already unlocked.

### `p` — pane

`h j k l` focus · `n` new · `d` down · `v` right · `s` stacked · `x` close
`f` fullscreen · `F` fullscreen without the bars · `w` floating layer
`e` embed/float · `i` pin · `z` frames on/off · `c` rename · `b` break out to a new tab
`p` next pane · `;` last pane

### `t` — tab

`h`/`l` prev/next · `n` new · `x` close · `c` rename · `b` break pane out
`[` `]` move this tab left/right · `1`…`9` jump · `Tab` last tab
`s` **sync**: every keystroke goes to every pane in the tab (run the same command on four servers at once)

### `r` — resize

`h j k l` grow that edge · `H J K L` shrink it · `=`/`-` grow/shrink overall

### `m` — move

`h j k l` move the pane · `n`/`Tab` next position · `p` previous position

### `s` — scroll / search

`j k` line · `d u` half page · `Ctrl f` `Ctrl b` page · `g`/`G` top/bottom
`[` `]` jump to the previous/next **shell prompt**
`m` select the command at this position · `y` copy the last command's output
`/` search, then `n`/`N` for next/previous, `c` case, `w` wrap, `o` whole word
`e` open the scrollback in your editor

### `o` — session

`d` detach · `w` session manager · `c` configuration · `p` plugin manager
`l` layout manager · `a` about
`]` climb out to the host session · `[` dive into the nested one · `f` fullscreen this session in its host

---

## Sessions: the actual point

A zellij session is a **server process**, not a window. It keeps running when you
detach, when you close the terminal, and when your SSH link drops. Panes, their
working directories and their running commands are serialised, so they also come
back after the server restarts or the box reboots.

Start it where the work is. An agent running on alucard should live in a zellij
**on alucard** — then your Mac and dracula are just two viewers of the same
session, and neither one dying interrupts anything.

```fish
zj                      # attach to (or create) a session named after $PWD
zj myproj               # attach to (or create) "myproj"
zj myproj dev           # ...creating it with the `dev` layout if it is new
zjr Bereitserver        # same, but the session runs on Bereitserver
zjr Bereitserver build  # ...named "build"
zjl                     # list sessions here
zjls Bereitserver       # list sessions there
```

`zj` and `zjr` never re-run a layout against a live session. Re-attaching shows
you exactly what you left.

Detach with `Ctrl g D`. Closing the terminal detaches too. `Ctrl g Ctrl q` is the
only thing that kills a session.

### Nesting

A zellij inside a zellij (yours, wrapping alucard's) just works: focus the pane
and your keys drive the inner session. `Ctrl g o ]` climbs back out to the outer
one.

### Resurrecting

Exited sessions stay in the session manager (`Ctrl g w`) with their layout and
commands. Give a session a descriptive name before you quit it and it becomes a
saved context you can rebuild months later.

---

## Layouts

A layout is a starting arrangement, applied once at creation.

```fish
zellij -l dev           # shell + watch + scratch, in $PWD
zellij -l agent         # big agent pane + inspector, plus a review tab
zellij -l bereit        # btop / yazi / lazydocker on Bereitserver, over one SSH connection
zellij -l work          # acGPT compose dir
zellij -l welcome       # zellij's own session picker
```

They live in `~/.config/zellij/layouts/` (`/etc/zellij/layouts/` on alucard) and
are generated from `hm-modules/zellij/lib.nix`. A new one is a few lines there.

`Ctrl g o l` opens the layout manager, which can also save the arrangement you
built by hand back out to a layout file.

---

## Mouse

Clicking works: panes, tabs, dragging borders, scrolling. `Ctrl`+scroll resizes.
Selecting text copies it to the system clipboard automatically.

---

## Things that bite

- **`Ctrl g` does nothing.** You are inside a nested session and the inner one is
  handling the key — that is the intended behaviour. `Ctrl g o ]` to climb out.
- **A pane says the command exited.** `Enter` re-runs it. Layout panes are kept
  around on exit on purpose so you can see what happened.
- **`Ctrl q` killed my work.** It kills the session. `Ctrl g D` detaches.
- **A pane came back empty after a reboot.** Only the last 10 000 lines per pane
  are serialised; the command is re-runnable but its live output is gone.
