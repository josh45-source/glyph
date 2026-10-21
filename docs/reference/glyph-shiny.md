# Use glyph plots in Shiny

`glyphOutput()` places a plot in a Shiny app's UI and `renderGlyph()`
draws it from the server. `renderGlyph()` takes a plot from
[`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md), a
layout from
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md),
or a widget from
[`render()`](https://josh45-source.github.io/glyph/reference/render.md).

What the user selects in the plot is sent back to the server as
`input$<outputId>_selected`, holding row numbers of the data frame given
to
[`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md).
See the section below and
[`vignette("shiny", package = "glyph")`](https://josh45-source.github.io/glyph/articles/shiny.md).

shiny is not installed with glyph. Install it to use these functions.

## Usage

``` r
glyphOutput(outputId, width = "100%", height = "400px")

renderGlyph(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- outputId:

  Output variable to read the plot from.

- width, height:

  Size of the plot, as a CSS size such as `"100%"` or `"400px"`, or a
  number of pixels.

- expr:

  An expression that returns a glyph_spec, a glyph_layout or a widget
  made by
  [`render()`](https://josh45-source.github.io/glyph/reference/render.md).
  It can also return `NULL`, which shows nothing and clears the
  selection.

- env:

  The environment in which to evaluate `expr`.

- quoted:

  Is `expr` a quoted expression (with
  [`quote()`](https://rdrr.io/r/base/substitute.html))? This is useful
  if you want to save an expression in a variable.

## Value

`glyphOutput()` returns the UI element for the plot. `renderGlyph()`
returns a render function to assign to an element of `output`.

## Selections

A selection is sent when the user ends a brush, clicks a mark with
`interact(click = "select")`, or clicks a legend entry added with
`selection(type = "legend")`. It is not sent while a brush is being
dragged. Clearing a brush (with the "Clear selection" button, Escape, or
a click on an empty part of the plot) sends `NULL`, as does clicking a
selected mark again. So does redrawing the plot, which happens when
`renderGlyph()` runs again or the output is resized.

For a single plot the value is an integer vector of row numbers, so
`data[input$plot_selected, ]` gives the selected rows. Row numbers are
positions in the data frame, not row names. They are correct when rows
with missing values were dropped and when a mapping is computed (such as
`x = log(wt)`). Selecting a box, violin, histogram bin or polygon
selects every row it summarises. A mark drawn from its own `data` takes
no part in the value. A brush that takes in no rows gives `integer(0)`.

A legend selects the rows whose entries are still shown. With every
entry shown there is no selection, and the value is `NULL`.

A [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
grid has one data frame, so its value is one vector: the rows selected
in any of its panels.

A
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
layout gives a list with one entry per panel, in the order the panels
were given, named after them when
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
was called with names. Each entry holds the rows selected in that panel,
as row numbers of that panel's data, or `NULL` when nothing is selected
there. A panel that is itself a layout gives a list of the same shape.
When no panel has a selection the whole value is `NULL`.

    output$plots <- renderGlyph(compose(cars = p1, iris = p2))
    # input$plots_selected is NULL, or for example
    # list(cars = c(3L, 18L), iris = NULL)

## Examples

``` r
if (interactive() && requireNamespace("shiny", quietly = TRUE)) {
  library(shiny)

  ui <- fluidPage(
    glyphOutput("plot"),
    tableOutput("rows")
  )

  server <- function(input, output) {
    output$plot <- renderGlyph(
      glyph(mtcars, x = wt, y = mpg) |>
        mark_point() |>
        interact(brush = TRUE)
    )
    output$rows <- renderTable(mtcars[input$plot_selected, ], rownames = TRUE)
  }

  shinyApp(ui, server)
}
```
