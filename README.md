# dsh-theme-sigrika

A warm cream-and-terracotta theme for the **DeepSeek Harness** Web GUI, built
around the character **Sigrika (西格莉卡)** from the game *Wuthering Waves* (鸣潮):
a sand-toned texture in the sidebar, a soft ornament behind the main content area,
and a terracotta accent, with a dark mode derived from the same hues.

The palette is not invented — it is sampled from the artwork. The sidebar's cream
`sand` and the terracotta accent come from the sidebar texture; the dusty-rose and
lavender-grey notes in the main ornament come from the character art.

|  |  |
|---|---|
| Surfaces | cream `#faf6ef`, raised `#fffcf7` |
| Accent | terracotta `#a85632` (dark `#e0915f`) |
| Sidebar | sand `#f2e6cd` + a 25%-opacity texture |
| Dark mode | warm brown `#1c1510` family, same hues re-derived |
| Character | Sigrika (西格莉卡) — *Wuthering Waves* (鸣潮), © Kuro Games |

> **The artwork is not original work — it was sourced from the internet and is
> included for personal, non-commercial use only.** The character and setting
> belong to Kuro Games; the MIT licence covers the code alone.
> See [Artwork notice](#artwork-notice).
>
> **图片来源于网络，并非原创，仅供个人学习交流使用。** 角色「西格莉卡 Sigrika」
> 出自游戏《鸣潮》，版权归库洛游戏所有；MIT 许可仅覆盖代码部分。
> 详见 [图片来源声明](#artwork-notice)。

<p align="center">
  <!-- Drop a screenshot here: <img src="preview.png" width="720" alt="dsh-theme-sigrika"> -->
</p>

## Requirements

- DeepSeek Harness `0.2.0-rc.2` or newer, on the **Web** surface (the `web` or
  `desktop` profile). It is a browser-side theme; it does nothing on the TUI.
- Node.js, for the install script's resolution pre-flight.

## Install

The theme lives in the `dsh-theme-sigrika/` folder of this repository. Both routes
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
pnpm add "github:<you>/<repo>#path:dsh-theme-sigrika"

# or from a local clone
pnpm add "C:\path\to\repo\dsh-theme-sigrika"
```

Then add `"dsh-theme-sigrika"` to `dsh.profile.bundles` in that profile's
`package.json`, or install it from the GUI's **Settings → Plugins** page.

Publishing to npm first makes this simpler for everyone else: `cd dsh-theme-sigrika`,
`npm publish`, and then it is a plain `pnpm add dsh-theme-sigrika` with no `#path:`.

### Route B — from a clone, no npm

```powershell
# Windows
cd dsh-theme-sigrika
pwsh -File install.ps1 -Profile desktop
```

```bash
# macOS / Linux
cd dsh-theme-sigrika
bash install.sh --profile desktop     # or: chmod +x install.sh && ./install.sh
```

Both take `--profile` (default `desktop`) and `--uninstall`, and `--dsh-home` /
`-DshHome` if your config root is not `$DSH_HOME` or `~/.dsh`.

The script copies the package to `$DSH_HOME/themes/dsh-theme-sigrika/`, writes a
marker-delimited row into `$DSH_HOME/profiles/<profile>/cordis.patch.yml` (it never
touches your own entries), and then reproduces the Loader's own resolution of that
row — rolling it back if it would not mount.

### Restart

`cordis.patch.yml` is read **at boot**. Restart dsh, then refresh the page.

Confirm the entry started:

```
cordis_inspect_query platform=host provider=Config method=listConfigs
```

Look for `include:theme-sigrika`, or just fetch an asset:

```powershell
Invoke-WebRequest "http://127.0.0.1:19387/theme-sigrika/sidebar-light.webp" -Method Head
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
├── dsh-theme-sigrika/          <- the installable package
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

The three originals are the source the `media/` images were derived from, and they
are internet-sourced too — see [Artwork notice](#artwork-notice). They are excluded
from the npm package by the `files` field, but a plain `git add -A` at the
repository root **will** commit all 14 MB of them. To keep them out, either delete
them or add a `.gitignore` at the repository root containing:

```gitignore
主体.png
侧栏.png
顶栏装饰.jpg
```

If you would rather not redistribute the artwork at all, delete the three originals
**and** replace the four files under `dsh-theme-sigrika/media/` with your own images.
Nothing in the code depends on the current pictures.

## How it works

Three things, and the split matters:

1. **Tokens carry the colour work.** 44 `--dsw-*` overrides, light and dark, applied
   through `ctx.theme.overrideTokens`. `bg-base` stays slightly translucent so the
   surfaces read as layered, but it is not load-bearing for the artwork — the
   ornament is painted above it, so `bg-base` being near-opaque is what lets cards
   cover the ornament instead of letting it muddy their text.

2. **One injected stylesheet paints the two images.** They cannot be tokens:
   `--dsw-alias-bg-base` is consumed through the `background` **shorthand** by the
   app frame and dozens of cards, so a `url()` there tiles onto every surface; and
   `--dsw-specific-sidebar-fill` is used as a *colour* inside `color-mix()` and
   gradients, so a `url()` there invalidates those declarations outright.

   Each image is painted on the surface that owns its region, **not on `body`**.
   On the Windows desktop the frame fills the whole window with an opaque
   `--dsw-specific-sidebar-fill`, so a `body` image never reaches the screen; and
   even elsewhere the frame, the centre column, and the conversation surface stack
   three translucent layers, which leaves about an eighth of the artwork. So the
   ornament goes on the conversation surface (the outermost `_root` inside the
   centre column) and the texture on the sidebar's own root.

3. **The host half serves the artwork.** DSH publishes only
   `/plugins/<pkg>/client.js` and its chunks, so files inside a plugin package are
   not reachable from the page. The host half registers a prefix route on the
   webserver (`/theme-sigrika`) and streams from `media/`, with a traversal guard, an
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

## Artwork notice

**The artwork under `media/` depicts the character Sigrika (西格莉卡) from the game
*Wuthering Waves* (鸣潮).** The character and its setting are the property of
**Kuro Games (库洛游戏)**. This project is not affiliated with or endorsed by Kuro
Games.

The image files themselves are **not original work** either: they were sourced from
the internet, and their individual authorship is unknown. They are included for
personal, non-commercial use and study only, and this project claims no rights over
the character, the setting, or the images. If you are a rights holder and want the
artwork removed, open an issue and it will be taken down.

> **图片来源声明**
>
> `media/` 目录下的图片描绘的是游戏《鸣潮》（Wuthering Waves）中的角色「西格莉卡
> Sigrika」，该角色及相关设定版权归**库洛游戏（Kuro Games）**所有，本项目与库洛游戏
> 无隶属或背书关系。
>
> 图片文件本身亦**并非原创**，来源于网络，作者不详。此处仅用于个人学习、研究与交流，
> 不作任何商业用途。本项目不对角色、设定及图片主张任何权利。
> 如有侵权，请提交 issue 告知，将立即删除。

The MIT licence covers **only the code** — `lib/`, `cordis.patch.yml`,
`package.json`, and the install scripts. If you intend to redistribute this theme,
replace the artwork with your own images or with properly licensed ones; nothing in
the code depends on the current pictures.

> MIT 许可**仅覆盖代码部分**。如需再分发本主题，请自行替换为原创或已获授权的图片。

## Licence

MIT for the code — see [LICENSE](LICENSE). The artwork is excluded from that grant;
see the notice above.

