#' @title Create a Glyph Visualization
#' @description Entry point for the glyph grammar. Creates a specification
#'   that describes a visualization declaratively. The spec is a plain nested
#'   list: it can be inspected, serialized to JSON, and compiled into an
#'   interactive HTML widget.
#'
#' @param data A data frame or tibble, or `NULL` if each mark will supply its
#'   own data.
#' @param ... Global aesthetic mappings, written as bare column names or
#'   expressions, e.g. `glyph(mtcars, x = wt, y = mpg)`. Every mark uses these
#'   unless it sets its own.
#' @return A `glyph_spec` object
#' @export
#'
#' @examples
#' spec <- glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point()
#' summary(spec)
glyph <- function(data = NULL, ...) {
  mappings <- capture_mappings(rlang::enquos(...))

  spec <- structure(
    list(
      data      = validate_data(data),
      mappings  = mappings,
      marks     = list(),
      scales    = list(),
      coords    = list(type = "cartesian"),
      facets    = NULL,
      interact  = list(),
      animate   = NULL,
      theme     = default_theme_tokens(),
      layout    = NULL,
      metadata  = list(
        created = Sys.time(),
        engine  = "auto"
      )
    ),
    class = "glyph_spec"
  )

  spec
}

#' Summarize a glyph specification
#'
#' @param object A glyph_spec object
#' @param ... Additional arguments (ignored)
#' @return No return value, called for side effects (prints a summary
#'   of the specification to the console)
#' @export
summary.glyph_spec <- function(object, ...) {
  n_marks <- length(object$marks)
  n_interact <- length(object$interact)
  has_anim <- !is.null(object$animate)
  data_desc <- if (is.null(object$data)) {
    "no data"
  } else {
    paste0(nrow(object$data), " x ", ncol(object$data))
  }

  cli::cli_h1("Glyph Specification")
  cli::cli_bullets(c(
    "*" = "Data: {data_desc}",
    "*" = "Marks: {n_marks}",
    "*" = "Interactions: {n_interact}",
    "*" = "Animated: {has_anim}"
  ))
  invisible(object)
}

# ---- Internal helpers --------------------------------------------------------

#' Capture bare-name mappings without requiring aes()
#' @noRd
capture_mappings <- function(quos) {
  if (length(quos) == 0) return(list())
  nms <- names(quos)
  if (is.null(nms) || any(nms == "")) {
    cli::cli_abort("All mappings must be named: glyph(data, x = col1, y = col2)")
  }
  lapply(quos, function(q) {
    list(
      expr  = rlang::as_label(q),
      quosure = q
    )
  })
}

#' Validate and normalize data input
#' @noRd
validate_data <- function(data) {
  if (is.null(data)) return(NULL)
  if (is.data.frame(data)) return(data)
  if (is.character(data) && length(data) == 1) {
    # Future: load from URL or file path
    cli::cli_abort("URL/file data sources are planned but not yet implemented.")
  }
  cli::cli_abort("Data must be a data.frame, tibble, or NULL.")
}

