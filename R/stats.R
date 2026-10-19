# ---- Statistical marks --------------------------------------------------------
#
# mark_boxplot(), mark_violin(), mark_histogram() and mark_sina() are computed
# here, in R, when the spec is compiled. resolve_mark() has already evaluated
# the mappings (including computed ones like `x = factor(cyl)`), added any
# computed facet column and dropped rows with NA in a position aesthetic, so
# the statistics only ever see clean rows.
#
# Boxplot, violin and histogram marks are replaced by one record per summary
# element (a box, a violin, a bin). Each record keeps the grouping columns
# (x, color and facet fields) under their original names, so the renderer's
# scales, colour scale and facet filtering work on it unchanged, plus `.rows`:
# the 0-based indices of the rows it summarises. The renderer uses `.rows` to
# connect a summary element to row-level selections from brushing and
# crossfilter. Sina marks keep one record per row and add the position offsets.
#
# mark_polygon() uses the same machinery without computing any statistic: its
# rows are vertices, and they are collected into one record per polygon (see
# stat_polygon() below) so that tooltips, brushing and crossfilter treat a
# polygon as one element that draws many rows.

#' Apply a mark's statistic to its resolved rows
#' @param mark The mark as stored in the spec (`mark$stat` holds the type and
#'   parameters).
#' @param data The mark's resolved rows (after NA dropping).
#' @param encoding The mark's resolved encoding.
#' @param facet_fields Facet field names to group by, if any.
#' @return A list with `records` (row records for the JSON), `encoding`
#'   (updated encoding) and `stat` (what the renderer needs to know).
#' @noRd
compute_stat <- function(mark, data, encoding, facet_fields = character()) {
  stat <- mark$stat
  facet_fields <- intersect(facet_fields, names(data))
  switch(stat$type,
    boxplot   = stat_boxplot(mark, data, encoding, facet_fields),
    violin    = stat_violin(mark, data, encoding, facet_fields),
    sina      = stat_sina(mark, data, encoding, facet_fields),
    histogram = stat_histogram(mark, data, encoding, facet_fields),
    polygon   = stat_polygon(mark, data, encoding, facet_fields)
  )
}

# The numeric variable a statistic summarises, with a clear error when it's
# missing or not numeric.
stat_values <- function(data, encoding, aes, mark) {
  field <- encoding[[aes]]$field
  fn <- paste0("mark_", mark$stat$type, "()")
  if (is.null(field)) {
    cli::cli_abort("{.fn {fn}} needs a numeric {.field {aes}} mapping.")
  }
  values <- if (nrow(data) > 0) data[[field]] else numeric()
  if (!is.numeric(values)) {
    cli::cli_abort(c(
      "{.fn {fn}} needs a numeric {.field {aes}} mapping.",
      "x" = "{.field {encoding[[aes]]$label %||% field}} is {.cls {class(values)[1]}}."
    ))
  }
  values
}

# Levels of a grouping column, in display order: factor levels that occur in
# the data, otherwise the sorted unique values. A missing value is a group of
# its own, placed last, so rows with a missing colour or group aren't
# silently left out.
group_levels <- function(x) {
  lev <- if (is.factor(x)) levels(droplevels(x)) else sort(unique(x))
  if (anyNA(x)) lev <- c(lev, NA)
  lev
}

# Makes sure a box/violin/sina mark has a discrete x to group on. Without an
# x mapping every row goes in one group, labelled with the y variable's name.
# Returns the (possibly extended) data and encoding.
ensure_group_x <- function(mark, data, encoding) {
  if (is.null(encoding$x$field)) {
    field <- sprintf(".g_%s_x", mark$id)
    data[[field]] <- rep(encoding$y$label %||% encoding$y$field, nrow(data))
    encoding$x <- list(field = field, type = "nominal", label = NULL)
  }
  x <- data[[encoding$x$field]]
  encoding$x$type <- "nominal"
  encoding$x$domain <- I(group_levels(x))
  list(data = data, encoding = encoding)
}

