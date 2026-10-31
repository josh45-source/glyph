# Set theme tokens

Set theme tokens

## Usage

``` r
theme_tokens(
  spec,
  preset = NULL,
  font = NULL,
  font_size = NULL,
  bg = NULL,
  fg = NULL,
  accent = NULL,
  grid = NULL,
  border = NULL,
  padding = NULL,
  title_size = NULL,
  strip_size = NULL,
  strip_weight = NULL,
  strip_fg = NULL,
  strip_bg = NULL
)
```

## Arguments

- spec:

  A glyph_spec

- preset:

  A named preset: "light" (default), "dark", "minimal", "publication",
  "presentation". Presets set all tokens to coherent defaults.

- font:

  Font family for all text

- font_size:

  Base font size in px (axis labels scale relative to this)

- bg:

  Background color

- fg:

  Primary text/axis color

- accent:

  Primary accent color (used for single-series marks)

- grid:

  Grid line visibility: TRUE, FALSE, "x", "y"

- border:

  Plot border: TRUE/FALSE

- padding:

  Padding around the plot area in px

- title_size:

  Title font size multiplier (relative to font_size)

- strip_size:

  Font size of facet strip labels in px. Follows `font_size` (at 0.9 of
  it) unless set.

- strip_weight:

  Font weight of facet strip labels: "normal", "bold", or a number from
  100 to 900.

- strip_fg:

  Text colour of facet strip labels. Follows `fg` unless set.

- strip_bg:

  Background colour of facet strips, or "transparent". Follows `bg` (a
  shade towards `fg`) unless set.

## Value

Modified glyph_spec

## Examples

``` r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  theme_tokens(preset = "dark")
#> <glyph_spec: 32 x 11, 1 mark(s)>

glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  theme_tokens(font = "IBM Plex Sans", bg = "#fafafa", grid = "y")
#> <glyph_spec: 32 x 11, 1 mark(s)>

# Facet strips: larger, normal-weight labels on a pale blue strip.
glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  facet(rows = cyl, cols = gear) |>
  theme_tokens(strip_size = 13, strip_weight = "normal", strip_bg = "#e8eef8")
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
