# Draw a glyph spec when it is printed

In an interactive session, printing a spec renders it as an htmlwidget,
so a plot appears without calling
[`render()`](https://josh45-source.github.io/glyph/reference/render.md).
In a non-interactive session, including R Markdown, Quarto and
vignettes, it prints a one-line summary instead; end the pipeline with
[`render()`](https://josh45-source.github.io/glyph/reference/render.md)
there.

## Usage

``` r
# S3 method for class 'glyph_spec'
print(x, ...)
```

## Arguments

- x:

  A glyph_spec object

- ...:

  Additional arguments (ignored)

## Value

Invisibly returns the glyph_spec object
