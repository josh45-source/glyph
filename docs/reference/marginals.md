# Add a marginal plot (histogram/density on axes)

Adds marginal distributions to a plot's axes — a common pattern that
requires ggExtra or manual grid manipulation in ggplot2.

## Usage

``` r
marginals(spec, x = "histogram", y = "histogram", size = 0.15)
```

## Arguments

- spec:

  A glyph_spec

- x:

  Marginal type for x-axis: "histogram", "density", "boxplot", NULL

- y:

  Marginal type for y-axis: "histogram", "density", "boxplot", NULL

- size:

  Proportion of plot area for marginals (0.0 to 0.4)

## Value

Modified glyph_spec

## Examples

``` r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  marginals(x = "histogram", y = "density")
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
