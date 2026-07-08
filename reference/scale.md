# Define a scale for an aesthetic channel

Define a scale for an aesthetic channel

## Usage

``` r
scale(
  spec,
  aesthetic,
  type = "auto",
  domain = NULL,
  range = NULL,
  nice = TRUE,
  zero = FALSE,
  reverse = FALSE,
  label = NULL,
  format = NULL,
  base = NULL
)
```

## Arguments

- spec:

  A glyph_spec

- aesthetic:

  Which channel: "x", "y", "color", "size", "shape", "alpha"

- type:

  Scale type: "linear", "log", "sqrt", "time", "ordinal", "band",
  "quantize", "threshold"

- domain:

  Explicit domain (data range). NULL for auto.

- range:

  Explicit output range. For color: a palette name or vector.

- nice:

  Round domain to nice values (TRUE/FALSE)

- zero:

  Force zero in domain (TRUE/FALSE)

- reverse:

  Reverse the scale

- label:

  Axis/legend label (NULL for auto from column name)

- format:

  Format string for tick labels (e.g. "\$.2f", "%b %Y")

- base:

  Log base, used when `type = "log"` (default 10 if NULL)

## Value

Modified glyph_spec

## Examples

``` r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  scale("y", "linear", zero = TRUE, label = "Miles per gallon") |>
  scale("color", "ordinal", range = "Set2")
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
