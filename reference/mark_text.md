# Add a text/label mark

Add a text/label mark

## Usage

``` r
mark_text(spec, ..., data = NULL, style = list(), smart_repel = TRUE)
```

## Arguments

- spec:

  A glyph_spec

- ...:

  Aesthetic mappings (x, y, color, size, shape, alpha, tooltip)

- data:

  Optional per-mark data override

- style:

  Named list of fixed visual properties

- smart_repel:

  Automatically avoid label overlaps (TRUE by default). This is a
  first-class feature, not an extension package.

## Value

Modified `glyph_spec` object with the text mark added