# Position of each group within its x band. When colour is mapped to a
# different field than x, groups are placed side by side ("dodged") within the
# band, one slot per colour level; otherwise each group fills the band.
# Returns a function of the colour value giving list(xc, xw) as fractions of
# the band: xc is the centre, xw the width.
dodge_positions <- function(data, encoding, width) {
  color_field <- encoding$color$field
  # Colour mapped to the same variable as x only colours the groups. Two
  # computed mappings of one expression (x = factor(cyl), color = factor(cyl))
  # get different generated fields, so compare the expressions too.
  same_as_x <- identical(color_field, encoding$x$field) ||
    (!is.null(encoding$color$label) && identical(encoding$color$label, encoding$x$label))
  if (is.null(color_field) || same_as_x) {
    return(function(color_value) list(xc = 0.5, xw = width))
  }
  lev <- group_levels(data[[color_field]])
  m <- length(lev)
  function(color_value) {
    k <- match(color_value, lev)
    list(xc = (k - 0.5) / m, xw = width / m)
  }
}

# Splits row indices into groups by the given fields, in level order.
# Returns a list of integer vectors (1-based row indices into `data`).
split_rows <- function(data, fields) {
  idx <- seq_len(nrow(data))
  if (length(fields) == 0 || nrow(data) == 0) return(list(idx))
  # Group by each value's position in group_levels(), so a missing value
  # (which factor() would drop) forms its own group.
  keys <- lapply(fields, function(f) {
    lev <- group_levels(data[[f]])
    factor(match(data[[f]], lev), levels = seq_along(lev))
  })
  groups <- split(idx, keys, drop = TRUE, lex.order = TRUE)
  unname(groups[lengths(groups) > 0])
}

# The grouping columns of the first row in `rows`, kept with their original
# class so they serialize exactly like the same columns in the plot's data.
group_columns <- function(data, fields, rows) {
  out <- lapply(fields, function(f) data[[f]][rows[1]])
  names(out) <- fields
  out
}

stat_boxplot <- function(mark, data, encoding, facet_fields) {
  params <- mark$stat
  y <- stat_values(data, encoding, "y", mark)
  g <- ensure_group_x(mark, data, encoding)
  data <- g$data
  encoding <- g$encoding

  fields <- unique(c(encoding$x$field, encoding$color$field, facet_fields))
  dodge <- dodge_positions(data, encoding, params$width)

  records <- lapply(split_rows(data, fields), function(rows) {
    v <- y[rows]
    q <- stats::quantile(v, c(0.25, 0.5, 0.75), names = FALSE, type = 7)
    iqr <- q[3] - q[1]
    lo <- q[1] - params$coef * iqr
    hi <- q[3] + params$coef * iqr
    inside <- v[v >= lo & v <= hi]
    outliers <- if (isTRUE(params$outliers)) sort(v[v < lo | v > hi]) else numeric()
    pos <- dodge(if (is.null(encoding$color$field)) NULL else data[[encoding$color$field]][rows[1]])
    c(
      group_columns(data, fields, rows),
      list(
        .n = length(v),
        .lower = q[1], .middle = q[2], .upper = q[3],
        .ymin = min(inside), .ymax = max(inside),
        .outliers = I(outliers),
        .xc = pos$xc, .xw = pos$xw,
        .rows = I(rows - 1L)
      )
    )
  })

  list(records = records, encoding = encoding, stat = list(type = "boxplot"))
}

# Kernel density of each group, trimmed to the group's range. Groups with
# fewer than two distinct values have no density and are left out, with a
# warning. Returns list(groups = list of list(rows, dens)), max density).
group_densities <- function(mark, data, y, fields) {
  params <- mark$stat
  groups <- split_rows(data, fields)
  dens <- lapply(groups, function(rows) {
    v <- y[rows]
    if (length(unique(v)) < 2) return(NULL)
    stats::density(v, bw = params$bw, adjust = params$adjust,
                   n = 64, from = min(v), to = max(v))
  })
  n_dropped <- sum(vapply(dens, is.null, logical(1)))
  if (n_dropped > 0) {
    cli::cli_warn(c(
      "!" = paste0(
        "{n_dropped} group{?s} in mark {.val {mark$id}} ",
        "{cli::qty(n_dropped)}{?has/have} fewer than two distinct values, ",
        "so no density can be drawn."
      )
    ))
  }
  dens_max <- max(c(0, unlist(lapply(dens, function(d) if (!is.null(d)) max(d$y)))))
  list(groups = groups, dens = dens, max = dens_max)
}

