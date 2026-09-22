# glyph <img src="man/figures/logo.png" align="right" height="139" />

> A next-generation grammar of interactive graphics for R.

**glyph** is a visualization package that treats interactivity, animation,
and composable layouts as first-class grammar concepts — not afterthoughts
bolted on via extension packages.

## Design Philosophy

glyph is built on three convictions:

1. **The spec is the plot.** A glyph visualization is a pure data structure
   (a nested list) that fully describes what to draw, how to interact, and
   how to animate. This spec can be inspected, serialized to JSON, exported
   to Vega-Lite, and compiled to different rendering backends.

2. **Interactivity is grammar, not glue.** Tooltips, brushing, zoom, linked
   views, and animated transitions are declared in the same pipeline as
   marks and scales. They are part of the specification, not a post-hoc
   conversion.

3. **Composition is built in.** Multi-plot layouts, marginal distributions,
   inset plots, and cross-filtered dashboards don't need separate packages.

## Installation

```r
# Install from GitHub (once published)
# remotes::install_github("yourname/glyph")

# For now, install from local source:
devtools::install("path/to/glyph")
```

## Quick Start

```r
library(glyph)

# Basic scatterplot — no aes() needed
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, size = hp)
```

```r
# Interactive with tooltips and zoom
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(
    tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons",
    zoom = TRUE,
    hover = "enlarge"
  ) |>
  theme_tokens(preset = "dark") |>
  titles(title = "Motor Trend Cars", subtitle = "Weight vs fuel efficiency")
```

```r
# Animated bar chart
glyph(mtcars, x = cyl, y = mpg) |>
  mark_bar() |>
  animate(transition = "slide", stagger = 80, easing = "bounce") |>
  scale("y", zero = TRUE, label = "Miles per gallon")
```

```r
# Composed layout with linked brushing
p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point(color = cyl)
p2 <- glyph(mtcars, x = hp, y = mpg) |> mark_point(color = cyl)
p3 <- glyph(mtcars, x = wt, y = hp) |> mark_line()

compose(p1, p2, p3,
        type = "wrap",
        linked_selections = TRUE,
        gap = 15)
```

```r
# Marginal distributions (built-in, no ggExtra)
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  marginals(x = "histogram", y = "density")
```

## How glyph Compares to ggplot2

### API Ergonomics

| Feature | ggplot2 | glyph |
|---|---|---|
| Aesthetic mapping | `aes(x = wt, y = mpg)` | `x = wt, y = mpg` (bare names) |
| Color palette | `scale_color_brewer(palette="Set2")` | `scale_color("Set2")` |
| Log scale | `scale_y_log10()` | `scale_log("y")` |
| Plot title | `labs(title = "...", subtitle = "...")` | `titles(title = "...", subtitle = "...")` |
| Theme | `theme(text = element_text(family = "..."), ...)` (90+ args) | `theme_tokens(font = "...", bg = "...", grid = "y")` (token cascade) |
| Faceting | `facet_wrap(~cyl)` or `facet_grid(rows = vars(cyl))` | `facet(cols = cyl, free_scales = "both")` |

### Capability Comparison

| Capability | ggplot2 | glyph |
|---|---|---|
| Static 2D plots | ✅ Excellent | ✅ Excellent |
| Tooltips | ❌ Requires `plotly::ggplotly()` | ✅ Built-in |
| Zoom & pan | ❌ Requires `plotly` | ✅ Built-in |
| Brush selection | ❌ Requires `plotly` or Shiny | ✅ Built-in |
| Linked views | ❌ Requires Shiny + custom code | ✅ `compose(linked_selections = TRUE)` |
| Animation | ❌ Requires `gganimate` | ✅ `animate()` in pipeline |
| Multi-plot layout | ❌ Requires `patchwork`/`cowplot` | ✅ `compose()` built-in |
| Marginal plots | ❌ Requires `ggExtra` | ✅ `marginals()` built-in |
| Inset plots | ❌ Manual grid/viewport hacking | ✅ `inset()` built-in |
| Smart label repulsion | ❌ Requires `ggrepel` | ✅ `mark_text(smart_repel = TRUE)` |
| Vega-Lite export | ❌ Not possible | ✅ `to_vegalite()` |
| Large data (>100K pts) | ⚠️ Slow (grob tree) | ⚠️ Not yet optimized — Canvas/WebGL backends are planned |
| Theme presets | ⚠️ `theme_minimal()`, etc. | ✅ `theme_tokens(preset = "dark")` with auto-contrast |
| Per-mark data | ⚠️ Awkward `data` param override | ✅ Each mark can have own data |
| Cross-filter dashboard | ❌ Requires Shiny | ✅ Declarative `crossfilter = TRUE` |

### What ggplot2 Still Does Better

- **Ecosystem breadth**: 100+ extension packages for niche chart types
- **Community knowledge**: millions of StackOverflow answers, tutorials, books
- **Statistical transforms**: `stat_smooth()`, `stat_density2d()`, etc. are deeply integrated
- **Print-quality output**: decades of R graphics device tuning
- **Stability**: battle-tested on millions of real-world plots

## Architecture

