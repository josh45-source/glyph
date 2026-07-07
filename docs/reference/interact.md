# Add interactive behaviors to a glyph spec

Add interactive behaviors to a glyph spec

## Usage

``` r
interact(
  spec,
  tooltip = FALSE,
  zoom = FALSE,
  brush = FALSE,
  hover = NULL,
  click = NULL,
  crossfilter = FALSE,
  nearest = FALSE
)
```

## Arguments

- spec:

  A glyph_spec

- tooltip:

  Show values on hover. TRUE for auto-generated, or a glue-style
  template string like "{x}: {y} ({color})".

- zoom:

  Enable scroll-to-zoom and pan

- brush:

  Enable rectangular brush selection

- hover:

  Highlight mark on hover ("enlarge", "brighten", "outline", or NULL)

- click:

  Action on click: "select", "filter", "url", or a callback name

- crossfilter:

  Link this plot's selections to other plots in a layout

- nearest:

  Snap selection to nearest point (useful for line charts)

## Value

Modified glyph_spec

## Examples

``` r
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(
    tooltip = "{cyl} cylinders\n{mpg} mpg at {wt} tons",
    zoom = TRUE,
    hover = "enlarge",
    brush = TRUE,
    crossfilter = TRUE
  )
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
