#' @title Token-Based Theming
#' @name theming
#' @description Instead of ggplot2's 90+ theme() arguments, glyph uses a
#'   design-token system. A small set of semantic tokens (font, colors,
#'   spacing, sizes) cascade through the entire visualization. Think of it
#'   like CSS custom properties for plots.
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
                         title_size = NULL) {
  stopifnot(inherits(spec, "glyph_spec"))

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
    title_size = title_size
  )
  overrides <- Filter(Negate(is.null), overrides)

  spec$theme <- utils::modifyList(spec$theme, overrides)

  # Auto-derive contrast color if bg changed but fg didn't

  if (!is.null(bg) && is.null(fg)) {
    spec$theme$fg <- auto_contrast(bg)
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
      bg = "#1a1a2e", fg = "#e0e0e0", grid_color = "#2a2a4a", accent = "#6ec6ff"
    )),
    minimal = utils::modifyList(default_theme_tokens(), list(
      grid = "y", border = FALSE, grid_color = "#f0f0f0"
    )),
    publication = utils::modifyList(default_theme_tokens(), list(
      font = "Palatino, Georgia, serif", border = TRUE, grid = FALSE
    )),
    presentation = utils::modifyList(default_theme_tokens(), list(
      font_size = 18, title_size = 1.6, padding = 60
    ))
  )
  presets[[name]]
}

#' @noRd
auto_contrast <- function(bg) {
  # Simple luminance check
  rgb <- grDevices::col2rgb(bg)
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  if (luminance > 0.5) "#333333" else "#e0e0e0"
}
