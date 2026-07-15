# Changelog

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
- Multi-backend compilation pipeline with auto engine selection based on
  data size (HTML/D3, Canvas, WebGL).
- JSON spec export via
  [`export()`](https://josh45-source.github.io/glyph/reference/export.md)
  and Vega-Lite interoperability via
  [`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md).
- D3.js v7 rendering engine via ‘htmlwidgets’.
