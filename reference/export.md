# Export to various formats

Export to various formats

## Usage

``` r
export(spec, file, width = 800, height = 600)
```

## Arguments

- spec:

  A glyph_spec or glyph_compiled

- file:

  Output file path. Extension determines format: .html, .svg, .png,
  .pdf, .json (exports the raw spec)

- width:

  Width in pixels

- height:

  Height in pixels

## Value

Invisibly returns the output file path
