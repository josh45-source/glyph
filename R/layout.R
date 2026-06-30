#' @title Layout Composition
#' @name layout
#' @description Built-in multi-plot composition. No external packages needed.
#'   Layouts can express grids, stacks, insets, marginal plots, and
#'   arbitrary nesting. Composed plots can share selections for
#'   cross-filtering (linked brushing).
NULL

#' Compose multiple glyph specs into a layout
#'
#' @param ... glyph_spec objects or layout objects (for nesting)
#' @param type Layout type: "hstack", "vstack", "grid", "wrap"
#' @param widths Relative widths for columns (e.g. c(2, 1) for 2:1 split)
#' @param heights Relative heights for rows
#' @param gap Gap between plots in px
#' @param shared_scales Share axis scales across plots: TRUE, FALSE,
#'   "x", "y", or "both"
#' @param linked_selections Share interaction selections across plots
#' @param title Overall layout title
#' @return A `glyph_layout` object
#' @export
#'
#' @examples
#' p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
#' p2 <- glyph(mtcars, x = wt, y = hp) |> mark_point()
#' p3 <- glyph(mtcars, x = hp, y = mpg) |> mark_line()
#'
#' # Horizontal stack
#' compose(p1, p2, type = "hstack")
#'
#' # Grid with linked brushing
#' compose(p1, p2, p3, type = "wrap",
#'         linked_selections = TRUE, shared_scales = "x")
compose <- function(...,
                    type = "hstack",
                    widths = NULL,
                    heights = NULL,
                    gap = 10,
                    shared_scales = FALSE,
                    linked_selections = FALSE,
                    title = NULL) {
  plots <- list(...)

  # Validate inputs
  valid <- vapply(plots, function(p) {
    inherits(p, "glyph_spec") || inherits(p, "glyph_layout")
  }, logical(1))

  if (!all(valid)) {
    cli::cli_abort("All arguments must be glyph_spec or glyph_layout objects.")
  }

  type <- match.arg(type, c("hstack", "vstack", "grid", "wrap"))

  structure(
    list(
      plots             = plots,
      type              = type,
      widths            = widths,
      heights           = heights,
      gap               = gap,
      shared_scales     = shared_scales,
      linked_selections = linked_selections,
      title             = title
    ),
    class = "glyph_layout"
  )
}

#' Add a marginal plot (histogram/density on axes)
#'
#' @description Adds marginal distributions to a plot's axes — a common
#'   pattern that requires ggExtra or manual grid manipulation in ggplot2.
#'
#' @param spec A glyph_spec
#' @param x Marginal type for x-axis: "histogram", "density", "boxplot", NULL
#' @param y Marginal type for y-axis: "histogram", "density", "boxplot", NULL
#' @param size Proportion of plot area for marginals (0.0 to 0.4)
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point(color = cyl) |>
#'   marginals(x = "histogram", y = "density")
marginals <- function(spec, x = "histogram", y = "histogram", size = 0.15) {
  stopifnot(inherits(spec, "glyph_spec"))
  spec$layout <- list(
    type = "marginals",
    x    = x,
    y    = y,
    size = size
  )
  spec
}

#' Add an inset plot
#'
#' @param spec The main glyph_spec
#' @param inset A glyph_spec to place as an inset
#' @param position Where to place: "top-right", "top-left", "bottom-right",
#'   "bottom-left", or a list(x, y, width, height) with proportions 0-1
#' @return Modified glyph_spec
#' @export
inset <- function(spec, inset, position = "top-right") {
  stopifnot(inherits(spec, "glyph_spec"))
  stopifnot(inherits(inset, "glyph_spec"))

  if (is.character(position)) {
    position <- match.arg(position, c("top-right", "top-left",
                                       "bottom-right", "bottom-left"))
  }

  spec$layout <- list(
    type     = "inset",
    inset    = inset,
    position = position
  )
  spec
}

#' Facet a plot by one or two variables
#'
#' @description Like ggplot2's facet_wrap/facet_grid but with a key improvement:
#'   each facet can have independent geom parameters and scales by default
#'   (instead of forced uniformity).
#'
#' @param spec A glyph_spec
#' @param rows Row faceting variable (bare name or NULL)
#' @param cols Column faceting variable (bare name or NULL)
#' @param free_scales "none", "x", "y", "both"
#' @param wrap If only one variable, wrap into a grid with this many columns
#' @return Modified glyph_spec
#' @export
facet <- function(spec, rows = NULL, cols = NULL,
                  free_scales = "none", wrap = NULL) {
  stopifnot(inherits(spec, "glyph_spec"))

  rows_expr <- if (!missing(rows)) rlang::as_label(rlang::enquo(rows)) else NULL
  cols_expr <- if (!missing(cols)) rlang::as_label(rlang::enquo(cols)) else NULL

  spec$facets <- list(
    rows        = rows_expr,
    cols        = cols_expr,
    free_scales = match.arg(free_scales, c("none", "x", "y", "both")),
    wrap        = wrap
  )
  spec
}

#' @param x A glyph_layout object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns the \code{glyph_layout} object
#' @export
print.glyph_layout <- function(x, ...) {
  n <- length(x$plots)
  cli::cli_h1("Glyph Layout")
  cli::cli_bullets(c(
    "*" = "Type: {x$type}",
    "*" = "Panels: {n}",
    "*" = "Linked selections: {x$linked_selections}"
  ))
  invisible(x)
}
