#' @title Token-Based Theming
#' @name theming
#' @description A theme is set with design tokens: a small set of named
#'   values (font, colours, spacing, sizes) that cascade through the whole
#'   plot, much like CSS custom properties.
#'
#' @details
#' Tokens cascade: setting `bg` changes the background, but also automatically
#' adjusts text color for contrast, grid line opacity, and tooltip styling.
#' You override only what you want; everything else adapts.
NULL

#' Set theme tokens
#'
#' @param spec A glyph_spec
#' @param preset A named preset: "light" (default), "dark", "minimal",
#'   "publication", "presentation". Presets set all tokens to coherent defaults.
#' @param font Font family for all text
#' @param font_size Base font size in px (axis labels scale relative to this)
#' @param bg Background color
#' @param fg Primary text/axis color
#' @param accent Primary accent color (used for single-series marks)
#' @param grid Grid line visibility: TRUE, FALSE, "x", "y"
#' @param border Plot border: TRUE/FALSE
#' @param padding Padding around the plot area in px
#' @param title_size Title font size multiplier (relative to font_size)
#' @param strip_size Font size of facet strip labels in px. Follows
#'   `font_size` (at 0.9 of it) unless set.
#' @param strip_weight Font weight of facet strip labels: "normal", "bold",
#'   or a number from 100 to 900.
#' @param strip_fg Text colour of facet strip labels. Follows `fg` unless
#'   set.
#' @param strip_bg Background colour of facet strips, or "transparent".
#'   Follows `bg` (a shade towards `fg`) unless set.
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point() |>
#'   theme_tokens(preset = "dark")
#'
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point() |>
#'   theme_tokens(font = "IBM Plex Sans", bg = "#fafafa", grid = "y")
#'
#' # Facet strips: larger, normal-weight labels on a pale blue strip.
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point() |>
#'   facet(rows = cyl, cols = gear) |>
#'   theme_tokens(strip_size = 13, strip_weight = "normal", strip_bg = "#e8eef8")
theme_tokens <- function(spec,
                         preset = NULL,
                         font = NULL,
                         font_size = NULL,
                         bg = NULL,
                         fg = NULL,
                         accent = NULL,
                         grid = NULL,
                         border = NULL,
                         padding = NULL,
                         title_size = NULL,
                         strip_size = NULL,
                         strip_weight = NULL,
                         strip_fg = NULL,
                         strip_bg = NULL) {
  stopifnot(inherits(spec, "glyph_spec"))
  if (!is.null(strip_weight) && !(
    (is.character(strip_weight) && length(strip_weight) == 1 && strip_weight %in% c("normal", "bold")) ||
    (is.numeric(strip_weight) && length(strip_weight) == 1 && strip_weight >= 100 && strip_weight <= 900))) {
    cli::cli_abort('{.arg strip_weight} must be "normal", "bold", or a number from 100 to 900.')
  }

  # Start from preset if given
  if (!is.null(preset)) {
    preset <- match.arg(preset, c("light", "dark", "minimal",
                                   "publication", "presentation"))
    spec$theme <- get_preset(preset)
  }

  # Override individual tokens
  overrides <- list(
    font       = font,
    font_size  = font_size,
    bg         = bg,
    fg         = fg,
    accent     = accent,
    grid       = grid,
    border     = border,
    padding    = padding,
    title_size = title_size,
    strip_size   = strip_size,
    strip_weight = strip_weight,
    strip_fg     = strip_fg,
    strip_bg     = strip_bg
  )
  overrides <- Filter(Negate(is.null), overrides)

  spec$theme <- utils::modifyList(spec$theme, overrides)

  # Auto-derive contrast color if bg changed but fg didn't

  if (!is.null(bg) && is.null(fg)) {
    spec$theme$fg <- auto_contrast(bg)
  }
  # Strips follow the text size and colours unless set themselves.
  if (!is.null(font_size) && is.null(strip_size)) {
    spec$theme$strip_size <- round(font_size * 0.9)
  }
  if ((!is.null(fg) || !is.null(bg)) && is.null(strip_fg)) {
    spec$theme$strip_fg <- spec$theme$fg
  }
  if (!is.null(bg) && is.null(strip_bg)) {
    spec$theme$strip_bg <- strip_shade(bg, spec$theme$fg)
  }

  spec
}

#' Add a title, subtitle, or caption
#' @param spec A glyph_spec
#' @param title Main title
#' @param subtitle Subtitle (below title)
#' @param caption Caption (bottom of plot, for source attribution)
#' @return Modified \code{glyph_spec} object with updated title metadata
#' @export
titles <- function(spec, title = NULL, subtitle = NULL, caption = NULL) {
  stopifnot(inherits(spec, "glyph_spec"))
  if (!is.null(title))    spec$theme$title    <- title
  if (!is.null(subtitle)) spec$theme$subtitle <- subtitle
  if (!is.null(caption))  spec$theme$caption  <- caption
  spec
}

# ---- Presets -----------------------------------------------------------------

#' @noRd
default_theme_tokens <- function() {
  list(
    font       = "system-ui, -apple-system, sans-serif",
    font_size  = 12,
    bg         = "#ffffff",
    fg         = "#333333",
    accent     = "#4269d0",
    grid       = TRUE,
    grid_color = "#e5e5e5",
    border     = FALSE,
    padding    = 40,
    title_size = 1.4,
    strip_size   = 11,
    strip_weight = 600,
    strip_fg     = "#333333",
    strip_bg     = "#f0f0f0",
    title      = NULL,
    subtitle   = NULL,
    caption    = NULL
  )
}

#' @noRd
get_preset <- function(name) {
  presets <- list(
    light = default_theme_tokens(),
    dark = utils::modifyList(default_theme_tokens(), list(
      bg = "#1a1a2e", fg = "#e0e0e0", grid_color = "#2a2a4a", accent = "#6ec6ff",
      strip_fg = "#e0e0e0", strip_bg = "#2a2a4a"
    )),
    minimal = utils::modifyList(default_theme_tokens(), list(
      grid = "y", border = FALSE, grid_color = "#f0f0f0",
      strip_bg = "transparent"
    )),
    publication = utils::modifyList(default_theme_tokens(), list(
      font = "Palatino, Georgia, serif", border = TRUE, grid = FALSE,
      strip_weight = "normal", strip_bg = "#e5e5e5"
    )),
    presentation = utils::modifyList(default_theme_tokens(), list(
      font_size = 18, title_size = 1.6, padding = 60,
      strip_size = 16
    ))
  )
  presets[[name]]
}

# A strip background for `bg`: 8% of the way from `bg` to `fg`.
#' @noRd
strip_shade <- function(bg, fg) {
  if (identical(bg, "transparent")) return("transparent")
  rgb <- grDevices::col2rgb(c(bg, fg))
  mixed <- rgb[, 1] + (rgb[, 2] - rgb[, 1]) * 0.08
  grDevices::rgb(mixed[1], mixed[2], mixed[3], maxColorValue = 255)
}

#' @noRd
auto_contrast <- function(bg) {
  # Simple luminance check
  rgb <- grDevices::col2rgb(bg)
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  if (luminance > 0.5) "#333333" else "#e0e0e0"
}
