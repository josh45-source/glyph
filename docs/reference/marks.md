# Visual Marks

Marks are the layers that draw data: points, lines, bars, areas, text,
rules, ribbons, links and polygons. Each `mark_*()` call adds one layer
to the spec.
[`mark_boxplot()`](https://josh45-source.github.io/glyph/reference/mark_boxplot.md),
[`mark_violin()`](https://josh45-source.github.io/glyph/reference/mark_violin.md),
[`mark_sina()`](https://josh45-source.github.io/glyph/reference/mark_sina.md)
and
[`mark_histogram()`](https://josh45-source.github.io/glyph/reference/mark_histogram.md)
summarise the distribution of a variable; their statistics are computed
from the data when the plot is compiled.

Mappings are passed as bare column names or expressions, and are added
to the global mappings set in
[`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md). A
mark can also take its own `data`, so one plot can draw from several
data frames. Fixed visual properties that don't depend on the data, such
as `size`, `opacity` or `stroke_width`, go in `style`. Interaction and
animation are set for the whole plot with
[`interact()`](https://josh45-source.github.io/glyph/reference/interact.md)
and
[`animate()`](https://josh45-source.github.io/glyph/reference/animate.md).
