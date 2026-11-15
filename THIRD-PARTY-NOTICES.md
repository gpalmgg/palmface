# Third-party notices

Palmface's own work is under the MIT licence in [`LICENSE`](LICENSE). This file lists the work
of others that the kit ships, fetches at install time, or only names, with each licence and
credit. Each licence below was checked against the upstream licence file on 2026-11-15.

## Shipped in this repository

| Component | Where | Licence | Copyright and credit | Upstream |
|---|---|---|---|---|
| claude-hud, modified | `statusline/` (installed to `~/.claude/palmface/statusline/`) | MIT | Copyright (c) 2026 Jarrod Watts | https://github.com/jarrodwatts/claude-hud |
| Ghostty cursor shaders: `sonic_boom_cursor.glsl`, `ripple_cursor.glsl`, `ripple_rectangle_cursor.glsl`, `rectangle_boom_cursor.glsl`, `cursor_tail.glsl`, `cursor_warp.glsl`, `cursor_sweep.glsl` | `extras/ghostty/shaders/` | MIT | Copyright (c) 2026 Sahaj Bhatt | https://github.com/sahaj-b/cursor-shaders (formerly `sahaj-b/ghostty-cursor-shaders`) |
| CRT shader: `crt.glsl` | `extras/ghostty/shaders/` | Unlicense (public domain) | CRTS by Timothy Lottes, adapted for Ghostty by Qwerasd | https://gist.github.com/qwerasd205/c3da6c610c8ffe17d6d2d3cc7068f17f, from https://www.shadertoy.com/view/MtSfRK |

Notes:

- **claude-hud.** The statusline is a modified copy: the build output in `statusline/dist/` and
  its source in `statusline/src/`. It bundles no other third-party code: `dist/` imports only
  Node's built-in modules. The MIT text, with both the upstream copyright line and Palmface's
  line for the changes, is in [`statusline/LICENSE`](statusline/LICENSE) and is installed beside
  the code.
- **Cursor shaders.** The full MIT text ships next to them, in
  [`extras/ghostty/shaders/LICENSE-cursor-shaders`](extras/ghostty/shaders/LICENSE-cursor-shaders),
  identical to upstream's. `cursor_tail`, `cursor_warp` and `cursor_sweep` are an earlier
  upstream revision of each file. Three of the shaders note that they build on Inigo Quilez's
  article on 2D distance functions (https://iquilezles.org/articles/distfunctions2d/); upstream's
  MIT licence covers the files as published. Per-file provenance is in
  [`extras/ghostty/shaders/PROVENANCE.md`](extras/ghostty/shaders/PROVENANCE.md).
- **CRT shader.** The public-domain dedication and both credits stay intact in the file's own
  header, as its author asks.

## Fetched at install time (not in this repository)

The terminal layer fetches these tmux plugins into `~/.config/palmface/tmux/plugins/`, each at the
exact commit pinned in `terminal/tmux/plugins.list`. The post script checks the commit before the
plugin is used and refuses anything else. Each clone carries its own licence file; the licence
lines below were checked at the pinned commits.

| Plugin | Pinned commit | Licence | Copyright | Upstream |
|---|---|---|---|---|
| rose-pine/tmux | `39e39e76f6710b40a4b66222c6688ece1da8d3a4` | MIT | Copyright (c) 2023 Rosé Pine | https://github.com/rose-pine/tmux |
| tmux-plugins/tmux-resurrect | `cff343cf9e81983d3da0c8562b01616f12e8d548` | MIT | Copyright (C) 2014 Bruno Sutic | https://github.com/tmux-plugins/tmux-resurrect |
| tmux-plugins/tmux-continuum | `0698e8f4b17d6454c71bf5212895ec055c578da0` | MIT | Copyright (C) Bruno Sutic | https://github.com/tmux-plugins/tmux-continuum |

## Installed by Homebrew, or only named

None of these is copied into the kit.

- **Maple Mono**, the font. SIL Open Font License 1.1, Copyright 2022 The Maple Mono Project
  Authors (https://github.com/subframe7536/maple-font). The `Brewfile` installs it with the
  `font-maple-mono` cask, and Palmface's Ghostty config names it.
- **Rosé Pine**, the colours. The theme is MIT, Copyright (c) 2023 Rosé Pine
  (https://github.com/rose-pine/rose-pine-theme). The palette is MIT, Copyright (c) mvllow
  (https://github.com/rose-pine/rose-pine-palette). Palmface's Ghostty config names Ghostty's
  bundled "Rose Pine Moon" and "Rose Pine Dawn" themes and uses three palette colours
  (`#ebbcba`, `#232136`, `#c4a7e7`). The starship prompt names the palette's colours and maps
  them to your terminal's ANSI slots.
- **Ghostty's bundled themes** come from iTerm2-Color-Schemes
  (https://github.com/mbadolato/iTerm2-Color-Schemes), under an MIT-style licence,
  Copyright (c) 2011 to Present Mark Badolato, in which each theme stays under its own author's
  licence. Palmface ships no theme files.
- **The tools in the `Brewfile`** (Ghostty, starship, tmux, eza, bat, fzf, zoxide, delta, jq,
  node, figlet, cowsay, lolcat and the optional ones) are installed by you through Homebrew,
  under their own licences. The kit's cowfiles are data for cowsay and contain none of its code.
- **Plugins** named in [`docs/plugins.md`](docs/plugins.md), including `superpowers`, are
  referenced by name for you to install. None is vendored.

## Written for Palmface

The `CLAUDE.md`, the reference guides, the hooks, the skills, the critter bank, the owl, cat and
sleepycat cowfiles, the zsh, tmux, starship and Ghostty configs, the launcher, the starters, the
scripts and the tests were written for Palmface and are under its MIT licence.

## MIT licence text

The MIT-licensed components above (claude-hud; the cursor shaders; the tmux plugins in their
own clones) are each under this text, with their own copyright line from the tables above:

```
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
