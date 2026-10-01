/**
 * DSH Sigrika theme - browser half.
 *
 * Sigrika (西格莉卡) from Wuthering Waves (鸣潮), a Kuro Games property. The
 * artwork is not original and is used for personal, non-commercial purposes; see
 * LICENSE. The code below is MIT.
 *
 * Palette derived from that artwork: a cream-and-sand sidebar texture, a
 * dusty-rose main ornament, and a terracotta accent. Everything below is either
 * a token (color) or one injected stylesheet (the two images).
 *
 * WHY THE IMAGES ARE NOT TOKENS
 *   `--dsw-alias-bg-base` is consumed through the `background` SHORTHAND by the
 *   app frame, the conversation root, and dozens of cards, so a `url(...)` there
 *   tiles onto every surface. And `--dsw-specific-sidebar-fill` cannot carry one
 *   either: it is used as a *color* inside `color-mix()` and
 *   `linear-gradient()` in several packages, including the dark-mode sidebar
 *   rule, where a url() would invalidate the declaration and leave the sidebar
 *   with no background at all. Both tokens therefore stay colors.
 *
 * WHERE THE IMAGES GO
 *   The main ornament is painted on the conversation surface - the outermost
 *   `_root` inside the centre column - because everything between `body` and the
 *   eye paints over it: on the Windows desktop the frame fills the whole window
 *   with an opaque `--dsw-specific-sidebar-fill`. See the rule's own comment.
 *
 *   The sidebar texture is painted on the sidebar's own root element, because
 *   that element repaints `--dsw-specific-sidebar-fill` over the column and would
 *   otherwise hide anything applied to the column itself.
 *
 * SELECTOR TECHNIQUE
 *   Component class names are CSS-module hashes: `pI_x6G_sidebarCol` in one build,
 *   `BynINW_sidebarCol` in another. The hash changes, the local name does not, so
 *   the rules below match the local-name SUFFIX (`[class*="_sidebarCol"]`) rather
 *   than hardcoding a hash that a DSH update would silently invalidate.
 */
