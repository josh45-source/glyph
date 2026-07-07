# Add a line mark

Add a line mark

## Usage

``` r
mark_line(spec, ..., data = NULL, style = list(), interpolate = "monotone")
```

## Arguments

- spec:

  A glyph_spec

- ...:

  Aesthetic mappings (x, y, color, size, shape, alpha, tooltip)

- data:

  Optional per-mark data override

- style:

  Named list of fixed visual properties

- interpolate:

  Interpolation method: "linear", "monotone", "step", "basis"

## Value

Modified `glyph_spec` object with the line mark added
