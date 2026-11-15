# Shader provenance

Palmface ships only shaders whose upstream licence is permissive. Each one was checked
against its upstream file and licence on 2026-11-14. Shaders with no licence, a
non-commercial licence, or no traceable upstream were left out.

| Shader | Upstream | Licence | Credit | Local copy vs upstream |
|---|---|---|---|---|
| `sonic_boom_cursor.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/sonic_boom_cursor.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | identical |
| `ripple_cursor.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/ripple_cursor.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | identical |
| `ripple_rectangle_cursor.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/ripple_rectangle_cursor.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | identical |
| `rectangle_boom_cursor.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/rectangle_boom_cursor.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | identical |
| `cursor_tail.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/cursor_tail.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | an earlier upstream revision (before the sRGB helper was added) |
| `cursor_warp.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/cursor_warp.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | an earlier upstream revision (before the sRGB helper was added) |
| `cursor_sweep.glsl` | https://github.com/sahaj-b/ghostty-cursor-shaders (`ghostty/cursor_sweep.glsl`) | MIT | Copyright (c) 2026 Sahaj Bhatt | an earlier upstream revision (before the sRGB helper was added) |
| `crt.glsl` | https://gist.github.com/qwerasd205/c3da6c610c8ffe17d6d2d3cc7068f17f | Unlicense (public domain), stated in the file | CRTS by Timothy Lottes, adapted for Ghostty by Qwerasd | identical; licence header kept intact |

- The MIT licence text for the cursor shaders is in `LICENSE-cursor-shaders` next to them,
  as MIT requires. The upstream repository may since have moved to `sahaj-b/cursor-shaders`.
- Three cursor shaders note that they build on Inigo Quilez's 2D distance-function article
  (https://iquilezles.org/articles/distfunctions2d/); the upstream repository's MIT licence
  covers the files as published.
- `crt.glsl` is a modified version of Timothy Lottes' public-domain CRT shader
  (https://www.shadertoy.com/view/MtSfRK); its full Unlicense header stays in the file.
