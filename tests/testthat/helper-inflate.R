# Rebuilds row records from a compiled spec the way the renderer does
# (inflateSpec() in inst/htmlwidgets/glyph.js), so tests can look at the rows
# each mark draws.

columns_to_rows <- function(columns, n, fields = NULL, rows = NULL) {
  fields <- if (is.null(fields)) names(columns) else as.character(fields)
  index <- if (is.null(rows)) seq_len(n) else as.integer(rows) + 1L
  lapply(index, function(i) {
    row <- lapply(fields, function(f) columns[[f]][i])
    names(row) <- fields
    row
  })
}

inflate_spec <- function(spec) {
  if (identical(spec$type, "layout")) {
    spec$panels <- lapply(spec$panels, inflate_spec)
    return(spec)
  }
  top <- spec$data
  for (i in seq_along(spec$marks)) {
    d <- spec$marks[[i]]$data
    if (identical(d$from, "plot")) {
      spec$marks[[i]]$data <- list(values = columns_to_rows(top$columns, top$n, d$fields, d$rows))
    } else if (!is.null(d$columns)) {
      spec$marks[[i]]$data <- list(values = columns_to_rows(d$columns, d$n))
    }
  }
  spec$data <- list(values = columns_to_rows(top$columns, top$n))
  if (!is.null(spec$layout$inset)) spec$layout$inset <- inflate_spec(spec$layout$inset)
  spec
}

inflated <- function(compiled) inflate_spec(compiled$spec)

# The row records every mark used to send, one list per row, for comparison.
old_records <- function(data) {
  if (is.null(data) || nrow(data) == 0) return(list())
  lapply(seq_len(nrow(data)), function(i) as.list(data[i, , drop = FALSE]))
}

# Serializes the way htmlwidgets does when it embeds a widget's data.
widget_json <- function(x) htmlwidgets:::toJSON(x)

# Rebuilds rows from the JSON the browser receives, the way inflateSpec()
# does in JavaScript: a column of one value arrives as a bare value.
rows_from_json <- function(payload, fields = NULL, rows = NULL) {
  as_array <- function(v) if (is.list(v)) v else list(v)
  fields <- if (is.null(fields)) names(payload$columns) else unlist(as_array(fields))
  index <- if (is.null(rows)) seq_len(payload$n) else unlist(as_array(rows)) + 1L
  cols <- lapply(fields, function(f) as_array(payload$columns[[f]]))
  lapply(index, function(i) {
    row <- lapply(cols, function(col) col[[i]])
    names(row) <- fields
    row
  })
}
