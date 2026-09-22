#' @keywords internal
#' @aliases glyph-package
#' @section Acknowledgements:
#' glyph's design draws directly on the ideas and prior art of others:
#'
#' - **Leland Wilkinson's *The Grammar of Graphics*** — the layered
#'   data/mark/scale vocabulary that glyph's spec is structured around.
#' - **ggplot2** — the aesthetic-mapping model (`aes()`, here bare names
#'   instead) and the pipeline style of building a plot up in layers.
#' - **Vega-Lite** — the idea of a declarative, serializable JSON spec that
#'   compiles to a render tree, and treating interactions as selections.
#' - **ggvis** — an earlier reactive, D3-backed grammar of graphics for R;
#'   glyph's D3-via-htmlwidgets rendering follows the same path.
#' - **ggiraph** — ggplot2 output with D3-powered tooltips, hover, and
#'   selection; a direct influence on glyph's own tooltip/hover/brush model.
#' - **plotly** — the baseline for what an "interactive R plot" should
#'   offer (zoom, pan, tooltips), which glyph aims to provide natively.
#' - **patchwork** — the model for glyph's [compose()] multi-plot layout API.
#' - **gganimate** — the `transition_states()`-style keyframe grammar behind
#'   `animate(by = ..., transition = "morph")`.
#' - **ggExtra** — the marginal histogram/density/boxplot pattern behind
#'   [marginals()].
#' - **ggrepel** — the inspiration for `mark_text(smart_repel = TRUE)`'s
#'   label decluttering (glyph uses a simpler iterative pairwise-nudge
#'   approach rather than ggrepel's force simulation — see [mark_text()]).
#'
#' This package also bundles [D3.js](https://d3js.org) (Copyright Mike
#' Bostock, ISC License); see `inst/COPYRIGHTS` for the full notice.
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang `%||%`
#' @importFrom jsonlite toJSON
#' @importFrom htmlwidgets createWidget
#' @importFrom cli cli_h1 cli_bullets cli_abort cli_alert_success cli_alert_info
## usethis namespace: end
NULL
