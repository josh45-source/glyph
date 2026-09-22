#' @title Rendering Pipeline
#' @name rendering
#' @description The rendering pipeline compiles a glyph_spec into output.
#'   The spec is first resolved (evaluate quosures, drop rows with missing
#'   mapped values, merge defaults), then serialized to JSON, then handed to
#'   a backend:
#'
#'   - **"html"** (default): htmlwidgets + D3.js for interactive viewing.
#'     This is currently the only implemented renderer; the visual output is
#'     SVG, drawn by D3 inside the widget.
#'   - **"svg"**, **"canvas"**, **"webgl"**, **"pdf"**: standalone static/
#'     large-data export backends. Planned, not yet implemented.
#'
#' @details
#' Key architectural difference from ggplot2: the spec is a pure data
#' structure. The `compile()` step resolves it into a concrete render tree.
#' This means you can:
#' - Inspect the compiled spec as JSON (for debugging or export)
#' - Serialize it and render on a different machine
#' - Export it to Vega-Lite JSON (near 1:1 mapping)
#' - Add new backends later without changing the user-facing spec API
NULL

#' Compile a glyph spec to a resolved representation
#'
#' @param spec A glyph_spec or glyph_layout
#' @param engine Rendering backend. Only `"html"` (D3.js via htmlwidgets) is
#'   currently implemented; `"auto"` resolves to `"html"`. Other values are
#'   rejected — earlier versions accepted `"canvas"`/`"webgl"` and silently
#'   ignored them (no such renderer ever existed), which was misleading.
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
  # Only "html" (D3/htmlwidgets) is actually implemented — there is no
  # canvas/webgl renderer to auto-select between by data size, so "engine"
  # no longer does anything except resolve "auto" -> "html" and reject
  # unsupported values explicitly instead of silently accepting them.
  engine <- match.arg(engine, c("auto", "html"))
  if (engine == "auto") engine <- "html"

  # Step 1: Resolve the facet variables (rows/cols), if any — like an
  # aesthetic mapping, `facet(cols = factor(cyl))` is a computed expression
  # that has to be evaluated, not a literal column name. Any generated
  # column is added to the top-level data (so the JS side can enumerate
  # facet values from it) and threaded into every mark's own per-mark data
  # below (so each facet panel can filter *that mark's* resolved rows —
  # computed columns and NA-dropped rows included — instead of falling back
  # to an unresolved, unfiltered slice of the shared data).
  facet_resolved <- resolve_facets(spec$facets, spec$data)
  enriched_data <- facet_resolved$data

  # Step 2: Resolve aesthetic mappings (evaluate quosures against data,
  # including computed expressions like `x = log(wt)`; drop rows with NA in
  # a mapped position aesthetic). Marks that map from the spec's own data
  # (not a per-mark `data` override) may generate new columns (e.g. for
  # `log(wt)`) — those are folded back into `enriched_data` so the top-level
  # serialized `data` (used by facets/marginals) also has them.
  resolved <- lapply(spec$marks, function(mark) {
    resolve_mark(mark, spec$data, spec$mappings, facet_resolved$generated)
  })
  resolved_marks <- lapply(resolved, `[[`, "mark_json")
  for (r in resolved) {
    if (!is.null(r$enriched)) {
      new_cols <- setdiff(names(r$enriched), names(enriched_data))
      for (col in new_cols) enriched_data[[col]] <- r$enriched[[col]]
    }
  }

  # Step 3: Auto-detect scale types from data (including computed mappings)
  resolved_scales <- resolve_scales(spec$scales, spec$mappings, spec$data)

  # Step 4: Build the JSON specification
  json_spec <- list(
    `$schema` = "glyph/v0.1",
    width     = width %||% 600,
    height    = height %||% 400,
    data      = list(values = df_to_records(enriched_data)),
    marks     = resolved_marks,
    scales    = resolved_scales,
    coords    = spec$coords,
    facets    = facet_resolved$facets,
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

#' Evaluate a captured mapping (quosure) against `data`
#' @description A mapping like \code{x = wt} is a plain column reference; one
#'   like \code{x = log(wt)} or \code{color = factor(cyl)} is a computed
#'   expression that has to be evaluated with \code{\link[rlang]{eval_tidy}}
#'   before it means anything. Returns \code{NULL} when the mapping can't be
#'   resolved to one value per row of \code{data} — e.g. a template string
#'   like \code{"{mpg} mpg"}, an unresolvable expression, or an aggregate
#'   that doesn't return a per-row vector — so the caller can fall back to
#'   treating it as an opaque expression, same as before.
#' @noRd
eval_mapping_value <- function(m, data) {
  expr_str <- m$expr
  if (!is.null(data) && expr_str %in% names(data)) {
    return(list(value = data[[expr_str]], computed = FALSE))
  }
  n <- if (!is.null(data)) nrow(data) else 0L
  if (n == 0) return(NULL)
  val <- tryCatch(rlang::eval_tidy(m$quosure, data = data), error = function(e) NULL)
  if (!is.null(val) && length(val) == n) {
    return(list(value = val, computed = TRUE))
  }
  NULL
}

#' Resolve facet(rows =, cols =) into concrete field names
#' @description Mirrors \code{eval_mapping_value()}: a facet variable can be
#'   a plain column (\code{facet(cols = cyl)}) or a computed expression
#'   (\code{facet(cols = factor(cyl))}). The former just needs its name; the
#'   latter has to be evaluated once against \code{data} and given a field
#'   name of its own, since the JS side facets by looking up
#'   \code{d[facets.cols]} on each row and a raw expression string like
#'   \code{"factor(cyl)"} was never going to be a real column.
#' @return A list with \code{facets} (the resolved facets list — same shape
#'   as \code{spec$facets} but with \code{rows}/\code{cols} always a plain
#'   field name string, or \code{NULL}), \code{data} (\code{data} with any
#'   generated column(s) added), and \code{generated} (a named list of the
#'   generated column(s) alone, so callers that don't already have the
#'   enriched \code{data} — namely each mark — can merge them in too).
#' @noRd
resolve_facets <- function(facets, data) {
  if (is.null(facets)) return(list(facets = NULL, data = data, generated = list()))

  generated <- list()
  resolve_one <- function(fvar, which) {
    if (is.null(fvar)) return(NULL)
    if (!is.null(data) && fvar$expr %in% names(data)) return(fvar$expr)

    n <- if (!is.null(data)) nrow(data) else 0L
    val <- if (n > 0) {
      tryCatch(rlang::eval_tidy(fvar$quosure, data = data), error = function(e) NULL)
    } else {
      NULL
    }
    if (!is.null(val) && length(val) == n) {
      field_name <- paste0(".g_facet_", which)
      generated[[field_name]] <<- val
      return(field_name)
    }

    # Unresolvable (e.g. references a name that doesn't exist anywhere) —
    # fall back to the raw expression text so this degrades the same way
    # an unresolvable aesthetic mapping does, rather than erroring.
    fvar$expr
  }

  cols_field <- resolve_one(facets$cols, "cols")
  rows_field <- resolve_one(facets$rows, "rows")

  data_out <- data
  for (fn in names(generated)) data_out[[fn]] <- generated[[fn]]

  list(
    facets = list(
      cols        = cols_field,
      rows        = rows_field,
      free_scales = facets$free_scales,
      wrap        = facets$wrap
    ),
    data = data_out,
    generated = generated
  )
}

#' @noRd
resolve_mark <- function(mark, global_data, global_mappings, extra_cols = list()) {
  mark_data <- mark$data %||% global_data
  uses_global_data <- is.null(mark$data)
  all_mappings <- utils::modifyList(global_mappings, mark$mappings)

  # Evaluate each mapping against the data. A computed expression that
  # resolves to a per-row vector becomes a generated column (e.g. field
  # ".g_point_1_x" for `x = log(wt)`); the expression text becomes the
  # default label used for axis/legend titles in resolve_scales().
  encoding <- list()
  generated_cols <- list()
  for (nm in names(all_mappings)) {
    m <- all_mappings[[nm]]
    expr_str <- m$expr
    resolved <- eval_mapping_value(m, mark_data)

    if (is.null(resolved)) {
      # Might be a template string (for tooltips) or an expression that
      # can't be evaluated per-row — unchanged fallback behavior.
      encoding[[nm]] <- list(expr = expr_str, type = "expression")
    } else if (resolved$computed) {
      field_name <- sprintf(".g_%s_%s", mark$id, nm)
      generated_cols[[field_name]] <- resolved$value
      encoding[[nm]] <- list(
        field = field_name,
        type  = infer_field_type(resolved$value),
        label = expr_str
      )
    } else {
      encoding[[nm]] <- list(
        field = expr_str,
        type  = infer_field_type(resolved$value),
        label = expr_str
      )
    }
  }

  # Attach any generated columns to a working copy of this mark's data so
  # they can be serialized (compile.glyph_spec() attaches the result as
  # this mark's own `data` in the compiled JSON). A computed facet variable
  # (extra_cols, from resolve_facets()) is folded in here too — only for
  # marks using the spec's own data, same condition as `enriched` below —
  # so the JS renderer can filter *this mark's* resolved rows by facet
  # value directly, instead of only the shared top-level data.
  work_data <- mark_data
  all_generated <- if (uses_global_data) c(generated_cols, extra_cols) else generated_cols
  if (length(all_generated) > 0) {
    if (is.null(work_data)) {
      work_data <- as.data.frame(all_generated, stringsAsFactors = FALSE)
    } else {
      for (fn in names(all_generated)) work_data[[fn]] <- all_generated[[fn]]
    }
  }

  # Marks using the spec's own data (no per-mark `data` override) can fold
  # their generated columns back into the shared top-level data, so facets
  # and marginals (which read the top-level `data`, not a per-mark one) see
  # them too. A per-mark data override can't be folded back this way — only
  # spec$data is serialized at the top level — but that combination was
  # already unsupported before this change.
  enriched <- if (uses_global_data) work_data else NULL

  # Drop rows with NA in a mapped position aesthetic — better to omit a mark
  # than draw it at an invalid position — and warn how many/why, ggplot2-style.
  position_aes <- c("x", "y", "x2", "y2", "y_min", "y_max")
  work_data <- drop_na_position_rows(work_data, encoding, position_aes, mark$id)

  list(
    mark_json = list(
      type     = mark$type,
      encoding = encoding,
      style    = mark$style,
      id       = mark$id,
      data     = list(values = df_to_records(work_data))
    ),
    enriched = enriched
  )
}

#' Drop rows with NA in any mapped position aesthetic and warn
#' @noRd
drop_na_position_rows <- function(data, encoding, position_aes, mark_id) {
  if (is.null(data) || nrow(data) == 0) return(data)

  pos_present <- intersect(position_aes, names(encoding))
  pos_fields <- lapply(pos_present, function(a) encoding[[a]]$field)
  names(pos_fields) <- pos_present
  pos_fields <- Filter(Negate(is.null), pos_fields)
  if (length(pos_fields) == 0) return(data)

  na_flags <- lapply(pos_fields, function(f) is.na(data[[f]]))
  any_na <- Reduce(`|`, na_flags)
  n_dropped <- sum(any_na)
  if (n_dropped == 0) return(data)

  offending <- names(pos_fields)[vapply(na_flags, any, logical(1))]
  cli::cli_warn(c(
    "!" = paste0(
      "Removed {n_dropped} row{?s} containing missing values ",
      "({.field {offending}}) from mark {.val {mark_id}}."
    )
  ))
  data[!any_na, , drop = FALSE]
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
  # Auto-create scales for mapped aesthetics if not explicitly defined.
  # Computed expressions (e.g. `x = log(wt)`) are evaluated the same way as
  # in resolve_mark() so their type can be inferred and the expression text
  # used as the default axis/legend label — previously only plain column
  # mappings got a label at all here, so a computed x/y axis rendered with
  # no label text.
  resolved <- scales
  for (nm in names(mappings)) {
    if (is.null(resolved[[nm]])) {
      m <- mappings[[nm]]
      ev <- eval_mapping_value(m, data)
      if (!is.null(ev)) {
        ftype <- infer_field_type(ev$value)
        resolved[[nm]] <- list(
          aesthetic = nm,
          type      = switch(ftype,
            quantitative = "linear",
            temporal     = "time",
            nominal      = "ordinal",
            ordinal      = "ordinal",
            "linear"
          ),
          label = m$expr,
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
#' @param file Output file path. Extension determines format. Currently
#'   implemented: `.html` (self-contained interactive widget) and `.json`
#'   (the compiled spec). Other extensions (`.svg`, `.png`, `.pdf`) are
#'   planned but not yet implemented, and currently just print a message.
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
