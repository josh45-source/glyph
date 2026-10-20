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
#' A glyph spec is a plain data structure, and nothing is drawn until the
#' `compile()` step resolves it into a concrete render tree. That means you
#' can:
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
  facet_fields <- c(facet_resolved$facets$cols, facet_resolved$facets$rows)
  resolved <- lapply(spec$marks, function(mark) {
    resolve_mark(mark, spec$data, spec$mappings, facet_resolved$generated,
                 facet_fields)
  })
  resolved_marks <- lapply(resolved, `[[`, "mark_json")
  for (r in resolved) {
    if (!is.null(r$enriched)) {
      new_cols <- setdiff(names(r$enriched), names(enriched_data))
      for (col in new_cols) enriched_data[[col]] <- r$enriched[[col]]
    }
  }
  # A mark can only refer to the plot's rows if every column it draws is
  # there with exactly its values (a column in the data could already have a
  # generated column's name); otherwise it sends its own copy, as every mark
  # used to.
  for (i in seq_along(resolved)) {
    d <- resolved_marks[[i]]$data
    if (!identical(d$from, "plot")) next
    same <- vapply(as.character(d$fields), function(f) {
      identical(enriched_data[[f]], resolved[[i]]$enriched[[f]])
    }, logical(1))
    if (!all(same)) resolved_marks[[i]]$data <- df_to_columns(resolved[[i]]$frame)
  }

  # Step 3: Auto-detect scale types from data (including computed mappings)
  resolved_scales <- resolve_scales(spec$scales, spec$mappings, spec$data)
  # A histogram's y axis shows counts, which no mapping names.
  is_histogram <- vapply(resolved_marks, function(m) identical(m$type, "histogram"),
                         logical(1))
  if (any(is_histogram) && is.null(resolved_scales$y)) {
    resolved_scales$y <- list(aesthetic = "y", type = "linear",
                              label = "count", nice = TRUE)
  }

  # Step 4: Choose which of the plot's own columns to send. A mark that
  # draws the plot's data (no per-mark `data`, no statistic) refers to these
  # rows instead of sending its own copy, so then every column is sent, as is
  # the case for keyframe animation, which reads them directly. Otherwise the
  # marks carry their own rows or summaries, and only what facet() and
  # marginals() read from the plot's data is sent; a plot of statistical
  # marks alone sends none of its raw rows.
  refers_to_plot <- vapply(resolved_marks, function(m) identical(m$data$from, "plot"), logical(1))
  top_fields <- if (any(refers_to_plot) || !is.null(spec$animate$by)) {
    names(enriched_data)
  } else {
    intersect(c(facet_fields, marginal_fields(spec$layout, resolved_marks)), names(enriched_data))
  }
  top_data <- if (length(top_fields) > 0) enriched_data[top_fields] else NULL

  # Step 5: Build the JSON specification
  json_spec <- list(
    `$schema` = "glyph/v0.2",
    width     = width %||% 600,
    height    = height %||% 400,
    data      = df_to_columns(top_data),
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
    `$schema`          = "glyph/v0.2",
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
resolve_mark <- function(mark, global_data, global_mappings, extra_cols = list(),
                         facet_fields = character()) {
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
  keep <- na_position_keep(work_data, encoding, position_aes, mark$id)
  if (!is.null(keep) && !all(keep)) work_data <- work_data[keep, , drop = FALSE]

  mark_json <- list(
    type     = mark$type,
    encoding = encoding,
    style    = mark$style,
    id       = mark$id,
    data     = df_to_columns(work_data)
  )

  # A mark drawing the plot's own rows doesn't send them again: it names the
  # columns it uses (in its own order) and, if rows were dropped for missing
  # values, which rows it keeps. compile.glyph_spec() sends those columns
  # once, at the top level, and the renderer rebuilds this mark's rows.
  if (uses_global_data && is.null(mark$stat) && !is.null(work_data)) {
    mark_json$data <- list(
      from   = "plot",
      fields = I(names(work_data)),
      rows   = if (is.null(keep) || all(keep)) NULL else I(which(keep) - 1L)
    )
  }

  # Statistical marks (boxplot, violin, histogram, sina, polygon) replace
  # their rows with computed summaries; see R/stats.R. Sina keeps one record
  # per row, sent as columns like any other rows.
  if (!is.null(mark$stat)) {
    if (is.null(work_data)) work_data <- data.frame()
    st <- compute_stat(mark, work_data, encoding, facet_fields)
    mark_json$encoding <- st$encoding
    mark_json$data <- if (!is.null(st$frame)) df_to_columns(st$frame) else list(values = st$records)
    mark_json$stat <- st$stat
  }

  list(mark_json = mark_json, enriched = enriched, frame = work_data)
}

#' Find rows with NA in any mapped position aesthetic, and warn
#' @return A logical vector, TRUE for the rows to keep, or NULL when there is
#'   no data.
#' @noRd
na_position_keep <- function(data, encoding, position_aes, mark_id) {
  if (is.null(data)) return(NULL)
  keep <- rep(TRUE, nrow(data))
  if (nrow(data) == 0) return(keep)

  pos_present <- intersect(position_aes, names(encoding))
  pos_fields <- lapply(pos_present, function(a) encoding[[a]]$field)
  names(pos_fields) <- pos_present
  pos_fields <- Filter(Negate(is.null), pos_fields)
  if (length(pos_fields) == 0) return(keep)

  na_flags <- lapply(pos_fields, function(f) is.na(data[[f]]))
  any_na <- Reduce(`|`, na_flags)
  n_dropped <- sum(any_na)
  if (n_dropped == 0) return(keep)

  offending <- names(pos_fields)[vapply(na_flags, any, logical(1))]
  cli::cli_warn(c(
    "!" = paste0(
      "Removed {n_dropped} row{?s} containing missing values ",
      "({.field {offending}}) from mark {.val {mark_id}}."
    )
  ))
  !any_na
}

#' Convert a data.frame to the columns sent to the browser
#' @description Data goes to the browser as one array per column, which
#'   jsonlite serializes hundreds of times faster than one object per row. It
#'   is a plain list, not a data.frame, so htmlwidgets can't reinterpret it,
#'   and the renderer (inflateSpec() in glyph.js) turns it back into one
#'   object per row before anything is drawn. A column of one value
#'   serializes as a bare value rather than an array; the renderer allows for
#'   that.
#' @return \code{list(columns = <named list of column vectors>, n = <rows>)}
#' @noRd
df_to_columns <- function(data) {
  if (is.null(data)) return(list(columns = structure(list(), names = character()), n = 0L))
  list(columns = as.list(data), n = nrow(data))
}

#' The fields marginals() reads from the plot's data: the first x and y
#' mapping among the marks, as the renderer's getPanelField() picks them.
#' @noRd
marginal_fields <- function(layout, marks) {
  if (!identical(layout$type, "marginals")) return(character())
  first_field <- function(aes) {
    for (m in marks) if (!is.null(m$encoding[[aes]]$field)) return(m$encoding[[aes]]$field)
    NULL
  }
  c(first_field("x"), first_field("y"))
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

#' Draw a glyph spec when it is printed
#'
#' @description A printed spec draws itself. At the console it opens in the
#'   viewer, and in R Markdown, Quarto and vignettes it is embedded in the
#'   document. Call [render()] only to set the width and height, and use
#'   [summary()][summary.glyph_spec] for a text description.
#'
#'   In a non-interactive session that isn't knitting a document, such as
#'   `Rscript`, there is nowhere to draw, so printing gives a one-line
#'   description instead.
#' @param x A glyph_spec object
#' @param ... Passed on to knitr when knitting; otherwise ignored.
#' @param options knitr chunk options, supplied by knitr.
#' @return `print()` invisibly returns `x`. `knit_print()` returns the
#'   rendered widget's HTML for knitr to include in the document.
#' @export
print.glyph_spec <- function(x, ...) {
  if (is_interactive()) {
    print(render(x))
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

#' @rdname print.glyph_spec
#' @exportS3Method knitr::knit_print
knit_print.glyph_spec <- function(x, ..., options = NULL) {
  knitr::knit_print(render(x), ..., options = options)
}

#' Is this an interactive session?
#' @description A wrapper around [interactive()] so tests can stub it.
#' @noRd
is_interactive <- function() {
  interactive()
}

#' Export to various formats
#'
#' @param spec A glyph_spec or glyph_compiled
#' @param file Output file path. Extension determines format. Currently
#'   implemented: `.html` (interactive widget) and `.json` (the compiled
#'   spec). Other extensions (`.svg`, `.png`, `.pdf`) are planned but not yet
#'   implemented, and currently just print a message.
#' @param width Width in pixels
#' @param height Height in pixels
#' @details
#' A single self-contained `.html` file needs [pandoc](https://pandoc.org).
#' RStudio ships with pandoc, so this works out of the box there; elsewhere,
#' install pandoc and make sure it is on your `PATH`. Without pandoc,
#' `export()` still writes the `.html` file but puts the JavaScript it needs
#' in a `<name>_files` folder next to it, and tells you so. Keep the two
#' together when moving or sharing the plot.
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
    if (has_pandoc()) {
      htmlwidgets::saveWidget(widget, file, selfcontained = TRUE)
      cli::cli_alert_success("Exported interactive HTML to {file}")
    } else {
      htmlwidgets::saveWidget(widget, file, selfcontained = FALSE)
      libdir <- paste0(tools::file_path_sans_ext(basename(file)), "_files")
      cli::cli_inform(c(
        "!" = "Exported interactive HTML to {.file {file}}, but not as a single self-contained file.",
        " " = "It needs the {.file {libdir}} folder next to it; keep the two together when moving or sharing it.",
        "i" = "Install pandoc ({.url https://pandoc.org/installing.html}) or run inside RStudio to get a single self-contained file instead."
      ))
    }
    return(invisible(file))
  }

  cli::cli_alert_info("Export to .{ext} uses the static engine (planned).")
  invisible(file)
}

#' Can a self-contained HTML file be written?
#' @description Uses the same check as `htmlwidgets::saveWidget()`, which also
#'   finds the copy of pandoc bundled with RStudio. A separate function so
#'   tests can stub it.
#' @noRd
has_pandoc <- function() {
  requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available()
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
