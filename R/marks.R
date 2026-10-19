#' @title Visual Marks
#' @name marks
#' @description Marks are the layers that draw data: points, lines, bars,
#'   areas, text, rules, ribbons, links and polygons. Each `mark_*()` call
#'   adds one layer to the spec. [mark_boxplot()], [mark_violin()],
#'   [mark_sina()] and
#'   [mark_histogram()] summarise the distribution of a variable; their
#'   statistics are computed from the data when the plot is compiled.
#'
#'   Mappings are passed as bare column names or expressions, and are added
#'   to the global mappings set in [glyph()]. A mark can also take its own
#'   `data`, so one plot can draw from several data frames. Fixed visual
#'   properties that don't depend on the data, such as `size`, `opacity` or
#'   `stroke_width`, go in `style`. Interaction and animation are set for the whole plot with
#'   [interact()] and [animate()].
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
#'   Inspired by \pkg{ggrepel}, but simpler: rather than a full force-directed
#'   simulation, glyph resolves overlaps by iterative pairwise nudging. It
#'   repeatedly compares every pair of label bounding boxes and, for any
#'   pair that still overlaps, pushes them a small step apart vertically
#'   (up to 50 passes, stopping as soon as none overlap).
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

#' Add a polygon mark
#'
#' @description Draws closed shapes from `x`/`y` vertices. Rows that share a
#'   value of `group` are the vertices of one polygon, joined in row order,
#'   and the last vertex is joined back to the first. Without a `group`
#'   mapping, all rows form one polygon. Mapping `color` fills each polygon by
#'   its value; a polygon whose rows have different colours is split into one
#'   polygon per colour.
#'
#'   Each polygon is one element: its tooltip shows the polygon rather than a
#'   single vertex, and brushing or clicking it selects all of its rows. A
#'   tooltip template can use any column that has the same value on every row
#'   of the polygon, such as a name or an id. Rows with a missing `x` or `y`
#'   are dropped first, with a warning, and polygons left with fewer than
#'   three vertices are not drawn.
#' @inheritParams mark_point
#' @param ... Aesthetic mappings: `x` and `y` (required, numeric), `group`
#'   and `color`.
#' @param style Named list of fixed visual properties: `fill` (a colour used
#'   when `color` isn't mapped), `stroke` (outline colour, the theme's
#'   foreground colour by default), `stroke_width` (in pixels, 0 for no
#'   outline) and `opacity` (of the fill).
#' @param radius Radius of rounded corners, in pixels. Each corner is rounded
#'   by at most half the length of its shorter edge. 0 (the default) keeps
#'   sharp corners.
#' @return Modified \code{glyph_spec} object with the polygon mark added
#' @export
#'
#' @examples
#' triangles <- data.frame(
#'   id = rep(c("a", "b"), each = 3),
#'   x = c(0, 1, 0.5, 1.5, 2.5, 2),
#'   y = c(0, 0, 1, 0, 0, 1)
#' )
#' glyph(triangles, x = x, y = y) |>
#'   mark_polygon(group = id, color = id)
mark_polygon <- function(spec, ..., data = NULL, style = list(), radius = 0) {
  check_number(radius, "radius", min = 0)
  add_mark(spec, "polygon", rlang::enquos(...), data, style,
           defaults = list(opacity = 0.7, stroke_width = 1, radius = radius),
           stat = list(type = "polygon"))
}

# ---- Statistical marks -------------------------------------------------------

