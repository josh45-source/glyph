# Compose multiple glyph specs into a layout

Compose multiple glyph specs into a layout

## Usage

``` r
compose(
  ...,
  type = "hstack",
  widths = NULL,
  heights = NULL,
  gap = 10,
  shared_scales = FALSE,
  linked_selections = FALSE,
  title = NULL
)
```

## Arguments

- ...:

  glyph_spec objects or layout objects (for nesting)

- type:

  Layout type: "hstack", "vstack", "grid", "wrap"

- widths:

  Relative widths for columns (e.g. c(2, 1) for 2:1 split)

- heights:

  Relative heights for rows

- gap:

  Gap between plots in px

- shared_scales:

  Share axis scales across plots: TRUE, FALSE, "x", "y", or "both"

- linked_selections:

  Share interaction selections across plots

- title:

  Overall layout title

## Value

A `glyph_layout` object

## Examples

``` r
p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
p2 <- glyph(mtcars, x = wt, y = hp) |> mark_point()
p3 <- glyph(mtcars, x = hp, y = mpg) |> mark_line()

# Horizontal stack
compose(p1, p2, type = "hstack")
#> 
#> ── Glyph Layout ────────────────────────────────────────────────────────────────
#> • Type: hstack
#> • Panels: 2
#> • Linked selections: FALSE

# Grid with linked brushing
compose(p1, p2, p3, type = "wrap",
        linked_selections = TRUE, shared_scales = "x")
#> 
#> ── Glyph Layout ────────────────────────────────────────────────────────────────
#> • Type: wrap
#> • Panels: 3
#> • Linked selections: TRUE
```
