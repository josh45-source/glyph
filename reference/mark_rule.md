# Add a rule (reference line) mark

Add a rule (reference line) mark

## Usage

``` r
mark_rule(
  spec,
  ...,
  data = NULL,
  style = list(),
  x_intercept = NULL,
  y_intercept = NULL
)
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

- x_intercept:

  Fixed x position for vertical rule

- y_intercept:

  Fixed y position for horizontal rule

## Value

Modified `glyph_spec` object with the rule mark added
