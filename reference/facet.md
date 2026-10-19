# Facet a plot by one or two variables

Splits a plot into small multiples, one panel for each value of `rows`,
`cols`, or both. Panels share their axes unless `free_scales` lets them
vary. With a single faceting variable, `wrap` sets how many panels go in
each row.

## Usage

``` r
facet(spec, rows = NULL, cols = NULL, free_scales = "none", wrap = NULL)
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

## Value

Modified glyph_spec
