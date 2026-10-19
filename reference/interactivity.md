# Interactivity

Tooltips, hover effects, clicks, zoom, brushing and linked selections
are part of the plot specification. They are declared with
[`interact()`](https://josh45-source.github.io/glyph/reference/interact.md)
and
[`selection()`](https://josh45-source.github.io/glyph/reference/selection.md)
in the same pipeline as the marks, stored in the spec, and run in the
browser by the D3 renderer.

## Details

Design philosophy: interactions are *selections* that filter or
highlight marks. This follows Vega-Lite's insight that most interactions
are really about defining subsets of the data. A tooltip is "select the
nearest point, show its values." Brushing is "select points in a
rectangle, highlight them."
