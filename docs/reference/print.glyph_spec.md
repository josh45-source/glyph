# Draw a glyph spec when it is printed

A printed spec draws itself. At the console it opens in the viewer, and
in R Markdown, Quarto and vignettes it is embedded in the document. Call
[`render()`](https://josh45-source.github.io/glyph/reference/render.md)
only to set the width and height, and use
[summary()](https://josh45-source.github.io/glyph/reference/summary.glyph_spec.md)
for a text description.

In a non-interactive session that isn't knitting a document, such as
`Rscript`, there is nowhere to draw, so printing gives a one-line
description instead.

## Usage

``` r
# S3 method for class 'glyph_spec'
print(x, ...)

# S3 method for class 'glyph_spec'
knit_print(x, ..., options = NULL)
```

## Arguments

- x:

  A glyph_spec object

- ...:

  Passed on to knitr when knitting; otherwise ignored.

- options:

  knitr chunk options, supplied by knitr.

## Value

[`print()`](https://rdrr.io/r/base/print.html) invisibly returns `x`.
`knit_print()` returns the rendered widget's HTML for knitr to include
in the document.
