# Add a selection parameter (advanced)

For complex interactions: define a named selection that can be
referenced by marks and scales. This is how you build linked views,
conditional encoding, and interactive legends.

## Usage

``` r
selection(
  spec,
  name,
  type = "point",
  on = "click",
  fields = NULL,
  resolve = "global"
)
```

## Arguments

- spec:

  A glyph_spec

- name:

  Selection name (referenced in conditional encodings)

- type:

  "point", "interval", or "legend"

- on:

  Event trigger: "click", "mouseover", "drag"

- fields:

  Which data fields the selection projects onto

- resolve:

  For composed views: "global", "union", "intersect"

## Value

Modified glyph_spec

## Examples

``` r
# Interactive legend: click legend entries to filter
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  selection("legend_filter", type = "legend", fields = "cyl")
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