#' Add a boxplot mark
#'
#' @description Draws one box per group: the box spans the first to third
#'   quartile, the line inside it is the median, and the whiskers reach the
#'   most extreme values within `coef` times the interquartile range of the
#'   box. Values beyond the whiskers are drawn as outlier points.
#'
#'   Map `y` to the numeric variable and `x` to the grouping variable, which
#'   is treated as categorical even when it is numeric. Without `x`, all rows
#'   form one box. Mapping `color` to a different variable than `x` places
#'   one box per colour side by side within each x group.
#'
#'   The statistics are computed in R when the plot is compiled, using
#'   [stats::quantile()] with its default `type = 7`. Rows with a missing `x`
#'   or `y` are dropped first, with a warning.
#' @inheritParams mark_point
#' @param ... Aesthetic mappings: `y` (required, numeric), `x` and `color`.
#' @param coef Length of the whiskers as a multiple of the interquartile
#'   range. Use `Inf` to extend them to the minimum and maximum.
#' @param outliers Whether to draw values beyond the whiskers as points.
#' @param width Width of each box as a fraction of the space for its group,
#'   between 0 and 1.
#' @return Modified \code{glyph_spec} object with the boxplot mark added
#' @export
#'
#' @examples
#' glyph(mtcars, x = factor(cyl), y = mpg) |>
#'   mark_boxplot()
mark_boxplot <- function(spec, ..., data = NULL, style = list(),
                         coef = 1.5, outliers = TRUE, width = 0.7) {
  check_number(coef, "coef", min = 0)
  check_flag(outliers, "outliers")
  check_number(width, "width", min = 0, max = 1, allow_min = FALSE)
  add_mark(spec, "boxplot", rlang::enquos(...), data, style,
           defaults = list(opacity = 0.7, stroke_width = 1),
           stat = list(type = "boxplot", coef = coef, outliers = outliers,
                       width = width))
}

#' Add a violin mark
#'
#' @description Draws the distribution of a numeric variable for each group
#'   as a mirrored kernel density curve, trimmed to the range of the group's
#'   values. All violins in the mark use the same density scale, so their
#'   widths can be compared directly.
#'
#'   Map `y` to the numeric variable and `x` to the grouping variable, which
#'   is treated as categorical even when it is numeric. Without `x`, all rows
#'   form one violin. Mapping `color` to a different variable than `x` places
#'   one violin per colour side by side within each x group.
#'
#'   The densities are computed in R when the plot is compiled, with
#'   [stats::density()]. A group needs at least two distinct values; groups
#'   with fewer are left out with a warning.
#' @inheritParams mark_point
#' @param ... Aesthetic mappings: `y` (required, numeric), `x` and `color`.
#' @param bw Smoothing bandwidth, passed to [stats::density()]: a number or
#'   the name of a bandwidth rule such as `"nrd0"` (the default) or `"SJ"`.
#' @param adjust Multiplier for the bandwidth. Values above 1 give smoother
#'   curves.
#' @param width Width of the widest violin as a fraction of the space for
#'   its group, between 0 and 1.
#' @return Modified \code{glyph_spec} object with the violin mark added
#' @export
#'
#' @examples
#' glyph(mtcars, x = factor(cyl), y = mpg) |>
#'   mark_violin()
mark_violin <- function(spec, ..., data = NULL, style = list(),
                        bw = "nrd0", adjust = 1, width = 0.9) {
  check_bandwidth(bw)
  check_number(adjust, "adjust", min = 0, allow_min = FALSE)
  check_number(width, "width", min = 0, max = 1, allow_min = FALSE)
  add_mark(spec, "violin", rlang::enquos(...), data, style,
           defaults = list(opacity = 0.6, stroke_width = 1),
           stat = list(type = "violin", bw = bw, adjust = adjust, width = width))
}

#' Add a sina mark
#'
#' @description Draws every row as a point, spread sideways within its group
#'   in proportion to the density of values at that height. The points fill
#'   the same outline a [mark_violin()] with the same settings would draw, so
#'   the two combine well.
#'
#'   Each point is still a row of the data, so tooltips, brushing and linked
#'   selections work on individual rows, as they do for [mark_point()]. The
#'   sideways positions are computed in R when the plot is compiled and are
#'   the same every time.
#' @inheritParams mark_violin
#' @param ... Aesthetic mappings: `y` (required, numeric), `x`, `color` and
#'   `size`.
#' @param width Width of the spread at the highest density, as a fraction of
#'   the space for its group, between 0 and 1.
#' @return Modified \code{glyph_spec} object with the sina mark added
#' @export
#'
#' @examples
#' glyph(mtcars, x = factor(cyl), y = mpg) |>
#'   mark_violin() |>
#'   mark_sina()
mark_sina <- function(spec, ..., data = NULL, style = list(),
                      bw = "nrd0", adjust = 1, width = 0.9) {
  check_bandwidth(bw)
  check_number(adjust, "adjust", min = 0, allow_min = FALSE)
  check_number(width, "width", min = 0, max = 1, allow_min = FALSE)
  add_mark(spec, "sina", rlang::enquos(...), data, style,
           defaults = list(size = 3, opacity = 0.8),
           stat = list(type = "sina", bw = bw, adjust = adjust, width = width))
}

