# glyph (development version)

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
