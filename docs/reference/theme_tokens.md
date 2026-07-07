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
  title_size = NULL
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
```