```
User API              Spec (pure data)          Backends
─────────           ──────────────────        ──────────
glyph() ──┐
mark_*()  ├──►  glyph_spec (R list)  ──►  compile() ──►  html (D3/htmlwidgets)
scale()   │     serializable to JSON        │              svg (planned)
animate() │     inspectable                 │              canvas (planned)
compose() ┘     exportable                  │              webgl (planned)
                                            │              pdf (planned)
                                            └──►  to_vegalite() (interop)
```

The key insight: **separation of specification from rendering**. The
`glyph_spec` is a plain data structure independent of how it's drawn, so
new backends (static SVG export, Canvas, WebGL) can be added later without
changing the user-facing code. Today, `compile()` only implements one
backend: an interactive HTML widget via D3.js/SVG.

## Rendering Backends

| Backend | Status | Use Case | Interactive |
|---|---|---|---|
| `html` (default) | ✅ Implemented | Exploration, dashboards | ✅ Full |
| `svg` | 🔜 Planned | Publication, export | ❌ Static |
| `canvas` | 🔜 Planned | Medium-large data | ✅ Tooltips + zoom |
| `webgl` | 🔜 Planned | Very large data | ⚠️ Basic |
| `pdf` | 🔜 Planned | Print | ❌ Static |

`compile(engine = ...)` currently only accepts `"auto"` (equivalent to
`"html"`) or `"html"` explicitly; other engines aren't implemented yet and
are rejected rather than silently ignored.

## Token-Based Theming

Instead of ggplot2's 90+ `theme()` arguments, glyph uses design tokens
that cascade:

```r
# ggplot2: verbose, flat
ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +
  theme(
    text = element_text(family = "Inter", size = 12),
    plot.background = element_rect(fill = "#1a1a2e"),
    panel.background = element_rect(fill = "#1a1a2e"),
    axis.text = element_text(color = "#e0e0e0"),
    axis.title = element_text(color = "#e0e0e0"),
    panel.grid = element_line(color = "#2a2a4a"),
    plot.title = element_text(color = "#e0e0e0", size = 16)
  )

# glyph: tokens cascade automatically
glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  theme_tokens(font = "Inter", bg = "#1a1a2e")
  # fg, grid_color, title color all auto-derived for contrast
```

## Roadmap

### v0.1 (This Prototype)
- [x] Core spec builder + pipe API
- [x] Point, line, bar, area, text, rule marks
- [x] D3.js htmlwidget renderer
- [x] Tooltips, zoom, brush, hover effects
- [x] Theme token system with presets
- [x] Layout composition (compose, marginals, inset)
- [x] Entrance animations
- [x] Vega-Lite JSON export

### v0.2 (Next)
- [ ] Statistical transforms (smooth, density, bin, aggregate)
- [ ] Legend rendering and interactive legends
- [ ] Canvas rendering backend for 10K–100K points
- [ ] Full faceting implementation in the JS renderer
- [ ] Keyboard accessibility

### v0.3
- [ ] WebGL backend via regl/deck.gl
- [ ] Keyframe animation (morph between data states)
- [ ] Cross-filter linked selections across composed plots
- [ ] Network/graph mark type
- [ ] Treemap and sunburst marks

### v1.0
- [ ] Full Vega-Lite round-trip (import + export)
- [ ] Shiny integration (server-side selections as reactive values)
- [ ] Static PDF/SVG export via headless Chrome
- [ ] Arrow/DuckDB data connectors for out-of-memory datasets
- [ ] Comprehensive test suite + pkgdown documentation site

## Contributing

This is a prototype exploring whether a better visualization grammar for R
is feasible. Contributions, feedback, and design discussions are welcome.

## Acknowledgements

glyph's design draws directly on the ideas and prior art of others:

- **Leland Wilkinson's *The Grammar of Graphics*** — the layered
  data/mark/scale vocabulary that glyph's spec is structured around.
- **ggplot2** — the aesthetic-mapping model (`aes()`, here bare names
  instead) and the pipeline style of building a plot up in layers.
- **Vega-Lite** — the idea of a declarative, serializable JSON spec that
  compiles to a render tree, and treating interactions as selections.
- **ggvis** — an earlier reactive, D3-backed grammar of graphics for R;
  glyph's D3-via-htmlwidgets rendering follows the same path.
- **ggiraph** — ggplot2 output with D3-powered tooltips, hover, and
  selection; a direct influence on glyph's own tooltip/hover/brush model.
- **plotly** — the baseline for what an "interactive R plot" should offer
  (zoom, pan, tooltips), which glyph aims to provide natively.
- **patchwork** — the model for glyph's `compose()` multi-plot layout API.
- **gganimate** — the `transition_states()`-style keyframe grammar behind
  `animate(by = ..., transition = "morph")`.
- **ggExtra** — the marginal histogram/density/boxplot pattern behind
  `marginals()`.
- **ggrepel** — the inspiration for `mark_text(smart_repel = TRUE)`'s
  label decluttering (glyph uses a simpler iterative pairwise-nudge
  approach rather than ggrepel's force simulation — see `?mark_text`).

This package also bundles [D3.js](https://d3js.org) (Copyright Mike
Bostock, ISC License); see `inst/COPYRIGHTS` for the full notice.

## License

MIT