stat_violin <- function(mark, data, encoding, facet_fields) {
  params <- mark$stat
  y <- stat_values(data, encoding, "y", mark)
  g <- ensure_group_x(mark, data, encoding)
  data <- g$data
  encoding <- g$encoding

  fields <- unique(c(encoding$x$field, encoding$color$field, facet_fields))
  dodge <- dodge_positions(data, encoding, params$width)
  dd <- group_densities(mark, data, y, fields)

  records <- list()
  for (i in seq_along(dd$groups)) {
    d <- dd$dens[[i]]
    if (is.null(d)) next
    rows <- dd$groups[[i]]
    v <- y[rows]
    pos <- dodge(if (is.null(encoding$color$field)) NULL else data[[encoding$color$field]][rows[1]])
    records[[length(records) + 1]] <- c(
      group_columns(data, fields, rows),
      list(
        .n = length(v),
        .middle = stats::median(v),
        .ymin = min(v), .ymax = max(v),
        .dens_y = I(d$x),
        # Scaled by the largest density in the mark, so every violin is drawn
        # on the same scale and areas are comparable across groups.
        .dens_w = I(d$y / dd$max),
        .xc = pos$xc, .xw = pos$xw,
        .rows = I(rows - 1L)
      )
    )
  }

  list(records = records, encoding = encoding, stat = list(type = "violin"))
}

stat_sina <- function(mark, data, encoding, facet_fields) {
  params <- mark$stat
  y <- stat_values(data, encoding, "y", mark)
  g <- ensure_group_x(mark, data, encoding)
  data <- g$data
  encoding <- g$encoding

  fields <- unique(c(encoding$x$field, encoding$color$field, facet_fields))
  dodge <- dodge_positions(data, encoding, params$width)
  dd <- group_densities(mark, data, y, fields)

  xc <- rep(0.5, nrow(data))
  offset <- rep(0, nrow(data))
  for (i in seq_along(dd$groups)) {
    rows <- dd$groups[[i]]
    pos <- dodge(if (is.null(encoding$color$field)) NULL else data[[encoding$color$field]][rows[1]])
    xc[rows] <- pos$xc
    d <- dd$dens[[i]]
    if (is.null(d)) next
    # Relative density at each point's y, between 0 and 1.
    rel <- stats::approx(d$x, d$y / dd$max, xout = y[rows], rule = 2)$y
    # Spread points across [-1, 1] with a fixed low-discrepancy sequence over
    # their rank in y, so neighbouring points land on different sides and the
    # layout is the same every time the plot is compiled.
    r <- rank(y[rows], ties.method = "first")
    u <- ((r * 0.6180339887498949) %% 1) * 2 - 1
    offset[rows] <- u * rel * pos$xw / 2
  }

  data[[".xc"]] <- xc
  data[[".offset"]] <- offset
  list(records = df_to_records(data), encoding = encoding, stat = list(type = "sina"))
}