#' Add a histogram mark
#'
#' @description Counts how many rows fall into each bin of a numeric `x`
#'   variable and draws one bar per bin. Bins are closed on the right, like
#'   [graphics::hist()], and the lowest bin also includes its left edge.
#'   Mapping `color` stacks one bar segment per colour within each bin.
#'
#'   With neither `bins` nor `binwidth`, the number of bins follows Sturges'
#'   rule and the edges are rounded to tidy values, as in
#'   [graphics::hist()]. All facet panels share the same bins.
#'
#'   The counts are computed in R when the plot is compiled. Rows with a
#'   missing `x` are dropped first, with a warning.
#' @inheritParams mark_point
#' @param ... Aesthetic mappings: `x` (required, numeric) and `color`. There
#'   is no `y` mapping; the bar heights are the counts.
#' @param bins Number of equal-width bins spanning the range of `x`.
#' @param binwidth Width of each bin. Bin edges are multiples of `binwidth`.
#'   Takes precedence over `bins`.
#' @return Modified \code{glyph_spec} object with the histogram mark added
#' @export
#'
#' @examples
#' glyph(mtcars, x = mpg) |>
#'   mark_histogram(binwidth = 2.5)
mark_histogram <- function(spec, ..., data = NULL, style = list(),
                           bins = NULL, binwidth = NULL) {
  if (!is.null(bins)) {
    check_number(bins, "bins", min = 1)
    if (bins != round(bins)) cli::cli_abort("{.arg bins} must be a whole number.")
  }
  if (!is.null(binwidth)) check_number(binwidth, "binwidth", min = 0, allow_min = FALSE)
  add_mark(spec, "histogram", rlang::enquos(...), data, style,
           defaults = list(opacity = 0.85),
           stat = list(type = "histogram", bins = bins, binwidth = binwidth))
}

# Argument checks for the statistical marks.
check_number <- function(x, arg, min = -Inf, max = Inf, allow_min = TRUE) {
  ok <- is.numeric(x) && length(x) == 1 && !is.na(x) &&
    x <= max && (if (allow_min) x >= min else x > min)
  if (!ok) {
    bound <- if (allow_min) ">=" else ">"
    range_txt <- if (is.finite(max)) {
      sprintf("between %s and %s", min, max)
    } else {
      sprintf("%s %s", bound, min)
    }
    cli::cli_abort("{.arg {arg}} must be a single number {range_txt}.")
  }
  invisible(x)
}

check_flag <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1 || is.na(x)) {
    cli::cli_abort("{.arg {arg}} must be {.code TRUE} or {.code FALSE}.")
  }
  invisible(x)
}

check_bandwidth <- function(bw) {
  ok <- (is.character(bw) && length(bw) == 1) ||
    (is.numeric(bw) && length(bw) == 1 && !is.na(bw) && bw > 0)
  if (!ok) {
    cli::cli_abort("{.arg bw} must be a positive number or the name of a bandwidth rule.")
  }
  invisible(bw)
}

# ---- Internal mark builder ---------------------------------------------------

#' @noRd
add_mark <- function(spec, type, quos, data, style, defaults = list(),
                     stat = NULL) {
  stopifnot(inherits(spec, "glyph_spec"))

  mappings <- capture_mappings(quos)

  mark <- list(
    type     = type,
    mappings = mappings,
    data     = if (!is.null(data)) validate_data(data) else NULL,
    style    = utils::modifyList(defaults, style),
    id       = paste0(type, "_", length(spec$marks) + 1),
    stat     = stat
  )

  spec$marks <- c(spec$marks, list(mark))
  spec
}
