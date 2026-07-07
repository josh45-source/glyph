# Create a Glyph Visualization

Entry point for the glyph grammar. Creates a specification object that
describes a visualization declaratively. Unlike ggplot2, the spec is a
pure data structure (nested list) that can be serialized, inspected, and
compiled to multiple backends.

## Usage

``` r
glyph(data = NULL, ...)
```

## Arguments

- data:

  A data.frame or tibble. Unlike ggplot2, glyph also accepts
  lists-of-lists, URLs to CSV/JSON, or arrow tables (planned).

- ...:

  Global aesthetic mappings using bare column names (no aes() needed).
  e.g. glyph(mtcars, x = wt, y = mpg)

## Value

A `glyph_spec` object

## Examples

``` r
spec <- glyph(mtcars, x = wt, y = mpg) |>
  mark_point()
summary(spec)
#> 
#> ── Glyph Specification ─────────────────────────────────────────────────────────
#> • Data: 32 x 11
#> • Marks: 1
#> • Interactions: 0
#> • Animated: FALSE
```
