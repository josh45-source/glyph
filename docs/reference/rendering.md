# Rendering Pipeline

The rendering pipeline compiles a glyph_spec into output. The spec is
first resolved (evaluate quosures, drop rows with missing mapped values,
merge defaults), then serialized to JSON, then handed to a backend:

- **"html"** (default): htmlwidgets + D3.js for interactive viewing.
  This is currently the only implemented renderer; the visual output is
  SVG, drawn by D3 inside the widget.

- **"svg"**, **"canvas"**, **"webgl"**, **"pdf"**: standalone static/
  large-data export backends. Planned, not yet implemented.

## Details

Key architectural difference from ggplot2: the spec is a pure data
structure. The
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
step resolves it into a concrete render tree. This means you can:

- Inspect the compiled spec as JSON (for debugging or export)

- Serialize it and render on a different machine

- Export it to Vega-Lite JSON (near 1:1 mapping)

- Add new backends later without changing the user-facing spec API
