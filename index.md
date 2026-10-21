# glyph

I built glyph so I could make interactive graphs straight from my R
scripts, without writing a lot of extra code just to make a plot
interactive. It is for anyone who wants a simpler grammar for
interactive graphics in R. glyph is in its early stages, and new
features are being added regularly.

``` r

install.packages("glyph")

# Development version
# remotes::install_github("josh45-source/glyph")
```

## A first plot

``` r

library(glyph)

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, size = hp) |>
  interact(tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons", zoom = TRUE) |>
  scale("y", zero = TRUE, label = "Miles per gallon") |>
  theme_tokens(preset = "dark") |>
  titles(title = "Motor Trend Cars", subtitle = "Weight vs fuel efficiency")
```

Each step adds to a specification, a plain R list that describes the
whole plot. When the plot is printed, glyph compiles the spec to JSON
and draws it in the browser with D3.js. That happens at the console and
in R Markdown, Quarto and vignettes alike. Call
[`render()`](https://josh45-source.github.io/glyph/reference/render.md)
only when you want to set the width and height.

## What goes in the spec

Marks are the layers that draw data: points, lines, bars, areas, text,
rules, ribbons, links and polygons, plus boxplots, violins, sina points
and histograms, which summarise a variable’s distribution. Each is a
`mark_*()` function, and mappings are bare column names or expressions
such as `factor(cyl)`.

[`interact()`](https://josh45-source.github.io/glyph/reference/interact.md)
adds tooltips, hover effects, zoom, brushing and click handling.
[`selection()`](https://josh45-source.github.io/glyph/reference/selection.md)
defines named selections, including a clickable legend.

[`animate()`](https://josh45-source.github.io/glyph/reference/animate.md)
controls how marks enter, and with `by =` it steps through groups of the
data.

[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
puts several plots in one widget and can link their selections.
[`facet()`](https://josh45-source.github.io/glyph/reference/facet.md),
[`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.md)
and
[`inset()`](https://josh45-source.github.io/glyph/reference/inset.md)
add small multiples, marginal distributions and inset plots.

[`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)
sets the look from a few tokens such as font, background and accent.
Text and grid colours are derived from the background so they stay
readable.

[`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md)
converts a spec to Vega-Lite JSON, and
[`export()`](https://josh45-source.github.io/glyph/reference/export.md)
writes a plot to an HTML or JSON file.

## Learn more

The [Getting Started
guide](https://josh45-source.github.io/glyph/articles/getting-started.md)
runs through each feature with live plots you can hover, zoom and brush.
[Using glyph in
Shiny](https://josh45-source.github.io/glyph/articles/shiny.md) shows
how to read what the user selects from a Shiny server. The [function
reference](https://josh45-source.github.io/glyph/reference/index.md)
lists everything glyph exports, and
[ARCHITECTURE.md](https://josh45-source.github.io/glyph/ARCHITECTURE.md)
explains how the spec, the compiler and the renderer fit together.
