# glyph

I built glyph so I could make interactive graphs straight from my R
scripts, without writing a lot of extra code just to make a plot
interactive. It is for anyone who wants a simpler grammar for
interactive graphics in R. glyph is in its early stages, and new
features are being added regularly.

## Installation

```r
install.packages("glyph")

# Development version
# remotes::install_github("josh45-source/glyph")
```

## A first plot

```r
library(glyph)

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, size = hp)
```

`glyph()` takes the data and the mappings shared by every mark. Mappings are
bare column names, or expressions such as `log(wt)` or `factor(cyl)`. Each
`mark_*()` adds a layer and can add mappings of its own.

The result is a specification: a plain R list that describes the data, the
marks, the scales, the interactions and the animation. Nothing is drawn until
it is printed or rendered. At that point `compile()` turns the spec into JSON
and a D3 renderer draws it in the browser as an htmlwidget.

## Drawing a plot

Plots print automatically. Type the name of a plot at the console, or leave
it as the last value of a pipeline, and it is drawn in the viewer. In R
Markdown, Quarto and vignettes it is drawn in the document. Layouts built
with `compose()` work the same way. You only need `render()` when you want
to set the width and height yourself:

```r
p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()

p                                    # drawn at the default size
render(p, width = 600, height = 400) # drawn at 600 x 400
```

For a text description of a plot or a layout, use `summary()`.

## Interaction

Tooltips, hover effects, zoom and brushing are part of the spec. They are
added with `interact()`:

```r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(
    tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons",
    zoom = TRUE,
    hover = "enlarge"
  )
```

A tooltip can be `TRUE`, which lists every mapped column, or a template with
column names in braces. Named selections, including a clickable legend, come
from `selection()`.

## Animation

`animate()` sets how marks enter and how they move between states.

```r
glyph(mtcars, x = cyl, y = mpg) |>
  mark_bar() |>
  animate(transition = "slide", stagger = 80, easing = "bounce") |>
  set_scale("y", zero = TRUE, label = "Miles per gallon")
```

With `by`, the plot steps through groups of the data and the marks move from
one group to the next. A play/pause control is added to the plot.

```r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(size = hp, color = cyl) |>
  animate(by = gear, transition = "morph", duration = 800)
```

## Layout

Several plots can share one widget. With `linked_selections = TRUE`, brushing
points in one panel highlights the same rows in the others.

```r
p1 <- glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)
p2 <- glyph(mtcars, x = hp, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

compose(p1, p2, type = "hstack", linked_selections = TRUE)
```

`facet()` splits one plot into small multiples. `marginals()` adds a
histogram, density curve or boxplot along each axis. `inset()` places a
second plot in a corner of the first.

```r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  marginals(x = "histogram", y = "density")
```

## Themes

Colours, fonts and spacing come from a small set of tokens: font,
background, foreground, accent, grid and padding. Set a few and the rest are
derived. A dark background gets light
text and a grid colour that still shows up against it.

```r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  theme_tokens(font = "Inter", bg = "#1a1a2e") |>
  titles(title = "Motor Trend Cars", subtitle = "Weight vs fuel efficiency")
```

There are five presets: `"light"`, `"dark"`, `"minimal"`, `"publication"`
and `"presentation"`. Use one with `theme_tokens(preset = "dark")`.

## Inspecting and exporting

Because the plot is data, you can look inside it before anything is drawn.
`summary()` lists what a spec contains. `compile()` resolves the mappings and
scales and returns the JSON that the renderer reads. `to_vegalite()` converts
a spec to Vega-Lite JSON for use in the Vega Editor, Altair or JavaScript.

`export()` writes a plot to a file:

```r
export(p, "plot.html")  # interactive widget
export(p, "plot.json")  # the compiled spec
```

A single self-contained HTML file needs pandoc, which RStudio includes.
Without pandoc, `export()` writes the HTML with a `plot_files` folder next to
it. Static SVG, PNG and PDF export are not implemented yet.

## Rendering

There is one renderer: an HTML widget drawn with D3.js and SVG.
`compile(engine = ...)` accepts `"auto"` or `"html"` and rejects anything
else. The spec does not depend on the renderer, so other backends can be
added later without changing how plots are written. See
[ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit together.

## Status

glyph is at version 0.1. It has point, line, bar, area, text, rule, ribbon,
link and polygon marks, and boxplot, violin, sina and histogram marks that
compute their statistics from the data. It supports tooltips, hover, click, zoom,
brushing and crossfilter; entrance and keyframe animation; `compose()`,
`facet()`, `marginals()` and `inset()`; theme tokens and presets; JSON
and Vega-Lite export; and Shiny apps, through `glyphOutput()` and
`renderGlyph()`, with brush, click and legend selections sent to the server
as row numbers.

Large plots are limited by the browser, not by R. A 100,000-point scatter
plot takes about 0.1s to compile and under half a second to reach the
Viewer, but every point is an SVG element, so the browser slows down as
points are added. Point plots respond to hover, brushing and zoom in under
0.1s up to about 10,000 points. At 15,000 points a step takes about 0.1s, at
50,000 about half a second, and at 100,000 about a second, and the plot
takes about 2s to draw. Zooming a 100,000-point line takes about 0.8s per
step. Boxplots and histograms send only their summaries, so at 100,000 rows
they draw in under 0.1s and respond within a frame. Exporting a
100,000-point plot to a single HTML file takes several seconds, most of it
in pandoc. These numbers come from Chromium on a 4-core machine; the details
are in [#8](https://github.com/josh45-source/glyph/issues/8).

Not done yet:

- Statistical transforms as separate pipeline steps (smooth, density, bin,
  aggregate)
- Drawing point and sina marks on a canvas above a row threshold
  ([#20](https://github.com/josh45-source/glyph/issues/20)), and a hexbin
  mark ([#21](https://github.com/josh45-source/glyph/issues/21))
- A legend drawn by default for colour scales. Today a legend appears only
  when you add one with `selection("legend", type = "legend")`.
- Keyboard accessibility
- Network, treemap and sunburst marks
- Static SVG, PNG and PDF export
- Importing Vega-Lite specs
- Arrow and DuckDB data sources for data that doesn't fit in memory

## Contributing

glyph is early, and feedback on the design is as useful as code. Bug reports,
questions and ideas are welcome in the
[issue tracker](https://github.com/josh45-source/glyph/issues).

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
