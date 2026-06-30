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
* Multi-backend compilation pipeline with auto engine selection based on
  data size (HTML/D3, Canvas, WebGL).
* JSON spec export via `export()` and Vega-Lite interoperability via
 `to_vegalite()`.
* D3.js v7 rendering engine via 'htmlwidgets'.
