#' @title Rendering Pipeline
#' @name rendering
#' @description The rendering pipeline compiles a glyph_spec into output.
#'   The spec is first resolved (evaluate quosures, compute stats, merge
#'   defaults), then serialized to JSON, then handed to a backend:
#'
#'   - **"html"** (default): htmlwidgets + D3.js for interactive viewing
#'   - **"svg"**: Static SVG file (publication quality)
#'   - **"canvas"**: HTML5 Canvas for large-data performance
#'   - **"webgl"**: WebGL via regl/deck.gl for 100K+ points (planned)
#'   - **"pdf"**: Direct PDF output via R's pdf() device (planned)
#'
#' @details
#' Key architectural difference from ggplot2: the spec is a pure data
#' structure. The `compile()` step resolves it into a concrete render tree.
#' This means you can:
#' - Inspect the compiled spec as JSON (for debugging or export)
#' - Serialize it and render on a different machine
#' - Export it to Vega-Lite JSON (near 1:1 mapping)
#' - Compile to multiple backends from one spec
NULL

#' Compile a glyph spec to a resolved representation
#'
#' @param spec A glyph_spec or glyph_layout
#' @param engine Rendering backend: "auto", "html", "svg", "canvas", "webgl"
#' @param width Width in pixels (NULL for auto)
#' @param height Height in pixels (NULL for auto)
#' @return A `glyph_compiled` object (a list with resolved data + JSON)
#' @export
compile <- function(spec, engine = "auto", width = NULL, height = NULL) {
  UseMethod("compile")
}

#' @rdname compile
#' @return A \code{glyph_compiled} object containing the resolved spec,
#'   JSON string, and engine selection
#' @export
compile.glyph_spec <- function(spec, engine = "auto",
                                width = NULL, height = NULL) {
  # Step 1: Choose engine based on data size if auto

if (engine == "auto") {
    n <- if (!is.null(spec$data)) nrow(spec$data) else 0
    engine <- if (n > 100000) "webgl" else if (n > 10000) "canvas" else "html"
  }

  # Step 2: Resolve aesthetic mappings (evaluate quosures against data)
  resolved_marks <- lapply(spec$marks, function(mark) {
    resolve_mark(mark, spec$data, spec$mappings)
  })

  # Step 3: Auto-detect scale types from data
  resolved_scales <- resolve_scales(spec$scales, spec$mappings, spec$data)

  # Step 4: Build the JSON specification
  json_spec <- list(
    `$schema` = "glyph/v0.1",
    width     = width %||% 600,
    height    = height %||% 400,
    data      = list(values = df_to_records(spec$data)),
    marks     = resolved_marks,
    scales    = resolved_scales,
    coords    = spec$coords,
    facets    = spec$facets,
    interact  = spec$interact,
    animate   = spec$animate,
    theme     = spec$theme,
    layout    = resolve_layout(spec$layout, engine),
    engine    = engine
  )

  structure(
    list(
      spec     = json_spec,
      json     = jsonlite::toJSON(json_spec, auto_unbox = TRUE, null = "null"),
      engine   = engine,
      original = spec
    ),
    class = "glyph_compiled"
  )
}

#' @rdname compile
#' @return A \code{glyph_compiled} object containing the resolved layout spec
#'   and JSON string
#' @export
compile.glyph_layout <- function(spec, engine = "auto",
                                  width = NULL, height = NULL) {
  compiled_panels <- lapply(spec$plots, compile,
                             engine = engine, width = width, height = height)

  json_spec <- list(
    `$schema`          = "glyph/v0.1",
    type               = "layout",
    layout_type        = spec$type,
    panels             = lapply(compiled_panels, function(c) c$spec),
    widths             = spec$widths,
    heights            = spec$heights,
    gap                = spec$gap,
    shared_scales      = spec$shared_scales,
    linked_selections  = spec$linked_selections,
    title              = spec$title
  )

  structure(
    list(
      spec   = json_spec,
      json   = jsonlite::toJSON(json_spec, auto_unbox = TRUE, null = "null"),
      engine = engine
    ),
    class = "glyph_compiled"
  )
}

# ---- Resolve helpers ---------------------------------------------------------

#' @noRd
resolve_mark <- function(mark, global_data, global_mappings) {
  data <- mark$data %||% global_data
  all_mappings <- utils::modifyList(global_mappings, mark$mappings)

  # Evaluate each mapping against the data
  encoding <- list()
  for (nm in names(all_mappings)) {
    m <- all_mappings[[nm]]
    expr_str <- m$expr

    # Check if it's a data column or a computed expression
    if (!is.null(data) && expr_str %in% names(data)) {
      col <- data[[expr_str]]
      encoding[[nm]] <- list(
        field = expr_str,
        type  = infer_field_type(col)
      )
    } else {
      # Might be a template string (for tooltips) or expression
      encoding[[nm]] <- list(
        expr = expr_str,
        type = "expression"
      )
    }
  }

  list(
    type     = mark$type,
    encoding = encoding,
    style    = mark$style,
    id       = mark$id
  )
}

#' Convert a data.frame to a list of row-records
#' @description htmlwidgets serializes embedded \code{x} payloads with
#'   \code{jsonlite}'s \code{dataframe = "columns"} default, which would turn
#'   a data.frame into one JSON object per column instead of one JSON object
#'   per row. The D3 renderer expects an array of row objects (so it can call
#'   \code{data.map(...)} etc.), so convert explicitly here rather than
#'   relying on the data.frame passing through untouched.
#' @noRd
df_to_records <- function(data) {
  if (is.null(data) || nrow(data) == 0) return(list())
  lapply(seq_len(nrow(data)), function(i) as.list(data[i, , drop = FALSE]))
}

