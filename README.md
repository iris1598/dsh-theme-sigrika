# dsh-theme-warm

A warm cream-and-terracotta theme for the **DeepSeek Harness** Web GUI: a sand-toned
texture in the sidebar, a soft ornament behind the main content area, and a
terracotta accent, with a dark mode derived from the same hues.

|  |  |
|---|---|
| Surfaces | cream `#faf6ef`, raised `#fffcf7` |
| Accent | terracotta `#a85632` (dark `#e0915f`) |
| Sidebar | sand `#f2e6cd` + a 25%-opacity texture |
| Dark mode | warm brown `#1c1510` family, same hues re-derived |

<p align="center">
  <!-- Drop a screenshot here: <img src="preview.png" width="720" alt="dsh-theme-warm"> -->
</p>

## Requirements

- DeepSeek Harness `0.2.0-rc.2` or newer, on the **Web** surface (the `web` or
  `desktop` profile). It is a browser-side theme; it does nothing on the TUI.
- Node.js, for the install script's resolution pre-flight.

## Install

The theme lives in the `dsh-theme-warm/` folder of this repository. Both routes
below assume you are **inside that folder**.

### Route A — as a bundle (npm, or straight from GitHub)

The package declares `dsh.bundle.patch`, so it installs like any other DSH bundle:
it lands in the profile's `node_modules`, gets listed in `dsh.profile.bundles`, and
its patch inserts the Loader row.

Because the package sits in a subdirectory, a git install needs pnpm's `#path:`
parameter — npm cannot install a package from a repository subdirectory.

```powershell
cd "$env:USERPROFILE\.dsh\profiles\desktop"

# straight from GitHub, once pushed
pnpm add "github:<you>/<repo>#path:dsh-theme-warm"

# or from a local clone
pnpm add "C:\path\to\repo\dsh-theme-warm"
```

Then add `"dsh-theme-warm"` to `dsh.profile.bundles` in that profile's
`package.json`, or install it from the GUI's **Settings → Plugins** page.

Publishing to npm first makes this simpler for everyone else: `cd dsh-theme-warm`,
`npm publish`, and then it is a plain `pnpm add dsh-theme-warm` with no `#path:`.

### Route B — from a clone, no npm

```powershell
# Windows
cd dsh-theme-warm
pwsh -File install.ps1 -Profile desktop
```

```bash
# macOS / Linux
cd dsh-theme-warm
bash install.sh --profile desktop     # or: chmod +x install.sh && ./install.sh
```

Both take `--profile` (default `desktop`) and `--uninstall`, and `--dsh-home` /
`-DshHome` if your config root is not `$DSH_HOME` or `~/.dsh`.

The script copies the package to `$DSH_HOME/themes/dsh-theme-warm/`, writes a
marker-delimited row into `$DSH_HOME/profiles/<profile>/cordis.patch.yml` (it never
touches your own entries), and then reproduces the Loader's own resolution of that
row — rolling it back if it would not mount.

### Restart

`cordis.patch.yml` is read **at boot**. Restart dsh, then refresh the page.

Confirm the entry started:

```
cordis_inspect_query platform=host provider=Config method=listConfigs
```

Look for `include:theme-warm`, or just fetch an asset:

```powershell
Invoke-WebRequest "http://127.0.0.1:19387/theme-warm/sidebar-light.webp" -Method Head
```

## Uninstall

```powershell
pwsh -File install.ps1 -Profile desktop -Uninstall
```

```bash
./install.sh --profile desktop --uninstall
```

Removes the row and the copied package. The theme disposes cleanly at runtime too:
both the token layer and the injected stylesheet are bound to the plugin's fiber,
so disabling it restores the stock look exactly.

## Repository layout

