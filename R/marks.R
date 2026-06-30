#' @title Visual Marks
#' @name marks
#' @description Marks are the visual encodings in glyph — analogous to ggplot2's
#'   geoms but with key differences:
#'
#'   1. **Mappings without aes()**: pass bare column names directly.
#'   2. **Per-mark data**: each mark can have its own data source, enabling
#'      multi-dataset plots without awkward data parameter overrides.
#'   3. **Built-in interaction hints**: marks carry interaction metadata
#'      (what happens on hover, click, drag) as part of the spec.
#'   4. **Transition-aware**: marks know how to interpolate between states
#'      for animation.
NULL

#' Add a point mark (scatterplot)
#' @param spec A glyph_spec
#' @param ... Aesthetic mappings (x, y, color, size, shape, alpha, tooltip)
#' @param data Optional per-mark data override
#' @param style Named list of fixed visual properties
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' spec <- glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point(color = cyl, size = hp, tooltip = "{cyl} cyl, {mpg} mpg")
mark_point <- function(spec, ..., data = NULL, style = list()) {
  add_mark(spec, "point", rlang::enquos(...), data, style,
           defaults = list(size = 5, opacity = 0.8))
}

#' Add a line mark
#' @inheritParams mark_point
#' @param interpolate Interpolation method: "linear", "monotone", "step", "basis"
#' @return Modified \code{glyph_spec} object with the line mark added
#' @export
mark_line <- function(spec, ..., data = NULL, style = list(),
                      interpolate = "monotone") {
  add_mark(spec, "line", rlang::enquos(...), data, style,
           defaults = list(stroke_width = 2, interpolate = interpolate))
}

#' Add a bar mark
#' @inheritParams mark_point
#' @param orient "vertical" or "horizontal"
#' @return Modified \code{glyph_spec} object with the bar mark added
#' @export
mark_bar <- function(spec, ..., data = NULL, style = list(),
                     orient = "vertical") {
  add_mark(spec, "bar", rlang::enquos(...), data, style,
           defaults = list(orient = orient, corner_radius = 2, padding = 0.1))
}

#' Add an area mark
#' @inheritParams mark_point
#' @return Modified \code{glyph_spec} object with the area mark added
#' @export
mark_area <- function(spec, ..., data = NULL, style = list()) {
  add_mark(spec, "area", rlang::enquos(...), data, style,
           defaults = list(opacity = 0.6, interpolate = "monotone"))
}

#' Add a text/label mark
#' @inheritParams mark_point
#' @param smart_repel Automatically avoid label overlaps (TRUE by default).
#'   This is a first-class feature, not an extension package.
#' @return Modified \code{glyph_spec} object with the text mark added
#' @export
mark_text <- function(spec, ..., data = NULL, style = list(),
                      smart_repel = TRUE) {
  add_mark(spec, "text", rlang::enquos(...), data, style,
           defaults = list(font_size = 11, smart_repel = smart_repel))
}

#' Add a rule (reference line) mark
#' @inheritParams mark_point
#' @param x_intercept Fixed x position for vertical rule
#' @param y_intercept Fixed y position for horizontal rule
#' @return Modified \code{glyph_spec} object with the rule mark added
#' @export
mark_rule <- function(spec, ..., data = NULL, style = list(),
                      x_intercept = NULL, y_intercept = NULL) {
  extras <- list()
  if (!is.null(x_intercept)) extras$x_intercept <- x_intercept
  if (!is.null(y_intercept)) extras$y_intercept <- y_intercept
  add_mark(spec, "rule", rlang::enquos(...), data, style,
           defaults = c(list(stroke_width = 1, dash = "4 2"), extras))
}

#' Add a ribbon/band mark (for confidence intervals, ranges)
#' @inheritParams mark_point
#' @return Modified \code{glyph_spec} object with the ribbon mark added
#' @export
mark_ribbon <- function(spec, ..., data = NULL, style = list()) {
  add_mark(spec, "ribbon", rlang::enquos(...), data, style,
           defaults = list(opacity = 0.3))
}

#' Add a link/edge mark (for networks, sankeys, slope graphs)
#' @inheritParams mark_point
#' @return Modified \code{glyph_spec} object with the link mark added
#' @export
mark_link <- function(spec, ..., data = NULL, style = list()) {
  add_mark(spec, "link", rlang::enquos(...), data, style,
           defaults = list(stroke_width = 1, opacity = 0.5))
}

# ---- Internal mark builder ---------------------------------------------------

#' @noRd
add_mark <- function(spec, type, quos, data, style, defaults = list()) {
  stopifnot(inherits(spec, "glyph_spec"))

  mappings <- capture_mappings(quos)

  mark <- list(
    type     = type,
    mappings = mappings,
    data     = if (!is.null(data)) validate_data(data) else NULL,
    style    = utils::modifyList(defaults, style),
    id       = paste0(type, "_", length(spec$marks) + 1)
  )

  spec$marks <- c(spec$marks, list(mark))
  spec
}
