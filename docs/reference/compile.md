# Compile a glyph spec to a resolved representation

Compile a glyph spec to a resolved representation

## Usage

``` r
compile(spec, engine = "auto", width = NULL, height = NULL)

# S3 method for class 'glyph_spec'
compile(spec, engine = "auto", width = NULL, height = NULL)

# S3 method for class 'glyph_layout'
compile(spec, engine = "auto", width = NULL, height = NULL)
```

## Arguments

- spec:

  A glyph_spec or glyph_layout

- engine:

  Rendering backend: "auto", "html", "svg", "canvas", "webgl"

- width:

  Width in pixels (NULL for auto)

- height:

  Height in pixels (NULL for auto)

## Value

A `glyph_compiled` object (a list with resolved data + JSON)

A `glyph_compiled` object containing the resolved spec, JSON string, and
engine selection

A `glyph_compiled` object containing the resolved layout spec and JSON
string
