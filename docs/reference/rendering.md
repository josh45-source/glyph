# Rendering Pipeline

The rendering pipeline compiles a glyph_spec into output. The spec is
first resolved (evaluate quosures, compute stats, merge defaults), then
serialized to JSON, then handed to a backend:

- **"html"** (default): htmlwidgets + D3.js for interactive viewing

- **"svg"**: Static SVG file (publication quality)

- **"canvas"**: HTML5 Canvas for large-data performance

- **"webgl"**: WebGL via regl/deck.gl for 100K+ points (planned)

- **"pdf"**: Direct PDF output via R's pdf() device (planned)

## Details

Key architectural difference from ggplot2: the spec is a pure data
structure. The
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
step resolves it into a concrete render tree. This means you can:

- Inspect the compiled spec as JSON (for debugging or export)

- Serialize it and render on a different machine

- Export it to Vega-Lite JSON (near 1:1 mapping)

- Compile to multiple backends from one spec