#' @noRd
infer_field_type <- function(x) {
  if (inherits(x, c("Date", "POSIXt"))) return("temporal")
  if (is.numeric(x)) return("quantitative")
  if (is.factor(x) || is.character(x)) return("nominal")
  if (is.ordered(x)) return("ordinal")
  "nominal"
}

#' @noRd
resolve_scales <- function(scales, mappings, data) {
  # Auto-create scales for mapped aesthetics if not explicitly defined
  resolved <- scales
  for (nm in names(mappings)) {
    if (is.null(resolved[[nm]])) {
      expr_str <- mappings[[nm]]$expr
      if (!is.null(data) && expr_str %in% names(data)) {
        ftype <- infer_field_type(data[[expr_str]])
        resolved[[nm]] <- list(
          aesthetic = nm,
          type      = switch(ftype,
            quantitative = "linear",
            temporal     = "time",
            nominal      = "ordinal",
            ordinal      = "ordinal",
            "linear"
          ),
          label = expr_str,
          nice  = TRUE
        )
      }
    }
  }
  resolved
}

#' Resolve the marginals/inset layout attached to a spec
#' @description \code{marginals()} and \code{inset()} both stash their
#'   config on \code{spec$layout}. \code{inset()} additionally embeds a full
#'   nested \code{glyph_spec} (with unresolved quosures), which must be
#'   compiled recursively before it can be serialized to JSON.
#' @noRd
resolve_layout <- function(layout, engine) {
  if (is.null(layout)) return(NULL)

  if (identical(layout$type, "inset")) {
    layout$inset <- compile(layout$inset, engine = engine)$spec
  }

  layout
}

# ---- Display methods ---------------------------------------------------------

#' Render a glyph spec as an htmlwidget
#'
#' @param spec A glyph_spec, glyph_layout, or glyph_compiled
#' @param width Widget width
#' @param height Widget height
#' @return An \code{htmlwidget} object that renders the visualization
#'   in an HTML viewer
#' @export
render <- function(spec, width = NULL, height = NULL) {
  if (!inherits(spec, "glyph_compiled")) {
    spec <- compile(spec, width = width, height = height)
  }

  htmlwidgets::createWidget(
    name    = "glyph",
    x       = list(spec = spec$spec),
    width   = width,
    height  = height,
    package = "glyph",
    sizingPolicy = htmlwidgets::sizingPolicy(
      defaultWidth  = spec$spec$width  %||% 600,
      defaultHeight = spec$spec$height %||% 400,
      viewer.fill   = TRUE,
      browser.fill  = TRUE,
      knitr.figure  = FALSE,
      knitr.defaultWidth  = "100%",
      knitr.defaultHeight = paste0(spec$spec$height %||% 400, "px")
    )
  )
}

#' Auto-render when printed (like ggplot2)
#' @param x A glyph_spec object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns the glyph_spec object
#' @export
print.glyph_spec <- function(x, ...) {
  if (base::interactive()) {
    widget <- render(x)
    print(widget)
  } else {
    n_marks <- length(x$marks)
    data_desc <- if (is.null(x$data)) {
      "no data"
    } else {
      paste0(nrow(x$data), " x ", ncol(x$data))
    }
    cat(sprintf("<glyph_spec: %s, %d mark(s)>\n", data_desc, n_marks))
  }
  invisible(x)
}

#' Export to various formats
#'
#' @param spec A glyph_spec or glyph_compiled
#' @param file Output file path. Extension determines format:
#'   .html, .svg, .png, .pdf, .json (exports the raw spec)
#' @param width Width in pixels
#' @param height Height in pixels
#' @return Invisibly returns the output file path
#' @export
export <- function(spec, file, width = 800, height = 600) {
  ext <- tools::file_ext(file)

  if (ext == "json") {
    compiled <- if (inherits(spec, "glyph_compiled")) spec else compile(spec)
    writeLines(compiled$json, file)
    cli::cli_alert_success("Exported spec to {file}")
    return(invisible(file))
  }

  if (ext == "html") {
    widget <- render(spec, width = width, height = height)
    htmlwidgets::saveWidget(widget, file, selfcontained = TRUE)
    cli::cli_alert_success("Exported interactive HTML to {file}")
    return(invisible(file))
  }

  cli::cli_alert_info("Export to .{ext} uses the static engine (planned).")
  invisible(file)
}

#' Export the spec as Vega-Lite JSON (interop)
#'
#' @description Because glyph's spec is structurally similar to Vega-Lite,
#'   we can export to Vega-Lite JSON for use in Python (Altair), JavaScript,
#'   or the Vega Editor.
#' @param spec A glyph_spec
#' @return A JSON string in Vega-Lite format
#' @export
to_vegalite <- function(spec) {
  compiled <- compile(spec)
  # Transform glyph spec → Vega-Lite spec
  # (This is a simplified mapping; a full implementation would handle
  #  all mark types, scales, and interactions)
  vl <- list(
    `$schema` = "https://vega.github.io/schema/vega-lite/v5.json",
    data      = list(values = spec$data)
  )

  if (length(compiled$spec$marks) == 1) {
    mark <- compiled$spec$marks[[1]]
    vl$mark <- mark$type
    vl$encoding <- mark$encoding
  }

  jsonlite::toJSON(vl, auto_unbox = TRUE, pretty = TRUE)
}
