# Facet a plot by one or two variables

Splits a plot into small multiples, one panel for each value of `rows`,
`cols`, or both. Panels share their axes unless `free_scales` lets them
vary.

With both `rows` and `cols`, panels form a grid, as in ggplot2's
`facet_grid()`: column labels go in a strip across the top and row
labels in a strip down the right side. With `rows` alone, panels stack
in one column with their labels on the right. With `cols` alone, or with
`wrap`, panels wrap into rows with each label in a strip on top.

Shared axes are drawn once, on the outer panels: the y axis on the left
column and the x axis on the bottom row. A strip shows the value alone,
such as "4", unless `labeller` gives another label. Strip font size,
weight and colours are theme tokens (see
[`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)).

## Usage

``` r
facet(
  spec,
  rows = NULL,
  cols = NULL,
  free_scales = "none",
  wrap = NULL,
  labeller = NULL
)
```

## Arguments

- spec:

  A glyph_spec

- rows:

  Row faceting variable: a bare column name, a computed expression (e.g.
  `factor(cyl)`), or `NULL`

- cols:

  Column faceting variable: a bare column name, a computed expression,
  or `NULL`

- free_scales:

  "none", "x", "y", "both"

- wrap:

  If only one variable, wrap into a grid with this many columns

- labeller:

  The labels shown in the strips, similar to `ggplot2::labeller()`. One
  of:

  - a named character vector, such as `c("4" = "Four cylinders")`, which
    looks up each value by its name. Values not in the vector keep their
    own label.

  - a function that takes the values as a character vector and returns
    their labels, one for each.

  - a list with one of the above per faceting variable, named as the
    variable is written in `rows` or `cols`, such as
    `list(cyl = c("4" = "Four"), gear = function(x) paste(x, "gears"))`.
    Variables not in the list keep their own labels.

## Value

Modified glyph_spec

## Examples

``` r
p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()

# Columns by gear in a strip on top, rows by cyl in a strip on the right.
p |> facet(rows = cyl, cols = gear)
#> <glyph_spec: 32 x 11, 1 mark(s)>

# One variable: panels wrap, with labels on top.
p |> facet(cols = cyl, wrap = 3)
#> <glyph_spec: 32 x 11, 1 mark(s)>

# Relabel some values with a named vector. 8 keeps its own label.
p |> facet(cols = cyl, labeller = c("4" = "Four cylinders", "6" = "Six cylinders"))
#> <glyph_spec: 32 x 11, 1 mark(s)>

# A labeller per variable: a lookup for cyl, a function for gear.
p |> facet(rows = cyl, cols = gear, labeller = list(
  cyl = c("4" = "Four", "6" = "Six", "8" = "Eight"),
  gear = function(x) paste(x, "gears")
))
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
