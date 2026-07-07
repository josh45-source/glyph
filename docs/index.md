# glyph

### The grammar of graphics, rebuilt for a web that moves.

**glyph** is a next-generation grammar of interactive graphics for R. It
treats interactivity, animation, and composable layouts as first-class
concepts — not afterthoughts bolted on via a chain of extension
packages.

``` r

install.packages("glyph")
```

  

## ggplot2 vs glyph

Same plot. One needs `plotly`, `ggrepel`, and a paragraph of
[`theme()`](https://ggplot2.tidyverse.org/reference/theme.html) calls to
get interactive, styled, and readable. The other needs a pipe.

[TABLE]

No [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html). No
[`factor()`](https://rdrr.io/r/base/factor.html) coercion. No `+`
juggling geometry, scales, and theme in one flat expression. And you get
zoom, brush, and hover for free.

  

## Why glyph?

**Interactivity is grammar, not glue.** Tooltips, zoom, brushing, and
linked views are declared right in the pipeline with
[`interact()`](https://josh45-source.github.io/glyph/reference/interact.md)
and
[`selection()`](https://josh45-source.github.io/glyph/reference/selection.md)
— not stapled on afterward with
[`plotly::ggplotly()`](https://rdrr.io/pkg/plotly/man/ggplotly.html).

**The spec is the plot.** Every glyph visualization is a pure,
inspectable data structure. Serialize it to JSON, export it to Vega-Lite
with
[`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md),
or
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
it to HTML, SVG, canvas, or WebGL — without touching the code that built
it.

**Composition is built in.** Multi-plot layouts, marginal distributions,
inset plots, and linked brushing across panels ship in
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md),
[`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.md),
and
[`inset()`](https://josh45-source.github.io/glyph/reference/inset.md) —
no `patchwork`, no `ggExtra`.

**Tokens, not 90 theme arguments.**
[`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)
takes a handful of design tokens — font, background, grid — and cascades
foreground, grid, and title colors automatically for contrast.

**Animation is a pipeline step.**
[`animate()`](https://josh45-source.github.io/glyph/reference/animate.md)
declares transitions, stagger, and easing right where the plot is built,
with no separate `gganimate` render pass.

  

## Installation

``` r

install.packages("glyph")

# Development version
# remotes::install_github("josh45-source/glyph")
```

  

## Getting Started

``` r

library(glyph)

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, size = hp) |>
  interact(tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons", zoom = TRUE) |>
  scale("y", zero = TRUE, label = "Miles per gallon") |>
  theme_tokens(preset = "dark") |>
  titles(title = "Motor Trend Cars", subtitle = "Weight vs fuel efficiency")
```

Read the [Getting Started
guide](https://josh45-source.github.io/glyph/articles/comparison.md) for
a full side-by-side tour of glyph’s grammar against ggplot2, or browse
the [function
reference](https://josh45-source.github.io/glyph/reference/index.md) to
see everything glyph can do.
