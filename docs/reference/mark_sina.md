# Add a sina mark

Draws every row as a point, spread sideways within its group in
proportion to the density of values at that height. The points fill the
same outline a
[`mark_violin()`](https://josh45-source.github.io/glyph/reference/mark_violin.md)
with the same settings would draw, so the two combine well.

Each point is still a row of the data, so tooltips, brushing and linked
selections work on individual rows, as they do for
[`mark_point()`](https://josh45-source.github.io/glyph/reference/mark_point.md).
The sideways positions are computed in R when the plot is compiled and
are the same every time.

## Usage

``` r
mark_sina(
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

  Aesthetic mappings: `y` (required, numeric), `x`, `color` and `size`.

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

  Width of the spread at the highest density, as a fraction of the space
  for its group, between 0 and 1.

## Value

Modified `glyph_spec` object with the sina mark added

## Examples

``` r
glyph(mtcars, x = factor(cyl), y = mpg) |>
  mark_violin() |>
  mark_sina()
#> <glyph_spec: 32 x 11, 2 mark(s)>
```
