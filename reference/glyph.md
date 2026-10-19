# Create a Glyph Visualization

Entry point for the glyph grammar. Creates a specification that
describes a visualization declaratively. The spec is a plain nested
list: it can be inspected, serialized to JSON, and compiled into an
interactive HTML widget.

## Usage

``` r
glyph(data = NULL, ...)
```

## Arguments

- data:

  A data frame or tibble, or `NULL` if each mark will supply its own
  data.

- ...:

  Global aesthetic mappings, written as bare column names or
  expressions, e.g. `glyph(mtcars, x = wt, y = mpg)`. Every mark uses
  these unless it sets its own.

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
