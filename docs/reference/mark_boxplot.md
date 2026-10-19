# Add a boxplot mark

Draws one box per group: the box spans the first to third quartile, the
line inside it is the median, and the whiskers reach the most extreme
values within `coef` times the interquartile range of the box. Values
beyond the whiskers are drawn as outlier points.

Map `y` to the numeric variable and `x` to the grouping variable, which
is treated as categorical even when it is numeric. Without `x`, all rows
form one box. Mapping `color` to a different variable than `x` places
one box per colour side by side within each x group.

The statistics are computed in R when the plot is compiled, using
[`stats::quantile()`](https://rdrr.io/r/stats/quantile.html) with its
default `type = 7`. Rows with a missing `x` or `y` are dropped first,
with a warning.

## Usage

``` r
mark_boxplot(
  spec,
  ...,
  data = NULL,
  style = list(),
  coef = 1.5,
  outliers = TRUE,
  width = 0.7
)
```

## Arguments

- spec:

  A glyph_spec

- ...:

  Aesthetic mappings: `y` (required, numeric), `x` and `color`.

- data:

  Optional per-mark data override

- style:

  Named list of fixed visual properties

- coef:

  Length of the whiskers as a multiple of the interquartile range. Use
  `Inf` to extend them to the minimum and maximum.

- outliers:

  Whether to draw values beyond the whiskers as points.

- width:

  Width of each box as a fraction of the space for its group, between 0
  and 1.

## Value

Modified `glyph_spec` object with the boxplot mark added

## Examples

``` r
glyph(mtcars, x = factor(cyl), y = mpg) |>
  mark_boxplot()
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
