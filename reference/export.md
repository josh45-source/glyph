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

  Output file path. Extension determines format. Currently implemented:
  `.html` (self-contained interactive widget) and `.json` (the compiled
  spec). Other extensions (`.svg`, `.png`, `.pdf`) are planned but not
  yet implemented, and currently just print a message.

- width:

  Width in pixels

- height:

  Height in pixels

## Value

Invisibly returns the output file path
