# glyph (development version)

* New browser tests (#28) draw plots in headless Chrome through chromote and
  check what was drawn: that plots draw at all, that slide-animated bars end
  at their full height, that the x axis stays visible in a wide, short
  container, box and histogram geometry, polygon vertices, one tooltip per
  widget after repeated resizes, widgets in knitted documents, and the
  "Clear selection" and "Reset zoom" buttons. They are skipped on CRAN and
  wherever chromote or Chrome isn't available, and a GitHub Actions
  workflow runs them on every pull request. chromote, htmltools and withr
  are new suggested packages.
* New "Clear selection" button in a plot's controls bar, shown while a
  brush selection exists (#26). Clicking or tapping it clears the selection
  and restores every mark, including marks in panels linked with
  `compose(linked_selections = TRUE)`. Pressing Escape clears brush
  selections too, unless you are typing in a text field. Plots with a brush
  but no zoom now get a controls bar for the button. When the controls don't
  fit the plot's width, as in small facet panels, they show just their
  symbols, with the full label in their tooltip.
* "Reset zoom" and double-click zooming no longer lag on large plots (#25).
  They jump straight to the result instead of animating when the plot has
  3,000 or more elements, since each frame of the animation redrew every
  point. At 15,000 points a reset now takes about 50ms instead of 470ms.
  Each zoom step still redraws every point, which canvas drawing (#20) is
  meant to fix.
* Tooltips no longer fall behind the pointer over dense areas of a large
  point plot (#23). With brushing on, each pointer move used to search every
  point for the nearest one and move the tooltip, and in WebKit moving the
  tooltip repainted the plot underneath it. At 15,000 points one move took
  about half a second, so moves queued up and the tooltip kept changing for
  over a minute after the pointer stopped. Points are now found through a
  quadtree, pointer moves are handled at most once per frame for the latest
  position, and the tooltip is drawn on its own layer so moving it doesn't
  repaint the plot. The same points are found as before.
* Redrawing a plot no longer leaves old tooltips in the page. Every resize
  redraws the plot, and fitting it to its container can take up to three
  draws, and each draw added another tooltip for every mark with one, plus
  click listeners that kept the replaced plot in memory. A faceted plot
  resized ten times left 144 tooltips behind, and a tooltip showing when
  the plot was redrawn could stay on screen. Each widget now has one
  tooltip, which a redraw hides and reuses.
* Plots with many rows are much quicker to prepare (#8). Plot data now goes
  to the browser as one array per column instead of one object per row, and
  is turned back into rows in the browser before anything is drawn. Each row
  is sent once: a mark that draws the plot's own data refers to it instead
  of carrying a second copy. Boxplot, violin and histogram marks send their
  summaries and the row indices that brushing and linked selections use, not
  the raw rows. At 100,000 points `compile()` takes 0.1s instead of 65s, the
  widget is ready for the Viewer in 0.4s, and the file is 5 MB instead of
  14 MB. Plots look and behave as before.
* The compiled JSON (`compile()$json` and `export(..., "plot.json")`) has a
  new data layout, marked by `"$schema": "glyph/v0.2"`. Data is
  `{"columns": {...}, "n": rows}`, and a mark that draws the plot's data has
  `{"from": "plot", "fields": [...], "rows": [...]}`, where `rows` is `null`
  or lists the 0-based rows it keeps after dropping missing values.
  Boxplot, violin, histogram and polygon marks send `{"values": [...]}`, one
  record per box, violin, bin or shape.
* New `mark_polygon()` draws closed shapes from x/y vertices, one per value
  of `group` (#7). Vertices are joined in row order, `color` fills each
  shape, `style` sets the fill, outline colour, outline width and opacity,
  and `radius` rounds the corners. Each polygon is one element: it gets one
  tooltip, and brushing or clicking it selects all of its rows, including
  in linked panels. It works with `facet()`, `compose()`, zoom, theme tokens,
  computed mappings and NA dropping.
* Boxplot, violin, sina and histogram marks no longer leave out rows whose
  colour is missing. Those rows now form a group of their own.
* Plots now fit inside their container in both directions (#17). A plot was
  drawn at the spec's width and height (600 x 400 unless set) and scaled to
  the container's width, so in a wide, short container such as RStudio's
  Viewer pane it came out taller than the space available and its x axis
  was cut off. The same happened to `facet()` grids, which also overflowed
  narrow containers, and plots in R Markdown documents ran past their 400px
  box into the text below. Plots and facet grids are now drawn at the size
  of the container they are in, and are redrawn when it is resized.
* New statistical marks (#6): `mark_boxplot()`, `mark_violin()`,
  `mark_sina()` and `mark_histogram()`. Their statistics are computed in R
  when the plot is compiled, with `stats::quantile()`, `stats::density()`
  and `hist()`-style bins, after computed mappings are evaluated and rows
  with missing values are dropped. They work with `facet()` (summaries are
  computed per panel), `compose()`, theme tokens, tooltips (which show the
  statistics), hover, click and brushing. Each box, violin or bin knows which
  rows it summarises, so brushing points or linked panels highlights the
  boxes and bins that contain the selected rows, and brushing a box selects
  its rows.
* Brushing and zooming now apply to the whole plot rather than to each point
  mark separately. A plot with several brushable marks gets one brush that
  covers all of them, and `interact(zoom = TRUE)` now zooms plots that have
  no point mark.
* Points on a categorical x axis are now drawn in the middle of their
  category instead of at its left edge.
* A quantitative axis now spans the values of every mark in the plot, not
  just the first, so a second mark with a wider range is no longer cut off.
* Automatic tooltips show a computed mapping by its expression (e.g.
  `factor(cyl)`) instead of its internal column name, and tooltip templates
  can refer to fields whose names contain dots, such as `{.median}`.
* Plots and layouts now draw automatically in R Markdown, Quarto and
  vignettes, without ending the pipeline with `render()` (#13). glyph
  registers `knit_print()` methods for `glyph_spec` and `glyph_layout`;
  knitr stays a suggested package. Printing a `compose()` layout at the
  console now draws it, the same as a single plot, and the text description
  it used to print is available from the new `summary.glyph_layout()`.
  `render()` is still there for setting the width and height.
* Rewrote the README, the pkgdown home page, `ARCHITECTURE.md` and the
  Getting Started vignette in plainer language (#4).
* Removed the comparisons with ggplot2 from the documentation, including the
  comparison tables in the README and the "glyph vs ggplot2" vignette. The
  package Title and Description now describe what glyph does (#5).
* The help pages no longer compare glyph with other packages either, and
  several now describe the code more accurately. `?glyph` no longer claims
  that lists, URLs or Arrow tables are accepted as data, `?facet` no longer
  says panels get independent scales by default, and `?marks` and
  `?interactivity` drop features that don't exist (#5).
* `export()` to `.html` no longer fails on machines without pandoc (#3).
  Instead of a low-level pandoc error, it now writes the HTML with its
  JavaScript in a `<name>_files` folder alongside, and says so, including how
  to get a single self-contained file (install pandoc, or run inside
  RStudio). The pandoc requirement is now documented in `?export`.
* Fixed the entrance/slide animation for bar charts showing no bars on
  Safari and Chrome mobile (#2). The animation was reading a value that was
  never set and had already been zeroed out, so bars always animated to
  zero height; it now stores each bar's real height/position before
  animating.
* Made plots responsive: the SVG now scales to fill its container (via
  `viewBox`) instead of a fixed 600px width, and the theme background now
  always covers the full plot area. Previously a dark theme's background
  didn't reach the edges on narrower or wider containers, including on
  mobile.
* Added a reset-zoom control, and made double-tap reset the zoom instead of
  always zooming in further, so a zoomed-in plot can be zoomed back out on
  touch devices.
* Tooltips now also appear on tap and dismiss on tapping elsewhere, for
  touch devices that have no hover state.
* Brush selection now also clears on a tap outside the plot, not just on a
  no-drag tap inside it.
* Fixed tapping/clicking a point doing nothing when both `brush` and
  `tooltip`/`click` interactions were enabled on the same mark: the brush's
  full-plot overlay sits on top of the marks (so a drag can start from
  anywhere) and was swallowing the tap before it reached the point
  underneath.
* Fixed the same problem for continuous mouse hover: hovering over a point
  did nothing (no tooltip, no hover effect) whenever `brush` was also
  enabled on that mark, for the same reason as the tap fix above. Brushing
  itself still works by dragging from anywhere in the plot area.
* Fixed one drag both panning and brushing when `zoom` and `brush` were
  enabled on the same mark: zoom binds its drag to the `<svg>` and brush to
  an overlay inside it, so a single mousedown started both gestures. A drag
  now does one thing at a time — it brushes by default when brushing is
  available, and a small toggle next to the reset-zoom control (shown only
  when both are enabled) switches dragging between selecting and panning.
  The scroll wheel, a trackpad pinch, a two-finger pinch and a
  double-click/double-tap always zoom, whichever mode the toggle is in.
* Two-finger pinch-zoom now works on plots that also have `brush` enabled.
  d3-brush stops propagation of every touch move once its one-finger
  gesture starts, so a second finger never reached the zoom behavior; the
  pinch is now handled before anything can intercept it.
* Fixed the plot jumping by its axis-margin offset the first time it was
  zoomed or panned — the zoom transform replaced the plot group's existing
  margin translate instead of composing with it.
* Clicking the reset-zoom control no longer discards the brush selection.
* Tapping the plot's margin (inside the chart but outside the plot area)
  now clears the brush selection, as tapping outside the widget already did.
* Double-tap zoom/reset on touch no longer depends on d3-zoom's internal
  gesture detection, which also makes it work for repeated double-taps and
  while dragging is set to brushing.
* Computed aesthetic mappings (e.g. `x = log(wt)`, `color = factor(cyl)`)
  are now evaluated at compile time instead of being silently dropped; the
  expression text is used as the default axis/legend label.
* Rows with `NA` in a mapped position aesthetic (`x`, `y`, `x2`, `y2`,
  `y_min`, `y_max`) are now dropped for that mark at compile time, with a
  warning reporting how many rows were removed and from which
  aesthetic(s), similar to ggplot2.
* `facet(rows =, cols =)` now accepts a computed expression (e.g.
  `facet(cols = factor(cyl))`), evaluated the same way as an aesthetic
  mapping — previously the raw expression text was used as a literal
  (nonexistent) column name, so faceting on anything but a plain column
  silently produced a single, unlabeled facet.
* Faceted panels now use each mark's own resolved data — computed mapping
  columns and NA-dropped rows included — instead of an unfiltered slice of
  the shared data, so `facet()` combined with a computed mapping or with
  `NA` values now behaves the same as the unfaceted case.
* Removed the auto-selection of a "canvas" or "webgl" rendering engine by
  data size in `compile()` — no such renderer has ever existed, only the
  D3/SVG renderer does, so the "selection" never did anything.
  `compile(engine = ...)` now only accepts `"auto"`/`"html"` and errors on
  other values instead of silently accepting them.
* Removed remaining claims of WebGL/Canvas rendering and standalone static
  SVG export from the package description, documentation, README, and
  ARCHITECTURE.md; a Canvas renderer is planned for a future release.
* Added Mike Bostock to `Authors@R` and `inst/COPYRIGHTS` to credit the
  bundled D3.js library (ISC license), per CRAN policy for bundled
  JavaScript.
* Added an "Acknowledgements" section to the README and the glyph-package
  help page, crediting the prior art glyph's design draws on.
* Documented `mark_text(smart_repel = TRUE)`'s actual method (iterative
  pairwise nudging of overlapping label boxes) instead of leaving it
  unspecified, and credited ggrepel as the inspiration.
* Fixed roxygen warnings that were silently skipping the `summary.glyph_spec`
  and `print.glyph_layout` help topics for lacking a title.

# glyph 0.1.1

* Fixed critical rendering bug where interactive plots displayed as blank
  in RStudio viewer, R Markdown documents, and Shiny apps. Data was being
  serialized in column-oriented format instead of the row-records format
  expected by the 'D3.js' frontend.
* Added error surfacing in the htmlwidget so JavaScript failures display
  a visible error message instead of a silent blank div.
* Added sizing policy for better default widget dimensions in R Markdown
  and pkgdown contexts.


# glyph 0.1.0

* Initial CRAN release.
* Core spec builder with quosure-based aesthetic mappings (no `aes()` required).
* Eight mark types: `mark_point()`, `mark_line()`, `mark_bar()`, `mark_area()`,
  `mark_text()`, `mark_rule()`, `mark_ribbon()`, `mark_link()`.
* First-class interactivity via `interact()`: tooltips, zoom, brush selection,
  hover effects, cross-filtering, and named selections.
* Declarative animation via `animate()`: entrance transitions and keyframe
  animation through data states.
* Unified scale system via `scale()` with convenience wrappers `scale_color()`,
  `scale_log()`, `scale_time()`.
* Token-based theming via `theme_tokens()` with five built-in presets:
  light, dark, minimal, publication, presentation.
* Built-in layout composition via `compose()`, `marginals()`, `inset()`,
  and `facet()`.
* Compilation pipeline via `compile()`, rendering to interactive HTML
  widgets via D3.js.
* JSON spec export via `export()` and Vega-Lite interoperability via
 `to_vegalite()`.
* D3.js v7 rendering engine via 'htmlwidgets'.
