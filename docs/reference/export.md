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
  `.html` (interactive widget) and `.json` (the compiled spec). Other
  extensions (`.svg`, `.png`, `.pdf`) are planned but not yet
  implemented, and currently just print a message.

- width:

  Width in pixels

- height:

  Height in pixels

## Value

Invisibly returns the output file path

## Details

A single self-contained `.html` file needs [pandoc](https://pandoc.org).
RStudio ships with pandoc, so this works out of the box there;
elsewhere, install pandoc and make sure it is on your `PATH`. Without
pandoc, `export()` still writes the `.html` file but puts the JavaScript
it needs in a `<name>_files` folder next to it, and tells you so. Keep
the two together when moving or sharing the plot.
