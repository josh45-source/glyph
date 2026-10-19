# Add a violin mark

Draws the distribution of a numeric variable for each group as a
mirrored kernel density curve, trimmed to the range of the group's
values. All violins in the mark use the same density scale, so their
widths can be compared directly.

Map `y` to the numeric variable and `x` to the grouping variable, which
is treated as categorical even when it is numeric. Without `x`, all rows
form one violin. Mapping `color` to a different variable than `x` places
one violin per colour side by side within each x group.

The densities are computed in R when the plot is compiled, with
[`stats::density()`](https://rdrr.io/r/stats/density.html). A group
needs at least two distinct values; groups with fewer are left out with
a warning.

## Usage

``` r
mark_violin(
  spec,
  ...,
  data = NULL,
  style = list(),
  bw = "nrd0",
  adjust = 1,
  width = 0.9
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

- bw:

  Smoothing bandwidth, passed to
  [`stats::density()`](https://rdrr.io/r/stats/density.html): a number
  or the name of a bandwidth rule such as `"nrd0"` (the default) or
  `"SJ"`.

- adjust:

  Multiplier for the bandwidth. Values above 1 give smoother curves.

- width:

  Width of the widest violin as a fraction of the space for its group,
  between 0 and 1.

## Value

Modified `glyph_spec` object with the violin mark added

## Examples

``` r
glyph(mtcars, x = factor(cyl), y = mpg) |>
  mark_violin()
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
