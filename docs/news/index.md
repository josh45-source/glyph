# Changelog

## glyph (development version)

- Fixed the entrance/slide animation for bar charts showing no bars on
  Safari and Chrome mobile
  ([\#2](https://github.com/josh45-source/glyph/issues/2)). The
  animation was reading a value that was never set and had already been
  zeroed out, so bars always animated to zero height; it now stores each
  bar’s real height/position before animating.
- Made plots responsive: the SVG now scales to fill its container (via
  `viewBox`) instead of a fixed 600px width, and the theme background
  now always covers the full plot area. Previously a dark theme’s
  background didn’t reach the edges on narrower or wider containers,
  including on mobile.
- Added a reset-zoom control, and made double-tap reset the zoom instead
  of always zooming in further, so a zoomed-in plot can be zoomed back
  out on touch devices.
- Tooltips now also appear on tap and dismiss on tapping elsewhere, for
  touch devices that have no hover state.
- Brush selection now also clears on a tap outside the plot, not just on
  a no-drag tap inside it.
- Fixed tapping/clicking a point doing nothing when both `brush` and
  `tooltip`/`click` interactions were enabled on the same mark: the
  brush’s full-plot overlay sits on top of the marks (so a drag can
  start from anywhere) and was swallowing the tap before it reached the
  point underneath.
- Fixed the same problem for continuous mouse hover: hovering over a
  point did nothing (no tooltip, no hover effect) whenever `brush` was
  also enabled on that mark, for the same reason as the tap fix above.
  Brushing itself still works by dragging from anywhere in the plot
  area.
- Computed aesthetic mappings (e.g. `x = log(wt)`,
  `color = factor(cyl)`) are now evaluated at compile time instead of
  being silently dropped; the expression text is used as the default
  axis/legend label.
- Rows with `NA` in a mapped position aesthetic (`x`, `y`, `x2`, `y2`,
  `y_min`, `y_max`) are now dropped for that mark at compile time, with
  a warning reporting how many rows were removed and from which
  aesthetic(s), similar to ggplot2.
- `facet(rows =, cols =)` now accepts a computed expression (e.g.
  `facet(cols = factor(cyl))`), evaluated the same way as an aesthetic
  mapping — previously the raw expression text was used as a literal
  (nonexistent) column name, so faceting on anything but a plain column
  silently produced a single, unlabeled facet.
- Faceted panels now use each mark’s own resolved data — computed
  mapping columns and NA-dropped rows included — instead of an
  unfiltered slice of the shared data, so
  [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  combined with a computed mapping or with `NA` values now behaves the
  same as the unfaceted case.
- Removed the auto-selection of a “canvas” or “webgl” rendering engine
  by data size in
  [`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
  — no such renderer has ever existed, only the D3/SVG renderer does, so
  the “selection” never did anything. `compile(engine = ...)` now only
  accepts `"auto"`/`"html"` and errors on other values instead of
  silently accepting them.
- Removed remaining claims of WebGL/Canvas rendering and standalone
  static SVG export from the package description, documentation, README,
  and ARCHITECTURE.md; a Canvas renderer is planned for a future
  release.
- Added Mike Bostock to `Authors@R` and `inst/COPYRIGHTS` to credit the
  bundled D3.js library (ISC license), per CRAN policy for bundled
  JavaScript.
- Added an “Acknowledgements” section to the README and the
  glyph-package help page, crediting the prior art glyph’s design draws
  on.
- Documented `mark_text(smart_repel = TRUE)`’s actual method (iterative
  pairwise nudging of overlapping label boxes) instead of leaving it
  unspecified, and credited ggrepel as the inspiration.
- Fixed roxygen warnings that were silently skipping the
  `summary.glyph_spec` and `print.glyph_layout` help topics for lacking
  a title.

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
- Core spec builder with quosure-based aesthetic mappings (no
  [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html) required).
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
  [`scale()`](https://josh45-source.github.io/glyph/reference/scale.md)
  with convenience wrappers
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
