# Export the spec as Vega-Lite JSON (interop)

Because glyph's spec is structurally similar to Vega-Lite, we can export
to Vega-Lite JSON for use in Python (Altair), JavaScript, or the Vega
Editor.

## Usage

``` r
to_vegalite(spec)
```

## Arguments

- spec:

  A glyph_spec

## Value

A JSON string in Vega-Lite format
