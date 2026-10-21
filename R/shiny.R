#' Use glyph plots in Shiny
#'
#' @description `glyphOutput()` places a plot in a Shiny app's UI and
#'   `renderGlyph()` draws it from the server. `renderGlyph()` takes a plot
#'   from [glyph()], a layout from [compose()], or a widget from [render()].
#'
#'   What the user selects in the plot is sent back to the server as
#'   `input$<outputId>_selected`, holding row numbers of the data frame given
#'   to [glyph()]. See the section below and
#'   `vignette("shiny", package = "glyph")`.
#'
#'   shiny is not installed with glyph. Install it to use these functions.
#'
#' @section Selections:
#' A selection is sent when the user ends a brush, clicks a mark with
#' `interact(click = "select")`, or clicks a legend entry added with
#' `selection(type = "legend")`. It is not sent while a brush is being
#' dragged. Clearing a brush (with the "Clear selection" button, Escape, or a
#' click on an empty part of the plot) sends `NULL`, as does clicking a
#' selected mark again. So does redrawing the plot, which happens when
#' `renderGlyph()` runs again or the output is resized.
#'
#' For a single plot the value is an integer vector of row numbers, so
#' `data[input$plot_selected, ]` gives the selected rows. Row numbers are
#' positions in the data frame, not row names. They are correct when rows
#' with missing values were dropped and when a mapping is computed (such as
#' `x = log(wt)`). Selecting a box, violin, histogram bin or polygon selects
#' every row it summarises. A mark drawn from its own `data` takes no part in
#' the value. A brush that takes in no rows gives `integer(0)`.
#'
#' A legend selects the rows whose entries are still shown. With every entry
#' shown there is no selection, and the value is `NULL`.
#'
#' A [facet()] grid has one data frame, so its value is one vector: the rows
#' selected in any of its panels.
#'
#' A [compose()] layout gives a list with one entry per panel, in the order
#' the panels were given, named after them when `compose()` was called with
#' names. Each entry holds the rows selected in that panel, as row numbers of
#' that panel's data, or `NULL` when nothing is selected there. A panel that
#' is itself a layout gives a list of the same shape. When no panel has a
#' selection the whole value is `NULL`.
#'
#' ```r
#' output$plots <- renderGlyph(compose(cars = p1, iris = p2))
#' # input$plots_selected is NULL, or for example
#' # list(cars = c(3L, 18L), iris = NULL)
#' ```
#'
#' @param outputId Output variable to read the plot from.
#' @param width,height Size of the plot, as a CSS size such as `"100%"` or
#'   `"400px"`, or a number of pixels.
#' @param expr An expression that returns a glyph_spec, a glyph_layout or a
#'   widget made by [render()]. It can also return `NULL`, which shows
#'   nothing and clears the selection.
#' @param env The environment in which to evaluate `expr`.
#' @param quoted Is `expr` a quoted expression (with [quote()])? This is
#'   useful if you want to save an expression in a variable.
#' @return `glyphOutput()` returns the UI element for the plot.
#'   `renderGlyph()` returns a render function to assign to an element of
#'   `output`.
#' @name glyph-shiny
#' @export
#'
#' @examples
#' if (interactive() && requireNamespace("shiny", quietly = TRUE)) {
#'   library(shiny)
#'
#'   ui <- fluidPage(
#'     glyphOutput("plot"),
#'     tableOutput("rows")
#'   )
#'
#'   server <- function(input, output) {
#'     output$plot <- renderGlyph(
#'       glyph(mtcars, x = wt, y = mpg) |>
#'         mark_point() |>
#'         interact(brush = TRUE)
#'     )
#'     output$rows <- renderTable(mtcars[input$plot_selected, ], rownames = TRUE)
#'   }
#'
#'   shinyApp(ui, server)
#' }
glyphOutput <- function(outputId, width = "100%", height = "400px") {
  rlang::check_installed("shiny", "to use glyph in Shiny.")
  htmlwidgets::shinyWidgetOutput(outputId, "glyph", width, height, package = "glyph")
}

#' @rdname glyph-shiny
#' @export
renderGlyph <- function(expr, env = parent.frame(), quoted = FALSE) {
  rlang::check_installed("shiny", "to use glyph in Shiny.")
  if (!quoted) expr <- substitute(expr)
  register_selection_handler()
  # The plot is turned into a widget after `expr` is evaluated, so the user
  # can return a spec or layout as they would print one. `expr` becomes the
  # body of its own function, `glyph_plot()` in this frame, so a return() in
  # it, as in `if (is.null(input$file)) return(NULL)`, still goes through the
  # conversion. Shiny's own installExprFunction() makes it, as for any other
  # render function.
  #
  # What Shiny runs is then the call below, evaluated in this frame, where
  # both names are found. It has to be language only: RStudio's Shiny debug
  # hook walks it and calls as.character() on its parts, and fails on a
  # function object placed in the call itself.
  shiny::installExprFunction(expr, "glyph_plot", env, quoted = TRUE)
  htmlwidgets::shinyRenderWidget(quote(as_glyph_widget(glyph_plot())), glyphOutput,
                                 environment(), quoted = TRUE)
}

#' The widget for a plot returned to renderGlyph()
#' @description `NULL` becomes an empty widget, which clears the plot and
#'   reports that nothing is selected. (htmlwidgets would hide the output
#'   instead and leave the old plot and its selection behind.)
#' @noRd
as_glyph_widget <- function(x) {
  if (is.null(x)) return(htmlwidgets::createWidget("glyph", list(empty = TRUE), package = "glyph"))
  if (inherits(x, c("glyph_spec", "glyph_layout", "glyph_compiled"))) return(render(x))
  if (inherits(x, "htmlwidget") && inherits(x, "glyph")) return(x)
  cli::cli_abort(c(
    "{.fn renderGlyph} needs a plot from {.fn glyph}, a layout from {.fn compose}, or a widget from {.fn render}.",
    "x" = "It got {.obj_type_friendly {x}}."
  ))
}

#' Turn a selection sent by the browser into input$<id>_selected
#' @description The browser sends `null`, an array of 1-based row numbers,
#'   or for a compose() layout `{panels: [...], names: [...]}` (see
#'   selectionValue() in glyph.js). Shiny has parsed the JSON without
#'   simplifying it, so arrays arrive as lists.
#' @noRd
selection_from_json <- function(x, session = NULL, name = NULL) {
  if (is.null(x)) return(NULL)
  if (is.list(x) && "panels" %in% names(x)) {
    panels <- lapply(x$panels, selection_from_json)
    if (!is.null(x$names)) names(panels) <- as.character(unlist(x$names))
    return(panels)
  }
  as.integer(unlist(x))
}

#' Tell Shiny how to read selections
#' @description The browser sends selections with the type "glyph.selection",
#'   and Shiny refuses an input whose type has no handler. Registered when
#'   glyph is loaded if shiny already is, when shiny is loaded otherwise, and
#'   again by renderGlyph().
#' @noRd
register_selection_handler <- function() {
  shiny::registerInputHandler("glyph.selection", selection_from_json, force = TRUE)
}

.onLoad <- function(libname, pkgname) {
  if (isNamespaceLoaded("shiny")) {
    register_selection_handler()
  } else {
    setHook(packageEvent("shiny", "onLoad"), function(...) register_selection_handler())
  }
}