window.__ModuleLoader__.load({
  id: 'dsh-theme-sigrika',
  factory: (require) => {
    const module = { exports: {} }
    const exports = module.exports
    Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' })

    /** Public route prefix registered by the host half. Keep in sync with lib/index.js. */
    const ROUTE = '/theme-sigrika'

    /** Layer identity for the token override. */
    const SOURCE = 'dsh-theme-sigrika'

    /**
     * Warm palette. Hues are taken from the source artwork; the dark mode is the
     * same hue family re-derived for dark surfaces rather than an inversion.
     *
     * `bg-base` stays slightly translucent so the surfaces read as layered rather
     * than flat, but it is NOT load-bearing for the artwork any more: the ornament
     * is painted on the conversation surface itself, above it. Keeping it near
     * opaque is what lets cards that use it cover the ornament instead of letting
     * it muddy their text. `bg-layer-*` are near-opaque for the same reason.
     */
    const TOKENS = {
      // ── canvas and surfaces ───────────────────────────────────────────────
      '--dsw-alias-bg-base': { light: 'rgba(250, 246, 239, 0.82)', dark: 'rgba(28, 21, 16, 0.84)' },
      '--dsw-alias-bg-layer-1': { light: 'rgba(255, 252, 247, 0.88)', dark: 'rgba(40, 31, 24, 0.88)' },
      '--dsw-alias-bg-layer-2': { light: 'rgba(255, 253, 249, 0.93)', dark: 'rgba(48, 37, 29, 0.93)' },
      '--dsw-alias-bg-layer-3': { light: 'rgba(255, 254, 252, 0.96)', dark: 'rgba(56, 44, 34, 0.96)' },
      '--dsw-alias-bg-overlay': { light: 'rgba(255, 253, 250, 0.97)', dark: 'rgba(50, 39, 31, 0.97)' },
      // Must stay a COLOR: this token is fed to color-mix() and gradients.
      '--dsw-specific-sidebar-fill': { light: '#f2e6cd', dark: '#241b15' },

      // ── borders: warm brown alpha, never opaque ───────────────────────────
      '--dsw-alias-border-l1': { light: '#6b4a3220', dark: '#ffffff1a' },
      '--dsw-alias-border-l2': { light: '#6b4a322e', dark: '#ffffff26' },
      '--dsw-alias-border-l3': { light: '#6b4a323d', dark: '#ffffff33' },
      '--dsw-alias-border-l4': { light: '#6b4a324d', dark: '#ffffff42' },

      // ── accent: terracotta from the artwork ───────────────────────────────
      '--dsw-alias-brand-primary': { light: '#a85632', dark: '#e0915f' },
      '--dsw-alias-brand-text': { light: '#6b3a22', dark: '#f0cdb2' },
      '--dsw-alias-link': { light: '#a85632', dark: '#e5a273' },

      // ── text: warm near-blacks and browns, kept opaque ────────────────────
      '--dsw-alias-label-primary': { light: '#38291f', dark: '#f4ece2' },
      '--dsw-alias-label-secondary': { light: '#6d5847', dark: '#c6b3a0' },
      '--dsw-alias-label-tertiary': { light: '#8c7663', dark: '#a08b78' },
      '--dsw-alias-label-dimmed': { light: '#b3a08d', dark: '#77675a' },
      '--dsw-alias-label-caption': { light: '#97826f', dark: '#8d7a68' },

      // ── semantic state: warm-shifted, still conventional ──────────────────
      '--dsw-alias-state-business-primary': { light: '#a85632', dark: '#e0915f' },
      '--dsw-alias-state-error-primary': { light: '#b3402f', dark: '#e87a68' },
      '--dsw-alias-state-idle-primary': { light: '#b8a794', dark: '#77675a' },
      '--dsw-alias-state-success-primary': { light: '#5f7a45', dark: '#9cb87a' },
      '--dsw-alias-state-warn-primary': { light: '#c2820f', dark: '#e0ab52' },

      // ── interaction ───────────────────────────────────────────────────────
      '--dsw-alias-interactive-bg-hover': { light: '#6b4a3214', dark: '#ffffff14' },
      '--dsw-alias-interactive-bg-active': { light: '#6b4a3224', dark: '#ffffff24' },
      '--dsw-alias-interactive-bg-hover-solid': { light: '#f0e6d6', dark: '#3a2d24' },

      // ── code and markdown: near-opaque, this is where transparency hurts ──
      '--dsw-alias-markdown-code-block': { light: 'rgba(250, 244, 234, 0.86)', dark: 'rgba(26, 20, 16, 0.86)' },
      '--dsw-alias-markdown-code-block-banner': { light: 'rgba(244, 236, 223, 0.92)', dark: 'rgba(38, 29, 23, 0.92)' },
      '--dsw-alias-markdown-inline-code': { light: 'rgba(246, 239, 228, 0.92)', dark: 'rgba(56, 44, 34, 0.92)' },

      // ── scrollbars ────────────────────────────────────────────────────────
      '--dsw-alias-scrollbar-bg-l1': { light: '#cdbda6', dark: '#4a3b2f' },
      '--dsw-alias-scrollbar-hover-l1': { light: '#b8a48a', dark: '#5f4c3d' },
      '--dsw-alias-scrollbar-bg-l2': { light: '#d6c8b2', dark: '#554435' },
      '--dsw-alias-scrollbar-hover-l2': { light: '#c0ad94', dark: '#6b5747' },

      // ── overlays and buttons: near-opaque, they sit above content ─────────
      '--dsw-alias-toast-bg': { light: '#4a382c', dark: '#3a2d24' },
      '--dsw-alias-toast-label': { light: '#fdf9f3', dark: '#f4ece2' },
      '--dsw-alias-tooltip-bg': { light: '#4a382c', dark: '#43342a' },
      '--dsw-alias-menu-icon': { light: '#6d5847', dark: '#c6b3a0' },
      '--dsw-alias-menu-group-header-fill': { light: 'rgba(253, 249, 243, 0.94)', dark: 'rgba(42, 32, 25, 0.94)' },
      '--dsw-alias-switch-thumb': { light: '#fffdf9', dark: '#8a7563' },
      '--dsw-alias-button-elevated-fill': { light: 'rgba(255, 252, 247, 0.90)', dark: 'rgba(48, 37, 29, 0.92)' },
      '--dsw-alias-button-floating-fill': { light: 'rgba(255, 253, 249, 0.94)', dark: 'rgba(56, 44, 34, 0.94)' },
      '--dsw-alias-button-floating-hover': { light: 'rgba(246, 238, 226, 0.96)', dark: 'rgba(68, 54, 42, 0.96)' },
      '--dsw-alias-button-ghost-active-fill': { light: 'rgba(238, 228, 213, 0.92)', dark: 'rgba(62, 49, 38, 0.92)' },
      '--dsw-alias-button-ghost-active-hover': { light: 'rgba(230, 218, 200, 0.95)', dark: 'rgba(74, 59, 46, 0.95)' },
    }

    /**
     * The two artwork layers.
     *
     * The sidebar rules carry the specificity needed to beat the package's own
     * `background: var(--dsw-specific-sidebar-fill)` and the dark-mode
     * `color-mix()` rule, and the `:not()` guard is what keeps the texture to a
     * single element. See the comment inside for why that matters.
     */
    const CSS = `
/* ---- sidebar texture -------------------------------------------------- */
/* The column paints the texture: one element, exactly the sidebar's size. */
[class*="_sidebarCol"] {
  background-color: #f2e6cd;
  background-image: url("${ROUTE}/sidebar-light.webp");
  background-position: center top;
  background-size: cover;
  background-repeat: no-repeat;
}

/* The sidebar's own root repaints --dsw-specific-sidebar-fill over the column,
   so it needs the texture too - but ONLY the outermost _root.

   A _root nested inside another one is a panel or an expandable section. A plain
   descendant selector hands each of those the image as well, and because
   background-size: cover resolves against the element's OWN box, every nested
   one re-crops the picture at a different zoom: the texture reappears, smaller,
   inside the sidebar. :not(<complex>) keeps the outermost element and the rule
   below strips the image from everything deeper. */
[class*="_sidebarCol"] [class*="_root"]:not([class*="_root"] [class*="_root"]) {
  background-color: #f2e6cd;
  background-image: url("${ROUTE}/sidebar-light.webp");
  background-position: center top;
  background-size: cover;
  background-repeat: no-repeat;
}

[class*="_sidebarCol"] [class*="_root"] [class*="_root"] {
  background-image: none;
}

body[data-ds-dark-theme] [class*="_sidebarCol"] {
  background-color: #241b15;
  background-image: url("${ROUTE}/sidebar-dark.webp");
}

body[data-ds-dark-theme] [class*="_sidebarCol"] [class*="_root"]:not([class*="_root"] [class*="_root"]) {
  background-color: #241b15;
  background-image: url("${ROUTE}/sidebar-dark.webp");
  background-position: center top;
  background-size: cover;
  background-repeat: no-repeat;
}

/* ---- main ornament ---------------------------------------------------- */
/* Painted on the conversation surface - the OUTERMOST _root inside the center
   column, which is ConversationRoot and owns the main area's own background -
   and NOT on body.

   A body background has to survive everything painted between it and the eye.
   On the Windows desktop that is fatal: the frame's caption rule is

     [data-windows-titlebar] .frame { background: var(--dsw-specific-sidebar-fill) }

   an OPAQUE fill across the whole window, and --dsw-specific-sidebar-fill has to
   stay a colour because other packages feed it to color-mix() and gradients. So
   a body image never reached the screen at all. Even without that rule the stack
   is the frame, the centre column, and this surface - three translucent layers,
   which leaves roughly an eighth of the artwork.

   Painting it here puts the ornament on the surface that already paints the main
   area, so it sits above all of that and reads at full strength, with panels and
   cards covering it where they should.

   The :not(<complex>) guard keeps it to that single outermost element; a plain
   descendant selector would hand the image to every nested _root (the hero
   shell, the chat view, ...), and background-size resolves per element, so each
   would re-crop the artwork at a different zoom. */
[class*="_centerCol"] [class*="_root"]:not([class*="_root"] [class*="_root"]) {
  background-image: url("${ROUTE}/main-light.webp");
  background-position: 68% center;
  background-size: auto 86%;
  background-repeat: no-repeat;
}

body[data-ds-dark-theme] [class*="_centerCol"] [class*="_root"]:not([class*="_root"] [class*="_root"]) {
  background-image: url("${ROUTE}/main-dark.webp");
}

/* An explicit request for less transparency wins: drop the ornament. */
@media (prefers-reduced-transparency: reduce) {
  [class*="_centerCol"] [class*="_root"]:not([class*="_root"] [class*="_root"]) {
    background-image: none;
  }
}
`

    /** Plugin-owned stylesheet identity; also the cleanup handle. */
    const CSS_TAG_ID = `${SOURCE}/theme.css`

    /**
     * Inject the stylesheet once, and remove it only if this call created it.
     * `data-plugin` plus `data-plugin-css` is the convention the module system's
     * owned-style cleanup and inspection both key on.
     */
    function installStyles() {
      let tag = document.querySelector(`style[data-plugin-css="${CSS_TAG_ID}"]`)
      const created = tag === null
      if (created) {
        tag = document.createElement('style')
        tag.dataset.plugin = SOURCE
        tag.dataset.pluginCss = CSS_TAG_ID
        tag.textContent = CSS
        document.head.appendChild(tag)
      }
      return () => {
        if (created) tag.remove()
      }
    }

    /**
     * Client plugin body. `inject: ['theme']` guarantees the theme registry
     * exists; `ctx.effect` ties both the token layer and the stylesheet to this
     * plugin's fiber, so disabling the plugin restores the built-in look exactly.
     */
    function apply(ctx) {
      ctx.effect(() => ctx.theme.overrideTokens(SOURCE, TOKENS))
      ctx.effect(installStyles)
    }

    const inject = ['theme']

    exports.apply = apply
    exports.inject = inject
    return module.exports
  },
})
