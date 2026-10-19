# Scales

Scales map data values to visual properties. Every scale is set with one
function, `scale(<aesthetic>, <type>, ...)`, where the aesthetic is the
channel (such as `"x"` or `"color"`) and the type is how values are
mapped (such as `"log"` or `"time"`). `scale_color()`, `scale_log()` and
`scale_time()` are shortcuts for common cases.

## Usage

``` r
scale_color(spec, palette = "Tableau10", ...)

scale_log(spec, aesthetic = "y", base = 10, ...)

scale_time(spec, aesthetic = "x", ...)
```

## Arguments

- spec:

  A glyph_spec

- palette:

  A named palette: "viridis", "Set2", "Tableau10", "Blues", etc.

- ...:

  Additional arguments passed to
  [`scale()`](https://josh45-source.github.io/glyph/reference/scale.md)

- aesthetic:

  Which channel: "x", "y", "color", "size", "shape", "alpha"

- base:

  Log base (default 10)

## Value

Modified `glyph_spec` object

Modified `glyph_spec` object

Modified `glyph_spec` object

## Functions

- `scale_color()`: Set color palette by name

- `scale_log()`: Log-transform an axis

- `scale_time()`: Time/date axis
