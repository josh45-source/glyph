# glyph

<!-- TODO(joash): write the intro in your own words -->

```r
install.packages("glyph")

# Development version
# remotes::install_github("josh45-source/glyph")
```

## A first plot

```r
library(glyph)

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, size = hp) |>
  interact(tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons", zoom = TRUE) |>
  scale("y", zero = TRUE, label = "Miles per gallon") |>
  theme_tokens(preset = "dark") |>
  titles(title = "Motor Trend Cars", subtitle = "Weight vs fuel efficiency")
```

Each step adds to a specification, a plain R list that describes the whole
plot. When the plot is printed, glyph compiles the spec to JSON and draws it
in the browser with D3.js. That happens at the console and in R Markdown,
Quarto and vignettes alike. Call [`render()`](reference/render.html) only
when you want to set the width and height.

## What goes in the spec

Marks are the layers that draw data: points, lines, bars, areas, text,
rules, ribbons and links. Each is a `mark_*()` function, and mappings are
bare column names or expressions such as `factor(cyl)`.

[`interact()`](reference/interact.html) adds tooltips, hover effects, zoom,
brushing and click handling. [`selection()`](reference/selection.html)
defines named selections, including a clickable legend.

[`animate()`](reference/animate.html) controls how marks enter, and with
`by =` it steps through groups of the data.

[`compose()`](reference/compose.html) puts several plots in one widget and
can link their selections. [`facet()`](reference/facet.html),
[`marginals()`](reference/marginals.html) and
[`inset()`](reference/inset.html) add small multiples, marginal
distributions and inset plots.

[`theme_tokens()`](reference/theme_tokens.html) sets the look from a few
tokens such as font, background and accent. Text and grid colours are
derived from the background so they stay readable.

[`to_vegalite()`](reference/to_vegalite.html) converts a spec to Vega-Lite
JSON, and [`export()`](reference/export.html) writes a plot to an HTML or
JSON file.

## Learn more

The [Getting Started guide](articles/getting-started.html) runs through
each feature with live plots you can hover, zoom and brush. The
[function reference](reference/index.html) lists everything glyph exports,
and [ARCHITECTURE.md](ARCHITECTURE.html) explains how the spec, the compiler
and the renderer fit together.
