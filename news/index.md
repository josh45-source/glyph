# Changelog

## glyph 0.2.0

CRAN release: 2026-10-21

### Breaking changes

- [`scale()`](https://rdrr.io/r/base/scale.html) is now
  [`set_scale()`](https://josh45-source.github.io/glyph/reference/set_scale.md)
  ([\#36](https://github.com/josh45-source/glyph/issues/36)). glyph’s
  [`scale()`](https://rdrr.io/r/base/scale.html) had the same name as
  [`base::scale()`](https://rdrr.io/r/base/scale.html), so
  [`library(glyph)`](https://github.com/josh45-source/glyph) masked the
  base function. It printed “The following object is masked from
  ‘package:base’: scale”, and base uses such as `scale(df$x)` failed
  afterwards with an error about glyph specs.
  [`set_scale()`](https://josh45-source.github.io/glyph/reference/set_scale.md)
  takes the same arguments. To update your code, change each
  [`scale()`](https://rdrr.io/r/base/scale.html) step in a glyph
  pipeline to
  [`set_scale()`](https://josh45-source.github.io/glyph/reference/set_scale.md):

  ``` r

  # Before
  glyph(mtcars, x = wt, y = mpg) |> mark_point() |> scale("y", zero = TRUE)
  # After
  glyph(mtcars, x = wt, y = mpg) |> mark_point() |> set_scale("y", zero = TRUE)
  ```

  Base uses of [`scale()`](https://rdrr.io/r/base/scale.html) work again
  and need no change.
  [`scale_color()`](https://josh45-source.github.io/glyph/reference/scales.md),
  [`scale_log()`](https://josh45-source.github.io/glyph/reference/scales.md)
  and
  [`scale_time()`](https://josh45-source.github.io/glyph/reference/scales.md)
  keep their names.
  [`library(glyph)`](https://github.com/josh45-source/glyph) no longer
  masks any function.

- The compiled JSON (`compile()$json` and `export(..., "plot.json")`)
  has a new data layout, marked by `"$schema": "glyph/v0.2"`
  ([\#8](https://github.com/josh45-source/glyph/issues/8)). Data is
  `{"columns": {...}, "n": rows}`, and a mark that draws the plot’s data
  has `{"from": "plot", "fields": [...], "rows": [...]}`, where `rows`
  is `null` or lists the 0-based rows it keeps after dropping missing
  values. Boxplot, violin, histogram and polygon marks send
  `{"values": [...]}`, one record per box, violin, bin or shape. Code
  that reads JSON written by glyph 0.1 needs updating.

- `compile(engine = ...)` accepts only `"auto"` and `"html"`, and gives
  an error for anything else. It used to accept `"canvas"` and `"webgl"`
  and pick one by data size, but no such renderer has ever existed, so
  the choice did nothing. The D3 and SVG renderer is the only one.

- Printing a
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  layout at the console now draws it, as printing a single plot does
  ([\#13](https://github.com/josh45-source/glyph/issues/13)). The text
  description it used to print comes from the new
  [`summary.glyph_layout()`](https://josh45-source.github.io/glyph/reference/summary.glyph_layout.md).

### New features

- glyph works in Shiny
  ([\#34](https://github.com/josh45-source/glyph/issues/34)).
  [`glyphOutput()`](https://josh45-source.github.io/glyph/reference/glyph-shiny.md)
  and
  [`renderGlyph()`](https://josh45-source.github.io/glyph/reference/glyph-shiny.md)
  place and draw a plot, and
  [`renderGlyph()`](https://josh45-source.github.io/glyph/reference/glyph-shiny.md)
  takes a plot, a
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  layout or a widget from
  [`render()`](https://josh45-source.github.io/glyph/reference/render.md).
  What the user selects reaches the server as
  `input$<outputId>_selected`: the row numbers of the data frame given
  to
  [`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md),
  so `data[input$plot_selected, ]` gives the selected rows. The numbers
  stay right when rows with missing values are dropped and when a
  mapping is computed, and selecting a box, bin or polygon selects the
  rows it summarises. The value is sent when a brush ends, on a click
  select and on a legend click, and clearing a selection sends `NULL`. A
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  grid gives one vector, and a
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  layout gives a list with one entry per panel, named after the panels
  when
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  is given names. shiny is suggested, not required. A new article,
  “Using glyph in Shiny”
  ([`vignette("shiny", package = "glyph")`](https://josh45-source.github.io/glyph/articles/shiny.md)),
  is built around an example app in `inst/examples/shiny-brush`.
- New statistical marks
  ([\#6](https://github.com/josh45-source/glyph/issues/6)):
  [`mark_boxplot()`](https://josh45-source.github.io/glyph/reference/mark_boxplot.md),
  [`mark_violin()`](https://josh45-source.github.io/glyph/reference/mark_violin.md),
  [`mark_sina()`](https://josh45-source.github.io/glyph/reference/mark_sina.md)
  and
  [`mark_histogram()`](https://josh45-source.github.io/glyph/reference/mark_histogram.md).
  Their statistics are computed in R when the plot is compiled, with
  [`stats::quantile()`](https://rdrr.io/r/stats/quantile.html),
  [`stats::density()`](https://rdrr.io/r/stats/density.html) and
  [`hist()`](https://rdrr.io/r/graphics/hist.html)-style bins, after
  computed mappings are evaluated and rows with missing values are
  dropped. They work with
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  (summaries are computed per panel),
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md),
  theme tokens, tooltips (which show the statistics), hover, click and
  brushing. Each box, violin or bin knows which rows it summarises, so
  brushing points or linked panels highlights the boxes and bins that
  contain the selected rows, and brushing a box selects its rows.
- New
  [`mark_polygon()`](https://josh45-source.github.io/glyph/reference/mark_polygon.md)
  draws closed shapes from x/y vertices, one per value of `group`
  ([\#7](https://github.com/josh45-source/glyph/issues/7)). Vertices are
  joined in row order, `color` fills each shape, `style` sets the fill,
  outline colour, outline width and opacity, and `radius` rounds the
  corners. Each polygon is one element: it gets one tooltip, and
  brushing or clicking it selects all of its rows, including in linked
  panels. It works with
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md),
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md),
  zoom, theme tokens, computed mappings and NA dropping.
- Plots and layouts now draw automatically in R Markdown, Quarto and
  vignettes, without ending the pipeline with
  [`render()`](https://josh45-source.github.io/glyph/reference/render.md)
  ([\#13](https://github.com/josh45-source/glyph/issues/13)). glyph
  registers `knit_print()` methods for `glyph_spec` and `glyph_layout`;
  knitr stays a suggested package.
  [`render()`](https://josh45-source.github.io/glyph/reference/render.md)
  is still there for setting the width and height.
- Plots with many rows are much quicker to prepare
  ([\#8](https://github.com/josh45-source/glyph/issues/8)). Plot data
  now goes to the browser as one array per column instead of one object
  per row, and is turned back into rows in the browser before anything
  is drawn. Each row is sent once: a mark that draws the plot’s own data
  refers to it instead of carrying a second copy. Boxplot, violin and
  histogram marks send their summaries and the row indices that brushing
  and linked selections use, not the raw rows. At 100,000 points
  [`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
  takes 0.1s instead of 65s, the widget is ready for the Viewer in 0.4s,
  and the file is 5 MB instead of 14 MB. Plots look and behave as
  before.
- New “Clear selection” button in a plot’s controls bar, shown while a
  brush selection exists
  ([\#26](https://github.com/josh45-source/glyph/issues/26)). Clicking
  or tapping it clears the selection and restores every mark, including
  marks in panels linked with `compose(linked_selections = TRUE)`.
  Pressing Escape clears brush selections too, unless you are typing in
  a text field. Plots with a brush but no zoom now get a controls bar
  for the button. When the controls don’t fit the plot’s width, as in
  small facet panels, they show just their symbols, with the full label
  in their tooltip.
- New reset-zoom control. A double tap now resets the zoom instead of
  zooming in further, so a zoomed plot can be zoomed back out on a touch
  device.
- Tooltips now appear on tap, and a tap elsewhere dismisses them, for
  touch devices that have no hover.
- New article, “Adding a custom mark”
  ([`vignette("custom-marks")`](https://josh45-source.github.io/glyph/articles/custom-marks.md)),
  walks through adding a mark type end to end with a worked example
  ([\#9](https://github.com/josh45-source/glyph/issues/9)). It covers
  the R function and `add_mark()`, how mappings are resolved when the
  plot is compiled, how data reaches the browser, the drawing code in
  `glyph.js`, axes, tooltips, hover, brushing, fitting the container,
  tests, and marks that summarise data. It also says plainly that adding
  a mark means editing glyph’s source, and what would need to change for
  other packages to add marks.
- Rewrote the README, the pkgdown home page, `ARCHITECTURE.md` and the
  Getting Started vignette in plainer language
  ([\#4](https://github.com/josh45-source/glyph/issues/4)). Removed the
  comparisons with ggplot2 from the documentation, including the
  comparison tables in the README and the “glyph vs ggplot2” vignette.
  The package Title and Description now describe what glyph does
  ([\#5](https://github.com/josh45-source/glyph/issues/5)). The README
  and the glyph-package help page have an “Acknowledgements” section
  crediting the prior art glyph’s design draws on.
- For contributors: browser tests
  ([\#28](https://github.com/josh45-source/glyph/issues/28)) draw plots
  in headless Chrome through chromote and check what was drawn. They
  check several of the bugs fixed in this release, and the selections
  sent to Shiny. They are skipped on CRAN and wherever chromote or
  Chrome isn’t available. GitHub Actions runs them, the pkgdown site
  build, and `R CMD check` on Windows, macOS and Linux for every pull
  request ([\#31](https://github.com/josh45-source/glyph/issues/31)).

### Bug fixes

- Bar and area charts now start their value axis at zero
  ([\#29](https://github.com/josh45-source/glyph/issues/29)). The y axis
  used to start at the smallest value, so the smallest bar had no height
  and the others weren’t in proportion to their values. Bars and areas
  are now drawn from zero, so a negative bar hangs down from zero
  instead of rising from the bottom of the plot. Histograms already
  started at zero. A domain set with
  [`set_scale()`](https://josh45-source.github.io/glyph/reference/set_scale.md)
  is used as given, including on the shared axes of
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  and
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md).
  Point and line marks are unchanged.
- Plots now fit inside their container in both directions
  ([\#17](https://github.com/josh45-source/glyph/issues/17)). A plot was
  drawn at the spec’s width and height (600 x 400 unless set) and scaled
  to the container’s width, so in a wide, short container such as
  RStudio’s Viewer pane it came out taller than the space available and
  its x axis was cut off. The same happened to
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  grids, which also overflowed narrow containers, and plots in R
  Markdown documents ran past their 400px box into the text below. Plots
  and facet grids are now drawn at the size of the container they are
  in, and are redrawn when it is resized.
- Tooltips no longer fall behind the pointer over dense areas of a large
  point plot ([\#23](https://github.com/josh45-source/glyph/issues/23)).
  With brushing on, each pointer move used to search every point for the
  nearest one and move the tooltip, and in WebKit moving the tooltip
  repainted the plot underneath it. At 15,000 points one move took about
  half a second, so moves queued up and the tooltip kept changing for
  over a minute after the pointer stopped. Points are now found through
  a quadtree, pointer moves are handled at most once per frame for the
  latest position, and the tooltip is drawn on its own layer so moving
  it doesn’t repaint the plot. The same points are found as before.
- Redrawing a plot no longer leaves old tooltips in the page
  ([\#23](https://github.com/josh45-source/glyph/issues/23)). Every
  resize redraws the plot, and fitting it to its container can take up
  to three draws. Each draw added another tooltip for every mark with
  one, plus click listeners that kept the replaced plot in memory. A
  faceted plot resized ten times left 144 tooltips behind, and a tooltip
  showing when the plot was redrawn could stay on screen. Each widget
  now has one tooltip, which a redraw hides and reuses.
- “Reset zoom” and double-click zooming no longer lag on large plots
  ([\#25](https://github.com/josh45-source/glyph/issues/25)). They jump
  straight to the result instead of animating when the plot has 3,000 or
  more elements, since each frame of the animation redrew every point.
  At 15,000 points a reset now takes about 50ms instead of 470ms. Each
  zoom step still redraws every point, which canvas drawing
  ([\#20](https://github.com/josh45-source/glyph/issues/20)) is meant to
  fix.
- [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  with named arguments, such as `compose(a = p1, b = p2)`, now draws
  ([\#34](https://github.com/josh45-source/glyph/issues/34)). The panels
  were sent as an object keyed by name instead of a list, and the widget
  showed a render error.
- [`export()`](https://josh45-source.github.io/glyph/reference/export.md)
  to `.html` no longer fails on machines without pandoc
  ([\#3](https://github.com/josh45-source/glyph/issues/3)). Instead of a
  low-level pandoc error, it now writes the HTML with its JavaScript in
  a `<name>_files` folder alongside, and says so, including how to get a
  single self-contained file (install pandoc, or run inside RStudio).
  The pandoc requirement is now documented in
  [`?export`](https://josh45-source.github.io/glyph/reference/export.md).
- The entrance (slide) animation for bar charts no longer shows no bars
  on Safari and Chrome mobile
  ([\#2](https://github.com/josh45-source/glyph/issues/2)). The
  animation read a value that was never set, so bars always animated to
  zero height. It now stores each bar’s real height and position before
  animating.
- Brushing and zooming now apply to the whole plot rather than to each
  point mark separately
  ([\#6](https://github.com/josh45-source/glyph/issues/6)). A plot with
  several brushable marks gets one brush that covers all of them, and
  `interact(zoom = TRUE)` now zooms plots that have no point mark.
- Points on a categorical x axis are now drawn in the middle of their
  category instead of at its left edge
  ([\#6](https://github.com/josh45-source/glyph/issues/6)).
- A quantitative axis now spans the values of every mark in the plot,
  not just the first, so a second mark with a wider range is no longer
  cut off ([\#6](https://github.com/josh45-source/glyph/issues/6)).
- Automatic tooltips show a computed mapping by its expression (such as
  `factor(cyl)`) instead of its internal column name, and tooltip
  templates can refer to fields whose names contain dots, such as
  `{.median}` ([\#6](https://github.com/josh45-source/glyph/issues/6)).
- Boxplot, violin, sina and histogram marks no longer leave out rows
  whose colour is missing. Those rows now form a group of their own
  ([\#7](https://github.com/josh45-source/glyph/issues/7)).
- Computed aesthetic mappings, such as `x = log(wt)` or
  `color = factor(cyl)`, are now evaluated when the plot is compiled.
  They used to be dropped without a message. The expression is used as
  the default axis or legend label.
- Rows with a missing value in a mapped position aesthetic (`x`, `y`,
  `x2`, `y2`, `y_min`, `y_max`) are now dropped from that mark when the
  plot is compiled, with a warning that says how many rows were removed
  and for which aesthetics.
- `facet(rows =, cols =)` now accepts a computed expression, such as
  `facet(cols = factor(cyl))`, evaluated the same way as an aesthetic
  mapping. The expression text used to be taken as a column name that
  didn’t exist, so faceting on anything but a plain column gave a
  single, unlabelled panel.
- Faceted panels now use each mark’s own resolved data, with its
  computed columns and with rows dropped for missing values, instead of
  an unfiltered slice of the shared data. So
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  with a computed mapping or with missing values behaves the same as an
  unfaceted plot.
- Plots scale to fill their container instead of being drawn 600px wide,
  and the theme background always covers the whole plot area. A dark
  theme’s background used to stop short of the edges in narrower or
  wider containers, including on phones.
- With brushing on, tapping or clicking a point now reaches it, so its
  tooltip and click select work. The brush’s overlay covers the plot so
  a drag can start anywhere, and it used to swallow the tap. Hovering
  over a point with brushing on now shows its tooltip and hover effect
  too, for the same reason. Brushing still works by dragging from
  anywhere in the plot.
- With both zoom and brushing on, one drag no longer both pans and
  brushes. A drag now does one thing at a time. It brushes by default,
  and a small toggle next to the reset-zoom control switches dragging
  between selecting and panning. The scroll wheel, a trackpad pinch, a
  two-finger pinch and a double-click or double tap always zoom,
  whichever mode the toggle is in.
- A two-finger pinch now zooms plots that also have brushing on.
  d3-brush stopped every touch move from reaching the zoom once its
  one-finger gesture started. The pinch is now handled first.
- The plot no longer jumps by its axis margin the first time it is
  zoomed or panned. The zoom transform replaced the margin offset
  instead of adding to it.
- Clicking the reset-zoom control no longer clears the brush selection.
- A brush selection now also clears on a tap outside the plot, or on the
  plot’s margin, not only on a tap inside the plot area.
- A double tap zooms or resets reliably, including repeated double taps
  and while dragging is set to brushing. It no longer depends on
  d3-zoom’s own gesture detection.
- The help pages no longer compare glyph with other packages, and
  several describe the code more accurately
  ([\#5](https://github.com/josh45-source/glyph/issues/5)).
  [`?glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)
  no longer claims that lists, URLs or Arrow tables are accepted as
  data,
  [`?facet`](https://josh45-source.github.io/glyph/reference/facet.md)
  no longer says panels get independent scales by default, and
  [`?marks`](https://josh45-source.github.io/glyph/reference/marks.md)
  and
  [`?interactivity`](https://josh45-source.github.io/glyph/reference/interactivity.md)
  drop features that don’t exist. The description, documentation, README
  and `ARCHITECTURE.md` no longer claim WebGL or canvas rendering or
  standalone SVG export. A canvas renderer is planned
  ([\#20](https://github.com/josh45-source/glyph/issues/20)).
- [`?mark_text`](https://josh45-source.github.io/glyph/reference/mark_text.md)
  now describes what `smart_repel = TRUE` does: it nudges overlapping
  label boxes apart, pair by pair, over several passes. It credits
  ggrepel as the inspiration.
- The `summary.glyph_spec` and `print.glyph_layout` help topics were
  left out because they had no title. They are back.
- Mike Bostock is now credited in `Authors@R` and `inst/COPYRIGHTS` as
  the author of the bundled D3.js library (ISC license), as CRAN policy
  asks for bundled JavaScript.

## glyph 0.1.1

CRAN release: 2026-07-08

- Fixed critical rendering bug where interactive plots displayed as
  blank in RStudio viewer, R Markdown documents, and Shiny apps. Data
  was being serialized in column-oriented format instead of the
  row-records format expected by the ‘D3.js’ frontend.
- Added error surfacing in the htmlwidget so JavaScript failures display
  a visible error message instead of a silent blank div.
- Added sizing policy for better default widget dimensions in R Markdown
  and pkgdown contexts.

## glyph 0.1.0

CRAN release: 2026-07-06

- Initial CRAN release.
- Core spec builder with quosure-based aesthetic mappings (no `aes()`
  required).
- Eight mark types:
  [`mark_point()`](https://josh45-source.github.io/glyph/reference/mark_point.md),
  [`mark_line()`](https://josh45-source.github.io/glyph/reference/mark_line.md),
  [`mark_bar()`](https://josh45-source.github.io/glyph/reference/mark_bar.md),
  [`mark_area()`](https://josh45-source.github.io/glyph/reference/mark_area.md),
  [`mark_text()`](https://josh45-source.github.io/glyph/reference/mark_text.md),
  [`mark_rule()`](https://josh45-source.github.io/glyph/reference/mark_rule.md),
  [`mark_ribbon()`](https://josh45-source.github.io/glyph/reference/mark_ribbon.md),
  [`mark_link()`](https://josh45-source.github.io/glyph/reference/mark_link.md).
- First-class interactivity via
  [`interact()`](https://josh45-source.github.io/glyph/reference/interact.md):
  tooltips, zoom, brush selection, hover effects, cross-filtering, and
  named selections.
- Declarative animation via
  [`animate()`](https://josh45-source.github.io/glyph/reference/animate.md):
  entrance transitions and keyframe animation through data states.
- Unified scale system via
  [`scale()`](https://rdrr.io/r/base/scale.html) with convenience
  wrappers
  [`scale_color()`](https://josh45-source.github.io/glyph/reference/scales.md),
  [`scale_log()`](https://josh45-source.github.io/glyph/reference/scales.md),
  [`scale_time()`](https://josh45-source.github.io/glyph/reference/scales.md).
- Token-based theming via
  [`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)
  with five built-in presets: light, dark, minimal, publication,
  presentation.
- Built-in layout composition via
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md),
  [`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.md),
  [`inset()`](https://josh45-source.github.io/glyph/reference/inset.md),
  and
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md).
- Compilation pipeline via
  [`compile()`](https://josh45-source.github.io/glyph/reference/compile.md),
  rendering to interactive HTML widgets via D3.js.
- JSON spec export via
  [`export()`](https://josh45-source.github.io/glyph/reference/export.md)
  and Vega-Lite interoperability via
  [`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md).
- D3.js v7 rendering engine via ‘htmlwidgets’.
