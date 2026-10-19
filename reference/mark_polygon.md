# Add a polygon mark

Draws closed shapes from `x`/`y` vertices. Rows that share a value of
`group` are the vertices of one polygon, joined in row order, and the
last vertex is joined back to the first. Without a `group` mapping, all
rows form one polygon. Mapping `color` fills each polygon by its value;
a polygon whose rows have different colours is split into one polygon
per colour.

Each polygon is one element: its tooltip shows the polygon rather than a
single vertex, and brushing or clicking it selects all of its rows. A
tooltip template can use any column that has the same value on every row
of the polygon, such as a name or an id. Rows with a missing `x` or `y`
are dropped first, with a warning, and polygons left with fewer than
three vertices are not drawn.

## Usage

``` r
mark_polygon(spec, ..., data = NULL, style = list(), radius = 0)
```

## Arguments

- spec:

  A glyph_spec

- ...:

  Aesthetic mappings: `x` and `y` (required, numeric), `group` and
  `color`.

- data:

  Optional per-mark data override

- style:

  Named list of fixed visual properties: `fill` (a colour used when
  `color` isn't mapped), `stroke` (outline colour, the theme's
  foreground colour by default), `stroke_width` (in pixels, 0 for no
  outline) and `opacity` (of the fill).

- radius:

  Radius of rounded corners, in pixels. Each corner is rounded by at
  most half the length of its shorter edge. 0 (the default) keeps sharp
  corners.

## Value

Modified `glyph_spec` object with the polygon mark added

## Examples

``` r
triangles <- data.frame(
  id = rep(c("a", "b"), each = 3),
  x = c(0, 1, 0.5, 1.5, 2.5, 2),
  y = c(0, 0, 1, 0, 0, 1)
)
glyph(triangles, x = x, y = y) |>
  mark_polygon(group = id, color = id)
#> <glyph_spec: 6 x 3, 1 mark(s)>
```
