#' @title First-Class Interactivity
#' @name interactivity
#' @description Unlike ggplot2 where interactivity is bolted on via ggplotly(),
#'   glyph treats interaction as part of the visualization grammar. Interactions
#'   are declared in the spec and compiled to the appropriate backend
#'   (D3 events for HTML, Shiny bindings for server-side).
#'
#' @details
#' Design philosophy: interactions are *selections* that filter or highlight
#' marks. This follows Vega-Lite's insight that most interactions are really
#' about defining subsets of the data. A tooltip is "select the nearest point,
#' show its values." Brushing is "select points in a rectangle, highlight them."
NULL

#' Add interactive behaviors to a glyph spec
#'
#' @param spec A glyph_spec
#' @param tooltip Show values on hover. TRUE for auto-generated, or a
#'   glue-style template string like "\{x\}: \{y\} (\{color\})".
#' @param zoom Enable scroll-to-zoom and pan
#' @param brush Enable rectangular brush selection
#' @param hover Highlight mark on hover ("enlarge", "brighten", "outline", or NULL)
#' @param click Action on click: "select", "filter", "url", or a callback name
#' @param crossfilter Link this plot's selections to other plots in a layout
#' @param nearest Snap selection to nearest point (useful for line charts)
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point(color = cyl) |>
#'   interact(
#'     tooltip = "{cyl} cylinders\n{mpg} mpg at {wt} tons",
#'     zoom = TRUE,
#'     hover = "enlarge",
#'     brush = TRUE,
#'     crossfilter = TRUE
#'   )
interact <- function(spec,
                        tooltip = FALSE,
                        zoom = FALSE,
                        brush = FALSE,
                        hover = NULL,
                        click = NULL,
                        crossfilter = FALSE,
                        nearest = FALSE) {
  stopifnot(inherits(spec, "glyph_spec"))

  interactions <- list()

  if (!isFALSE(tooltip)) {
    interactions$tooltip <- list(
      enabled  = TRUE,
      template = if (isTRUE(tooltip)) "auto" else tooltip
    )
  }

  if (isTRUE(zoom)) {
    interactions$zoom <- list(
      enabled = TRUE,
      type    = "wheel",     # "wheel", "pinch", "drag"
      x_only  = FALSE,
      y_only  = FALSE
    )
  }

  if (isTRUE(brush)) {
    interactions$brush <- list(
      enabled = TRUE,
      type    = "rect",       # "rect", "x", "y", "lasso"
      action  = "highlight",  # "highlight", "filter", "callback"
      resolve = "intersect"
    )
  }

  if (!is.null(hover)) {
    hover_type <- match.arg(hover, c("enlarge", "brighten", "outline", "fade_others"))
    interactions$hover <- list(
      enabled = TRUE,
      effect  = hover_type
    )
  }

  if (!is.null(click)) {
    interactions$click <- list(
      enabled = TRUE,
      action  = click
    )
  }

  if (isTRUE(crossfilter)) {
    interactions$crossfilter <- list(enabled = TRUE)
  }

  if (isTRUE(nearest)) {
    interactions$nearest <- list(enabled = TRUE)
  }

  spec$interact <- utils::modifyList(spec$interact, interactions)
  spec
}

#' Add a selection parameter (advanced)
#'
#' @description For complex interactions: define a named selection that
#'   can be referenced by marks and scales. This is how you build linked
#'   views, conditional encoding, and interactive legends.
#'
#' @param spec A glyph_spec
#' @param name Selection name (referenced in conditional encodings)
#' @param type "point", "interval", or "legend"
#' @param on Event trigger: "click", "mouseover", "drag"
#' @param fields Which data fields the selection projects onto
#' @param resolve For composed views: "global", "union", "intersect"
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' # Interactive legend: click legend entries to filter
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point(color = cyl) |>
#'   selection("legend_filter", type = "legend", fields = "cyl")
selection <- function(spec, name, type = "point", on = "click",
                      fields = NULL, resolve = "global") {
  stopifnot(inherits(spec, "glyph_spec"))
  type <- match.arg(type, c("point", "interval", "legend"))

  sel <- list(
    name    = name,
    type    = type,
    on      = on,
    fields  = fields,
    resolve = resolve
  )

  if (is.null(spec$interact$selections)) {
    spec$interact$selections <- list()
  }
  spec$interact$selections[[name]] <- sel
  spec
}
