#' @title Animation Grammar
#' @name animation
#' @description Animations in glyph are declarative state transitions, not
#'   frame-by-frame rendering. You describe *what changes* and *how it should
#'   interpolate*, and the renderer handles the rest.
#'
#' @details
#' Two animation paradigms:
#' - **Transitions**: animate between data states (e.g. year 2020 → 2021).
#'   Marks morph smoothly, entering/exiting as data changes.
#' - **Entrances**: animate marks appearing on first render (stagger bars
#'   growing from zero, points fading in).
NULL

#' Add animation/transition behavior
#'
#' @param spec A glyph_spec
#' @param transition Transition type: "morph", "fade", "slide", "none"
#' @param duration Duration in milliseconds
#' @param stagger Delay between successive marks in ms (for entrance effects)
#' @param by Column that defines animation keyframes (like gganimate's
#'   transition_states). e.g. by = year plays through years.
#' @param easing Easing function: "linear", "ease-in", "ease-out",
#'   "ease-in-out", "bounce", "elastic"
#' @param loop Repeat animation (TRUE, FALSE, or number of times)
#' @return Modified glyph_spec
#' @export
#'
#' @examples
#' # Entrance animation: bars grow from baseline
#' glyph(mtcars, x = cyl, y = mpg) |>
#'   mark_bar() |>
#'   animate(transition = "slide", stagger = 50)
#'
#' # Keyframe animation: morph between groups
#' glyph(mtcars, x = wt, y = mpg) |>
#'   mark_point(size = hp, color = cyl) |>
#'   animate(by = gear, transition = "morph", duration = 800)
animate <- function(spec,
                    transition = "morph",
                    duration = 500,
                    stagger = 0,
                    by = NULL,
                    easing = "ease-in-out",
                    loop = FALSE) {
  stopifnot(inherits(spec, "glyph_spec"))
  transition <- match.arg(transition, c("morph", "fade", "slide", "none"))
  easing <- match.arg(easing, c("linear", "ease-in", "ease-out",
                                 "ease-in-out", "bounce", "elastic"))

  by_expr <- if (!missing(by)) rlang::as_label(rlang::enquo(by)) else NULL

  spec$animate <- list(
    transition = transition,
    duration   = duration,
    stagger    = stagger,
    by         = by_expr,
    easing     = easing,
    loop       = loop
  )

  spec
}
