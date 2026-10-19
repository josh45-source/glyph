# Add a histogram mark

Counts how many rows fall into each bin of a numeric `x` variable and
draws one bar per bin. Bins are closed on the right, like
[`graphics::hist()`](https://rdrr.io/r/graphics/hist.html), and the
lowest bin also includes its left edge. Mapping `color` stacks one bar
segment per colour within each bin.

With neither `bins` nor `binwidth`, the number of bins follows Sturges'
rule and the edges are rounded to tidy values, as in
[`graphics::hist()`](https://rdrr.io/r/graphics/hist.html). All facet
panels share the same bins.

The counts are computed in R when the plot is compiled. Rows with a
missing `x` are dropped first, with a warning.

## Usage

``` r
mark_histogram(
  spec,
  ...,
  data = NULL,
  style = list(),
  bins = NULL,
  binwidth = NULL
)
```

## Arguments

- spec:

  A glyph_spec

- ...:

  Aesthetic mappings: `x` (required, numeric) and `color`. There is no
  `y` mapping; the bar heights are the counts.

- data:

  Optional per-mark data override

- style:

  Named list of fixed visual properties

- bins:

  Number of equal-width bins spanning the range of `x`.

- binwidth:

  Width of each bin. Bin edges are multiples of `binwidth`. Takes
  precedence over `bins`.

## Value

Modified `glyph_spec` object with the histogram mark added

## Examples

``` r
glyph(mtcars, x = mpg) |>
  mark_histogram(binwidth = 2.5)
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