stat_histogram <- function(mark, data, encoding, facet_fields) {
  params <- mark$stat
  if (!is.null(encoding$y)) {
    cli::cli_abort(c(
      "{.fn mark_histogram} maps {.field x} only.",
      "i" = "The bar heights are the counts, so remove the {.field y} mapping."
    ))
  }
  x <- stat_values(data, encoding, "x", mark)
  breaks <- histogram_breaks(x, params$bins, params$binwidth)

  bin <- if (length(x) > 0) {
    findInterval(x, breaks, left.open = TRUE, rightmost.closed = TRUE)
  } else {
    integer()
  }
  fields <- unique(c(facet_fields, encoding$color$field))

  # One record per (facet cell, bin, colour group) with at least one row.
  # Colour groups are stacked within a bin, in colour-level order.
  cells <- split_rows(data, facet_fields)
  color_field <- encoding$color$field
  records <- list()
  for (cell in cells) {
    for (b in sort(unique(bin[cell]))) {
      in_bin <- cell[bin[cell] == b]
      stacks <- if (is.null(color_field)) list(in_bin) else {
        split_rows(data[in_bin, , drop = FALSE], color_field) |>
          lapply(function(r) in_bin[r])
      }
      base <- 0
      for (rows in stacks) {
        n <- length(rows)
        records[[length(records) + 1]] <- c(
          group_columns(data, fields, rows),
          list(
            .x0 = breaks[b], .x1 = breaks[b + 1],
            .count = n, .ymin = base, .ymax = base + n,
            .rows = I(rows - 1L)
          )
        )
        base <- base + n
      }
    }
  }

  encoding$y <- list(field = ".count", type = "quantitative", label = "count")
  list(
    records = records,
    encoding = encoding,
    stat = list(type = "histogram", breaks = I(breaks))
  )
}

# Bin edges for a histogram. With neither `bins` nor `binwidth`, uses the
# same rule as hist(): Sturges' number of bins, rounded to pretty edges.
histogram_breaks <- function(x, bins = NULL, binwidth = NULL) {
  if (length(x) == 0) return(c(0, 1))
  rng <- range(x)
  if (rng[1] == rng[2]) rng <- rng + c(-0.5, 0.5)
  if (!is.null(binwidth)) {
    start <- floor(rng[1] / binwidth) * binwidth
    end <- ceiling(rng[2] / binwidth) * binwidth
    if (end == start) end <- start + binwidth
    return(seq(start, end, by = binwidth))
  }
  if (!is.null(bins)) {
    return(seq(rng[1], rng[2], length.out = bins + 1))
  }
  pretty(rng, n = grDevices::nclass.Sturges(x), min.n = 1)
}

# ---- Polygons -----------------------------------------------------------------

# One record per polygon: its vertices in row order (`.x`, `.y`), the rows it
# draws (`.rows`), its grouping columns, and every other column that has a
# single value within the polygon, so tooltip templates such as "{name}" can
# use them. Rows are split into polygons by `group`, and by colour and facet
# panel, since a polygon can only have one fill and be drawn in one panel.
# Without a group mapping, all rows of a panel and colour form one polygon.
# Polygons with fewer than three vertices enclose no area and are left out,
# with a warning.
stat_polygon <- function(mark, data, encoding, facet_fields) {
  x <- stat_values(data, encoding, "x", mark)
  y <- stat_values(data, encoding, "y", mark)
  group_field <- encoding$group$field
  fields <- unique(c(group_field, encoding$color$field, facet_fields))
  skip <- c(encoding$x$field, encoding$y$field, fields)

  groups <- if (nrow(data) == 0) list() else split_rows(data, fields)
  too_small <- lengths(groups) < 3
  n_small <- sum(too_small)
  if (n_small > 0) {
    cli::cli_warn(c(
      "!" = paste0(
        "{n_small} polygon{?s} in mark {.val {mark$id}} ",
        "{cli::qty(n_small)}{?has/have} fewer than three vertices and ",
        "{cli::qty(n_small)}{?was/were} left out."
      )
    ))
  }

  records <- lapply(groups[!too_small], function(rows) {
    constant <- list()
    for (f in setdiff(names(data), skip)) {
      v <- data[[f]][rows]
      if (length(unique(v)) == 1L) constant[[f]] <- v[1]
    }
    c(
      group_columns(data, fields, rows),
      constant,
      list(.x = I(x[rows]), .y = I(y[rows]), .n = length(rows), .rows = I(rows - 1L))
    )
  })

  list(records = records, encoding = encoding, stat = list(type = "polygon"))
}
