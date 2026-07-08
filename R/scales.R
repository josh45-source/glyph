#' @title Scales
#' @name scales
#' @description Scales map data values to visual properties. Glyph simplifies
#'   ggplot2's `scale_<aesthetic>_<type>` explosion into a composable system:
#'   `scale(<aesthetic>, <type>, ...)`.
NULL

#' Define a scale for an aesthetic channel
#'
#' @param spec A glyph_spec
#' @param aesthetic Which channel: "x", "y", "color", "size", "shape", "alpha"
#' @param type Scale type: "linear", "log", "sqrt", "time", "ordinal",
#'   "band", "quantize", "threshold"
#' @param domain Explicit domain (data range). NULL for auto.
#' @param range Explicit output range. For color: a palette name or vector.
#' @param nice Round domain to nice values (TRUE/FALSE)
#' @param zero Force zero in domain (TRUE/FALSE)
#' @param reverse Reverse the scale
#' @param label Axis/legend label (NULL for auto from column name)
#' @param format Format string for tick labels (e.g. "$.2f", "%b %Y")
#' @param base Log base, used when \code{type = "log"} (default 10 if NULL)
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point(color = cyl) |>
#'   scale("y", "linear", zero = TRUE, label = "Miles per gallon") |>
#'   scale("color", "ordinal", range = "Set2")
scale <- function(spec, aesthetic, type = "auto",
                  domain = NULL, range = NULL,
                  nice = TRUE, zero = FALSE, reverse = FALSE,
                  label = NULL, format = NULL, base = NULL) {
  stopifnot(inherits(spec, "glyph_spec"))

  sc <- list(
    aesthetic = aesthetic,
    type      = type,
    domain    = domain,
    range     = range,
    nice      = nice,
    zero      = zero,
    reverse   = reverse,
    label     = label,
    format    = format,
    base      = base
  )

  spec$scales[[aesthetic]] <- sc
  spec
}

# ---- Convenience wrappers (optional syntactic sugar) -------------------------

#' @describeIn scales Set color palette by name
#' @param spec A glyph_spec
#' @param palette A named palette: "viridis", "Set2", "Tableau10", "Blues", etc.
#' @param ... Additional arguments passed to \code{scale()}
#' @return Modified \code{glyph_spec} object
#' @export
scale_color <- function(spec, palette = "Tableau10", ...) {
  scale(spec, "color", range = palette, ...)
}

#' @describeIn scales Log-transform an axis
#' @param aesthetic Which channel: "x", "y", "color", "size", "shape", "alpha"
#' @param base Log base (default 10)
#' @return Modified \code{glyph_spec} object
#' @export
scale_log <- function(spec, aesthetic = "y", base = 10, ...) {
  scale(spec, aesthetic, type = "log", base = base, ...)
}

#' @describeIn scales Time/date axis
#' @return Modified \code{glyph_spec} object
#' @export
scale_time <- function(spec, aesthetic = "x", ...) {
  scale(spec, aesthetic, type = "time", ...)
}
