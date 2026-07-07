# glyph

### The grammar of graphics, rebuilt for a web that moves.

**glyph** is a next-generation grammar of interactive graphics for R. It
treats interactivity, animation, and composable layouts as first-class
concepts — not afterthoughts bolted on via a chain of extension packages.

```r
install.packages("glyph")
```

<br>

## ggplot2 vs glyph

Same plot. One needs `plotly`, `ggrepel`, and a paragraph of `theme()` calls
to get interactive, styled, and readable. The other needs a pipe.

<table width="100%">
<tr>
<th width="50%">ggplot2 (+ plotly, for interactivity)</th>
<th width="50%">glyph</th>
</tr>
<tr>
<td>

```r
library(ggplot2)
library(plotly)

p <- ggplot(mtcars, aes(
      x = wt, y = mpg,
      color = factor(cyl),
      text = paste0(
        cyl, " cyl, ", mpg,
        " mpg at ", wt, " tons")
    )) +
  geom_point(size = 3) +
  scale_color_brewer(palette = "Set2") +
  labs(title = "Motor Trend Cars",
       subtitle = "Weight vs fuel efficiency") +
  theme(
    text = element_text(
      family = "Inter", size = 12),
    plot.background = element_rect(
      fill = "#1a1a2e"),
    panel.background = element_rect(
      fill = "#1a1a2e"),
    axis.text = element_text(
      color = "#e0e0e0"),
    panel.grid = element_line(
      color = "#2a2a4a")
  )

ggplotly(p, tooltip = "text")
# loses some theming; no zoom/brush
```

</td>
<td>

```r
library(glyph)

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  scale_color("Set2") |>
  interact(
    tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons",
    zoom = TRUE,
    hover = "enlarge"
  ) |>
  theme_tokens(bg = "#1a1a2e", font = "Inter") |>
  titles(
    title = "Motor Trend Cars",
    subtitle = "Weight vs fuel efficiency"
  )




# fg, grid, and title color are
# auto-derived for contrast


# tooltip + zoom + brush, built in
```

</td>
</tr>
</table>

No `aes()`. No `factor()` coercion. No `+` juggling geometry, scales, and
theme in one flat expression. And you get zoom, brush, and hover for free.

<br>

## Why glyph?

**Interactivity is grammar, not glue.**
Tooltips, zoom, brushing, and linked views are declared right in the
pipeline with [`interact()`](reference/interact.html) and
[`selection()`](reference/selection.html) — not stapled on afterward with
`plotly::ggplotly()`.

**The spec is the plot.**
Every glyph visualization is a pure, inspectable data structure. Serialize
it to JSON, export it to Vega-Lite with
[`to_vegalite()`](reference/to_vegalite.html), or
[`compile()`](reference/compile.html) it to HTML, SVG, canvas, or WebGL —
without touching the code that built it.

**Composition is built in.**
Multi-plot layouts, marginal distributions, inset plots, and linked
brushing across panels ship in
[`compose()`](reference/compose.html), [`marginals()`](reference/marginals.html),
and [`inset()`](reference/inset.html) — no `patchwork`, no `ggExtra`.

**Tokens, not 90 theme arguments.**
[`theme_tokens()`](reference/theme_tokens.html) takes a handful of design
tokens — font, background, grid — and cascades foreground, grid, and title
colors automatically for contrast.

**Animation is a pipeline step.**
[`animate()`](reference/animate.html) declares transitions, stagger, and
easing right where the plot is built, with no separate `gganimate` render
pass.

<br>

## Installation

```r
install.packages("glyph")

# Development version
# remotes::install_github("josh45-source/glyph")
```

<br>

## Getting Started

```r
library(glyph)

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, size = hp) |>
  interact(tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons", zoom = TRUE) |>
  scale("y", zero = TRUE, label = "Miles per gallon") |>
  theme_tokens(preset = "dark") |>
  titles(title = "Motor Trend Cars", subtitle = "Weight vs fuel efficiency")
```

Read the [Getting Started guide](articles/getting-started.html) for live,
interactive examples, the [side-by-side comparison](articles/comparison.html)
against ggplot2, or browse the [function reference](reference/index.html) to
see everything glyph can do.