```
<repo>/
├── dsh-theme-warm/          <- the installable package
│   ├── package.json             the plugin manifest: dsh.bundle.patch + dsh.client
│   ├── cordis.patch.yml         the Loader row this package contributes
│   ├── lib/index.js             host half  — serves the artwork from media/
│   ├── lib/client.js            browser half — 44 tokens + the injected artwork rules
│   ├── media/                   the four delivered WebP images (576 KB total)
│   ├── install.ps1              Route B installer, Windows
│   ├── install.sh               Route B installer, macOS / Linux
│   ├── README.md                this file
│   └── LICENSE
├── 主体.png                 <- source artwork, ~14 MB, not needed to run the theme
├── 侧栏.png
└── 顶栏装饰.jpg
```

The three originals are the source the `media/` images were derived from. They are
excluded from the npm package by the `files` field, but a plain `git add -A` at the
repository root **will** commit all 14 MB of them. To keep them out, either delete
them or add a `.gitignore` at the repository root containing:

```gitignore
主体.png
侧栏.png
顶栏装饰.jpg
```

## How it works

Three things, and the split matters:

1. **Tokens carry the colour work.** 44 `--dsw-*` overrides, light and dark, applied
   through `ctx.theme.overrideTokens`. `bg-base` is deliberately translucent
   (0.52 light / 0.58 dark) — it is the outermost canvas, and its opacity is the
   knob controlling how strongly the ornament reads through the UI. `bg-layer-*`
   stay near-opaque so cards keep their contrast.

2. **One injected stylesheet paints the two images.** They cannot be tokens:
   `--dsw-alias-bg-base` is consumed through the `background` **shorthand** by the
   app frame and dozens of cards, so a `url()` there tiles onto every surface; and
   `--dsw-specific-sidebar-fill` is used as a *colour* inside `color-mix()` and
   gradients, so a `url()` there invalidates those declarations outright.

3. **The host half serves the artwork.** DSH publishes only
   `/plugins/<pkg>/client.js` and its chunks, so files inside a plugin package are
   not reachable from the page. The host half registers a prefix route on the
   webserver (`/theme-warm`) and streams from `media/`, with a traversal guard, an
   extension allowlist, `GET`/`HEAD` only, and `ETag` revalidation.

Component class names are CSS-module hashes that change between builds, so the
injected rules match the local-name **suffix** (`[class*="_sidebarCol"]`) rather
than a hash. The sidebar rule keeps the texture on the outermost `_root` only,
using `:not(<complex>)`; a plain descendant selector would hand the image to every
nested panel, and `background-size: cover` re-crops it to each smaller box — the
texture reappears, smaller, inside expandable sections.

## Customising

**Swap the artwork.** Replace the four files in `media/`. They are served as-is:

| File | Used for |
|---|---|
| `sidebar-light.webp` / `sidebar-dark.webp` | the sidebar column |
| `main-light.webp` / `main-dark.webp` | behind the main content area |

Keep the names, or update the `url(...)` paths in `lib/client.js`. Two images per
element rather than one, because a picture that sits behind dark surfaces is
usually wrong behind light ones.

**Change the palette.** Edit the `TOKENS` object in `lib/client.js`. Every token
needs **both** modes; a bare string throws a teaching error at runtime.

**Rename the package.** Change `name` in `package.json` **and** the `id` in the
`window.__ModuleLoader__.load({ id, ... })` call in `lib/client.js` — they must
match, because the host serves the bundle at `/plugins/<name>/client.js`.

## Known limits

- **macOS composites its sidebar through `color-mix`**, capping the sidebar token's
  alpha at 40% under a hardcoded gradient. The texture still shows; you just cannot
  make that sidebar fully opaque or fully transparent from the token layer.
- **A restart is required after installing.** No installed package in this DSH
  version watches `cordis.patch.yml`; the `patchReload` field in some profile
  manifests is not read.
- **`prefers-reduced-transparency: reduce`** drops both images and falls back to
  the flat canvas colour.
- The `media/` artwork in this repository is derived from the author's own
  source images; check the licence before reusing it elsewhere.

## Licence

MIT — see [LICENSE](LICENSE). The bundled artwork is covered separately; see the
note above.
