# Getting Started with glyph

\
[`library`](https://rdrr.io/r/base/library.html)`(`[`glyph`](https://github.com/josh45-source/glyph)`)`\
`#> `\
`#> Attaching package: 'glyph'`\
`#> The following object is masked from 'package:base':`\
`#> `\
`#>     scale`

Every plot on this page is built by the code above it and drawn by
glyph’s D3 renderer. They are live, so you can hover, click, brush and
zoom them. All the examples use `mtcars`, which means you can paste them
into R and get the same result.

## 1. Tooltips and hover

[`interact()`](https://josh45-source.github.io/glyph/reference/interact.html)
adds behaviour to the plot. Here it turns on tooltips and makes a point
grow when the mouse is over it.
[`titles()`](https://josh45-source.github.io/glyph/reference/titles.html)
adds a title in the same pipeline.

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`interact`](https://josh45-source.github.io/glyph/reference/interact.md)`(``tooltip ``=`` ``TRUE``, hover ``=`` ``"enlarge"``)`` ``|>`\
`  `[`titles`](https://josh45-source.github.io/glyph/reference/titles.md)`(``title ``=`` ``"Motor Trend Cars"``)`

Move the mouse over a point to enlarge it, and rest on it to see the
tooltip.

## 2. Animated bars

[`animate()`](https://josh45-source.github.io/glyph/reference/animate.html)
describes how marks enter the plot. With `stagger`, each bar starts a
little after the one before, so they draw in sequence.

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``cyl``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_bar`](https://josh45-source.github.io/glyph/reference/mark_bar.md)`(``)`` ``|>`\
`  `[`animate`](https://josh45-source.github.io/glyph/reference/animate.md)`(``transition ``=`` ``"slide"``, stagger ``=`` ``50``)`

Reload the page, or run the chunk again in R, to watch the bars slide
in.

## 3. A dark theme

[`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.html)
sets the look of a plot from a few values. This example uses the
`"dark"` preset. You can also set single tokens such as `bg`, `font` or
`accent`. Text, grid and title colours are worked out from the
background so they stay readable.

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`interact`](https://josh45-source.github.io/glyph/reference/interact.md)`(``tooltip ``=`` ``TRUE``)`` ``|>`\
`  `[`theme_tokens`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)`(``preset ``=`` ``"dark"``)`` ``|>`\
`  `[`titles`](https://josh45-source.github.io/glyph/reference/titles.md)`(``title ``=`` ``"Dark Theme Example"``)`

## 4. Labels that avoid each other

[`mark_text()`](https://josh45-source.github.io/glyph/reference/mark_text.html)
draws one label per row. With `smart_repel = TRUE`, labels that overlap
are nudged apart. `mtcars` keeps the car names in its row names, so the
first line copies them into a column.

\
`mtcars_named`` ``<-`` `[`data.frame`](https://rdrr.io/r/base/data.frame.html)`(``model ``=`` `[`rownames`](https://rdrr.io/r/base/colnames.html)`(``mtcars``)``, ``mtcars``, row.names ``=`` ``NULL``)`\
\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars_named``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`mark_text`](https://josh45-source.github.io/glyph/reference/mark_text.md)`(``label ``=`` ``model``, smart_repel ``=`` ``TRUE``)`

## 5. Linked panels

[`compose()`](https://josh45-source.github.io/glyph/reference/compose.html)
places several plots in one widget. Both panels below allow brushing,
and `linked_selections = TRUE` connects them. Rows you select in one
panel are highlighted in the other.

\
`p1`` ``<-`` `[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`interact`](https://josh45-source.github.io/glyph/reference/interact.md)`(``brush ``=`` ``TRUE``)`\
\
`p2`` ``<-`` `[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``hp``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`interact`](https://josh45-source.github.io/glyph/reference/interact.md)`(``brush ``=`` ``TRUE``)`\
\
[`compose`](https://josh45-source.github.io/glyph/reference/compose.md)`(``p1``, ``p2``, type ``=`` ``"hstack"``, linked_selections ``=`` ``TRUE``)`

Drag a rectangle over a few points in either panel. The same cars light
up in both.

## 6. Small multiples

[`facet()`](https://josh45-source.github.io/glyph/reference/facet.html)
splits a plot into one panel per value of a variable. You can facet by
rows, by columns or by both.

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`facet`](https://josh45-source.github.io/glyph/reference/facet.md)`(``cols ``=`` ``cyl``)`

## 7. Marginal distributions

[`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.html)
draws the distribution of each axis along its edge. The choices are
`"histogram"`, `"density"` and `"boxplot"`.

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`` ``|>`\
`  `[`marginals`](https://josh45-source.github.io/glyph/reference/marginals.md)`(``x ``=`` ``"histogram"``, y ``=`` ``"density"``)`

## 8. Inset plots

[`inset()`](https://josh45-source.github.io/glyph/reference/inset.html)
puts a smaller plot inside a corner of the main one. It works well for a
detail view or a second breakdown of the same data.

\
`main_plot`` ``<-`` `[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`` `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`\
`detail_plot`` ``<-`` `[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``cyl``, y ``=`` ``mpg``)`` ``|>`` `[`mark_bar`](https://josh45-source.github.io/glyph/reference/mark_bar.md)`(``)`\
\
[`inset`](https://josh45-source.github.io/glyph/reference/inset.md)`(``main_plot``, ``detail_plot``, position ``=`` ``"top-right"``)`

## 9. Moving between groups

`animate(by = ..., transition = "morph")` shows one group of the data at
a time. When the group changes, each mark moves to its new position.

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``size ``=`` ``hp``, color ``=`` ``cyl``)`` ``|>`\
`  `[`animate`](https://josh45-source.github.io/glyph/reference/animate.md)`(``by ``=`` ``gear``, transition ``=`` ``"morph"``, duration ``=`` ``800``)`

Use the play/pause button to step through the `gear` groups.

## Where to next

The [function
reference](https://josh45-source.github.io/glyph/reference/index.html)
covers every mark, scale and layout function in more detail.
