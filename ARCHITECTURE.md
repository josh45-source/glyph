# glyph — Architecture & Design Decisions

## Why This Package Exists

ggplot2 is the most successful data visualization library ever built.
But it was designed in 2005–2007 for a world of static print graphics.
The web, large data, and interactive dashboards have changed what
“plotting” means. glyph doesn’t try to replace ggplot2 — it asks: *what
would a grammar of graphics look like if designed for 2026?*

## Core Architecture

### 1. Spec-First Design

Every glyph visualization is a **specification** — a pure R list that
fully describes the plot without executing any rendering. This is the
single most important architectural decision and the root cause of most
advantages:

    glyph_spec = {
      data:      data.frame or reference
      mappings:  list of quosures (lazy, not evaluated)
      marks:     list of mark descriptors
      scales:    list of scale configs
      interact:  list of interaction configs
      animate:   animation config
      theme:     token map
      layout:    composition config
    }

**Why specs matter:** - *Serializable*:
`jsonlite::toJSON(compile(spec)$spec)` gives you a JSON blob you can
send to a server, save to a file, or embed in a document. -
*Inspectable*: You can print, diff, and test specs without rendering. -
*Multi-backend*: One spec compiles to D3, Canvas, WebGL, SVG, or PDF. -
*Interoperable*: The spec maps closely to Vega-Lite, enabling
R↔︎JS↔︎Python workflows.

ggplot2’s `ggplot` objects contain grobs (grid graphics objects) that
are tightly coupled to R’s graphics device system. You can’t serialize a
ggplot to JSON, render it in a browser without conversion, or inspect it
cleanly.

### 2. Quosure-Based Mappings (No `aes()`)

ggplot2 requires `aes()` to create a mapping object. This is a
historical artifact from when NSE in R was less mature. With rlang’s
quosure system, we can capture bare names directly:

``` r
# ggplot2
ggplot(data, aes(x = wt, y = mpg, color = factor(cyl)))

# glyph
glyph(data, x = wt, y = mpg)  # global mappings
  |> mark_point(color = cyl)    # per-mark mappings
```

Mappings are stored as **quosures** (expressions + environments) and
only evaluated during
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md).
This means the spec is portable and doesn’t carry data references
prematurely.

### 3. Mark Model (vs. Geom + Stat)

ggplot2 separates **geoms** (visual forms) from **stats** (data
transforms). `geom_smooth()` is really `stat_smooth()` + `geom_line()`.
This is elegant in theory but confusing in practice (“should I use
`geom_bar()` or `stat_count()`?”).

glyph uses a simpler model: **marks** are visual encodings. Statistical
transforms are explicit, composable steps applied to the data before
marking:

``` r

glyph(data, x = wt, y = mpg) |>
  transform_smooth(method = "loess", se = TRUE) |>  # planned
  mark_ribbon(y_min = .lower, y_max = .upper) |>
  mark_line(y = .fitted)
```

This makes the data flow explicit: raw data → transform → mark. No
hidden stat layers.

### 4. Interaction as Grammar

The key insight from Vega-Lite: **most interactions are selections**. A
tooltip is a single-point selection with a display action. Brushing is a
multi-point selection. Zooming is a continuous interval selection on the
position channels.

glyph encodes interactions as part of the spec, not as runtime behaviors
bolted on after rendering:

``` r

interact(
  tooltip = TRUE,     # point selection → show values
  brush = TRUE,       # interval selection → highlight
  zoom = TRUE,        # interval selection → rescale
  crossfilter = TRUE  # propagate selection to linked views
)
```

This means: - Interactions survive export (the HTML output is
self-contained) - The spec can describe interactions without knowing the
backend - Server-side tools (Shiny) can intercept selection events

### 5. Token-Based Theming

ggplot2’s `theme()` has 90+ arguments because it treats every visual
property independently. glyph uses **design tokens** — a small set of
semantic values that cascade through the visualization:

    font       →  all text elements
    font_size  →  base size; title = font_size × title_size
    bg         →  plot background; auto-derives fg for contrast
    fg         →  text, axis lines, ticks
    accent     →  single-series mark color
    grid       →  grid visibility and color (derived from bg)
    padding    →  all margins uniformly

Setting `bg = "#1a1a2e"` (dark) automatically gives you: - Light text
(`fg = "#e0e0e0"`) - Subtle grid lines (`grid_color = "#2a2a4a"`) -
Appropriate tooltip styling

This is how CSS custom properties work, and it’s far more maintainable
than flat theme arguments.

### 6. Built-In Composition

ggplot2 delegates multi-plot layouts to patchwork, cowplot, or
gridExtra. glyph includes
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
because layout is part of the visualization design, not an afterthought:

``` r

compose(p1, p2, p3,
        type = "wrap",
        linked_selections = TRUE,
        shared_scales = "x")
```

The layout is part of the spec. This means: - Linked selections can
propagate across panels - Shared scales are computed globally, not
per-panel - The entire composition exports as one self-contained HTML

### 7. Multi-Backend Compilation

The
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
step translates the abstract spec into a backend-specific render tree:

                        ┌──► D3.js + SVG (< 10K points)
                        │
    glyph_spec ──►  compile() ──► Canvas 2D (10K–100K points)
                        │
                        ├──► WebGL / regl (100K+ points)
                        │
                        └──► Static SVG / PDF (export)

The compiler auto-selects based on data size but can be overridden. Each
backend implements the same mark/scale/interaction semantics; only the
rendering primitives differ.

## What’s Hard (Honest Assessment)

### Statistical Transforms

ggplot2’s stat system is deeply integrated and covers dozens of methods.
Replicating this is a multi-year effort. glyph’s strategy: start with
explicit `transform_*()` functions for the most common cases (smooth,
bin, density, aggregate) and grow from there.

### Extension Ecosystem

ggplot2 has 200+ extension packages. glyph can’t compete on breadth.
Instead, the Vega-Lite export path provides an escape hatch: anything
glyph can’t do, Vega-Lite/D3 probably can. The spec-first design also
makes extension easier — add a new mark type without touching the
renderer.

### Print Quality

R’s PDF/SVG graphics devices have been tuned for decades. glyph’s static
export (via headless Chrome rendering of the HTML output) will never
match R’s native device quality for print. For publication-quality
static plots, ggplot2 remains the right tool.

### Community Adoption

The cold truth: R visualization is a solved problem for most users.
Convincing people to learn a new grammar requires either a dramatically
better experience (possible) or institutional adoption (hard). glyph’s
best path is as a complement — used when ggplot2 falls short — not a
replacement.

## Technology Choices

| Layer | Choice | Rationale |
|----|----|----|
| R API | rlang + base pipe | Modern NSE; works with existing tidyverse muscle memory |
| Serialization | jsonlite | Mature, fast, round-trips R lists to JSON cleanly |
| Interactive rendering | htmlwidgets + D3.js v7 | De facto standard for R→browser graphics |
| Large-data rendering | regl (planned) | WebGL without the boilerplate; proven by deck.gl |
| Static export | headless Chrome (planned) | Pixel-perfect match with interactive version |
| Interop | Vega-Lite JSON | Bridges R, Python (Altair), and JavaScript ecosystems |
