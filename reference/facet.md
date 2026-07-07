# Facet a plot by one or two variables

Like ggplot2's facet_wrap/facet_grid but with a key improvement: each
facet can have independent geom parameters and scales by default
(instead of forced uniformity).

## Usage

``` r
facet(spec, rows = NULL, cols = NULL, free_scales = "none", wrap = NULL)
```

## Arguments

- spec:

  A glyph_spec

- rows:

  Row faceting variable (bare name or NULL)

- cols:

  Column faceting variable (bare name or NULL)

- free_scales:

  "none", "x", "y", "both"

- wrap:

  If only one variable, wrap into a grid with this many columns

## Value

Modified glyph_spec
