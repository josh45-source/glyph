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

  Automatically avoid label overlaps (TRUE by default). Inspired by
  ggrepel, but simpler: rather than a full force-directed simulation,
  glyph resolves overlaps by iterative pairwise nudging — repeatedly
  comparing every pair of label bounding boxes and, for any pair that
  still overlaps, pushing them a small step apart vertically (up to 50
  passes, stopping as soon as none overlap). This is a first-class
  feature, not an extension package.

## Value

Modified `glyph_spec` object with the text mark added
