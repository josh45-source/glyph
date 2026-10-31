# Getting Started with glyph

``` r

library(glyph)
```

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

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(tooltip = TRUE, hover = "enlarge") |>
  titles(title = "Motor Trend Cars")
```

Move the mouse over a point to enlarge it, and rest on it to see the
tooltip.

## 2. Animated bars

[`animate()`](https://josh45-source.github.io/glyph/reference/animate.html)
describes how marks enter the plot. With `stagger`, each bar starts a
little after the one before, so they draw in sequence.

``` r

glyph(mtcars, x = cyl, y = mpg) |>
  mark_bar() |>
  animate(transition = "slide", stagger = 50)
```

Reload the page, or run the chunk again in R, to watch the bars slide
in.

## 3. A dark theme

[`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.html)
sets the look of a plot from a few values. This example uses the
`"dark"` preset. You can also set single tokens such as `bg`, `font` or
`accent`. Text, grid and title colours are worked out from the
background so they stay readable.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(tooltip = TRUE) |>
  theme_tokens(preset = "dark") |>
  titles(title = "Dark Theme Example")
```

## 4. Labels that avoid each other

[`mark_text()`](https://josh45-source.github.io/glyph/reference/mark_text.html)
draws one label per row. With `smart_repel = TRUE`, labels that overlap
are nudged apart. `mtcars` keeps the car names in its row names, so the
first line copies them into a column.

``` r

mtcars_named <- data.frame(model = rownames(mtcars), mtcars, row.names = NULL)

glyph(mtcars_named, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  mark_text(label = model, smart_repel = TRUE)
```

## 5. Linked panels

[`compose()`](https://josh45-source.github.io/glyph/reference/compose.html)
places several plots in one widget. Both panels below allow brushing,
and `linked_selections = TRUE` connects them. Rows you select in one
panel are highlighted in the other.

``` r

p1 <- glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

p2 <- glyph(mtcars, x = hp, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

compose(p1, p2, type = "hstack", linked_selections = TRUE)
```

Drag a rectangle over a few points in either panel. The same cars light
up in both.

## 6. Small multiples

[`facet()`](https://josh45-source.github.io/glyph/reference/facet.html)
splits a plot into one panel per value of a variable. You can facet by
rows, by columns or by both.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  facet(cols = cyl)
```

With both, column labels go in a strip across the top and row labels in
a strip down the right side. A `labeller` changes what the strips say:
here a named vector for `cyl`, where 8 keeps its own label, and a
function for `gear`. The strips’ font size, weight and colours are theme
tokens.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  facet(rows = cyl, cols = gear, labeller = list(
    cyl = c("4" = "4 cylinders", "6" = "6 cylinders"),
    gear = function(x) paste(x, "gears")
  )) |>
  theme_tokens(strip_size = 12, strip_bg = "#e8eef8")
```

## 7. Marginal distributions

[`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.html)
draws the distribution of each axis along its edge. The choices are
`"histogram"`, `"density"` and `"boxplot"`.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  marginals(x = "histogram", y = "density")
```

## 8. Inset plots

[`inset()`](https://josh45-source.github.io/glyph/reference/inset.html)
puts a smaller plot inside a corner of the main one. It works well for a
detail view or a second breakdown of the same data.

``` r

main_plot <- glyph(mtcars, x = wt, y = mpg) |> mark_point(color = cyl)
detail_plot <- glyph(mtcars, x = cyl, y = mpg) |> mark_bar()

inset(main_plot, detail_plot, position = "top-right")
```

## 9. Moving between groups

`animate(by = ..., transition = "morph")` shows one group of the data at
a time. When the group changes, each mark moves to its new position.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(size = hp, color = cyl) |>
  animate(by = gear, transition = "morph", duration = 800)
```

Use the play/pause button to step through the `gear` groups.

## 10. Boxplots

[`mark_boxplot()`](https://josh45-source.github.io/glyph/reference/mark_boxplot.html)
summarises a numeric variable for each group. The box runs from the
first to the third quartile and the line across it is the median. Values
beyond the whiskers are drawn as separate points.

``` r

glyph(mtcars, x = factor(cyl), y = mpg) |>
  mark_boxplot() |>
  interact(tooltip = TRUE, hover = "outline")
```

Rest the pointer on a box to read its quartiles.

## 11. Violins

[`mark_violin()`](https://josh45-source.github.io/glyph/reference/mark_violin.html)
draws each group’s distribution as a mirrored density curve. Every
violin uses the same density scale, so a wide section means many cars
with similar values.

``` r

glyph(mtcars, x = factor(gear), y = mpg) |>
  mark_violin(color = factor(gear)) |>
  interact(tooltip = TRUE)
```

## 12. Sina points

[`mark_sina()`](https://josh45-source.github.io/glyph/reference/mark_sina.html)
draws one point per row and spreads the points sideways by how common
their value is. They fill the same outline a violin would, but each
point is still a car, so you can brush across them.

``` r

glyph(mtcars, x = factor(cyl), y = mpg) |>
  mark_violin(style = list(opacity = 0.2)) |>
  mark_sina() |>
  interact(tooltip = TRUE, brush = TRUE)
```

Drag across a group to select the cars in it.

## 13. Histograms

[`mark_histogram()`](https://josh45-source.github.io/glyph/reference/mark_histogram.html)
counts the rows that fall in each bin of a numeric variable. Mapping
colour stacks the counts for each group within a bin.

``` r

glyph(mtcars, x = mpg) |>
  mark_histogram(binwidth = 2.5, color = factor(am)) |>
  interact(tooltip = TRUE)
```

## 14. Polygons

[`mark_polygon()`](https://josh45-source.github.io/glyph/reference/mark_polygon.html)
draws closed shapes from x/y vertices, one shape per value of `group`.
Here each shape is the convex hull of a cylinder group, found with
[`chull()`](https://rdrr.io/r/grDevices/chull.html), and drawn under the
cars it encloses.

``` r

hulls <- do.call(rbind, lapply(split(mtcars, mtcars$cyl), function(d) {
  d[chull(d$wt, d$mpg), ]
}))

glyph(mtcars, x = wt, y = mpg) |>
  mark_polygon(data = hulls, group = factor(cyl), color = factor(cyl),
               style = list(opacity = 0.2)) |>
  mark_point(color = factor(cyl)) |>
  interact(tooltip = TRUE)
```

## Where to next

The [function
reference](https://josh45-source.github.io/glyph/reference/index.html)
covers every mark, scale and layout function in more detail.
