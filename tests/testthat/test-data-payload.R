# Plot data goes to the browser as columns, and a mark drawing the plot's
# own rows refers to them instead of sending a copy (see df_to_columns() and
# resolve_mark() in R/render.R, inflateSpec() in inst/htmlwidgets/glyph.js).
# These tests check that the rows the browser rebuilds are exactly the rows it
# used to receive.

# What the browser parses from the JSON htmlwidgets embeds.
parsed <- function(x) jsonlite::fromJSON(widget_json(x), simplifyVector = FALSE)
# The rows a data frame used to arrive as.
old_rows <- function(df) parsed(list(values = old_records(df)))$values

typed_frame <- function(n) {
  set.seed(n)
  data.frame(
    num   = c(round(rnorm(n), 6), NA)[seq_len(n)],
    big   = c(1e15 + 0.5, -2.5e-12, 123456.789, NaN, Inf)[(seq_len(n) - 1) %% 5 + 1],
    int   = seq_len(n),
    chr   = c("a", "b \"quoted\"", NA, "ünïcödé", "")[(seq_len(n) - 1) %% 5 + 1],
    fct   = factor(c("lo", "hi", NA)[(seq_len(n) - 1) %% 3 + 1], levels = c("lo", "hi")),
    lgl   = c(TRUE, FALSE, NA)[(seq_len(n) - 1) %% 3 + 1],
    date  = as.Date("2024-02-28") + seq_len(n),
    time  = as.POSIXct("2024-03-31 01:30:00", tz = "Europe/London") + 3600 * seq_len(n),
    stringsAsFactors = FALSE
  )
}

test_that("rows rebuilt from columns match the old row records exactly", {
  for (n in c(0, 1, 2, 7, 40)) {
    df <- typed_frame(n)
    payload <- parsed(df_to_columns(df))
    # Dates and date-times go as numbers, named in `temporal` (#39); the
    # renderer turns them into dates. Every other value is unchanged.
    expected <- df
    expected$date <- temporal_ms(df$date)
    expected$time <- temporal_ms(df$time)
    expect_identical(rows_from_json(payload), old_rows(expected), info = paste("rows:", n))
    expect_identical(unlist(payload$temporal), c("date", "time"))
  }
  # A single column, and a single row of a single column.
  one <- data.frame(v = c(1.5, 2.5, NA))
  expect_identical(rows_from_json(parsed(df_to_columns(one))), old_rows(one))
  expect_identical(rows_from_json(parsed(df_to_columns(one[1, , drop = FALSE]))),
                   old_rows(one[1, , drop = FALSE]))
})

test_that("a mark drawing the plot's rows refers to them instead of copying them", {
  compiled <- compile(glyph(mtcars, x = wt, y = mpg) |> mark_point(color = cyl))
  d <- compiled$spec$marks[[1]]$data
  expect_equal(d$from, "plot")
  expect_null(d$rows)
  expect_null(d$columns)
  expect_equal(as.character(d$fields), names(mtcars))
  json <- compiled$json
  expect_equal(lengths(regmatches(json, gregexpr('"wt":\\[', json))), 1)

  top <- parsed(compiled$spec)$data
  mark <- parsed(compiled$spec)$marks[[1]]$data
  expect_identical(rows_from_json(top, mark$fields, mark$rows), old_rows(mtcars))
})

test_that("a mark's rows keep its own columns, in its own order, and its NA drops", {
  df <- mtcars
  df$mpg[c(2, 5)] <- NA
  spec <- glyph(df, x = log(wt), y = mpg) |>
    mark_point() |>
    mark_bar(x = factor(cyl), y = hp) |>
    facet(cols = factor(am))
  expect_warning(compiled <- compile(spec), "Removed 2 rows")
  p <- parsed(compiled$spec)

  # The point mark: the plot's columns, its computed x, then the computed
  # facet column, without the rows whose y is missing.
  point_df <- df
  point_df$.g_point_1_x <- log(df$wt)
  point_df$.g_facet_cols <- factor(df$am)
  point_df <- point_df[!is.na(df$mpg), ]
  m1 <- p$marks[[1]]$data
  expect_equal(unlist(m1$rows), which(!is.na(df$mpg)) - 1L)
  expect_identical(rows_from_json(p$data, m1$fields, m1$rows), old_rows(point_df))

  # The bar mark keeps every row and has its own computed x, not the point
  # mark's.
  bar_df <- df
  bar_df$.g_bar_2_x <- factor(df$cyl)
  bar_df$.g_facet_cols <- factor(df$am)
  m2 <- p$marks[[2]]$data
  expect_null(m2$rows)
  expect_identical(rows_from_json(p$data, m2$fields, m2$rows), old_rows(bar_df))
})

test_that("a data column named like a generated column doesn't replace it", {
  df <- data.frame(wt = 1:3, mpg = c(3, 1, 2), .g_point_1_x = c(9, 9, 9))
  compiled <- compile(glyph(df, x = log(wt), y = mpg) |> mark_point())
  p <- parsed(compiled$spec)
  expect_null(p$marks[[1]]$data$from)
  rows <- rows_from_json(p$marks[[1]]$data)
  expect_equal(vapply(rows, `[[`, numeric(1), ".g_point_1_x"), log(1:3))
})

test_that("a mark whose rows are all dropped draws nothing", {
  df <- data.frame(a = c(1, 2), b = c(NA, NA), c = c(1, 2))
  expect_warning(compiled <- compile(glyph(df, x = a, y = c) |> mark_point() |> mark_point(y = b)),
                 "Removed 2 rows")
  p <- parsed(compiled$spec)
  m2 <- p$marks[[2]]$data
  expect_equal(m2$from, "plot")
  expect_length(rows_from_json(p$data, m2$fields, m2$rows), 0)
  expect_length(rows_from_json(p$data, p$marks[[1]]$data$fields, p$marks[[1]]$data$rows), 2)
})

test_that("a mark with its own data sends its own columns", {
  other <- data.frame(wt = c(2, 3, 4), mpg = c(30, 25, 20), label = c("a", "b", "c"))
  compiled <- compile(glyph(mtcars, x = wt, y = mpg) |> mark_point() |> mark_text(data = other, label = label))
  p <- parsed(compiled$spec)
  expect_equal(p$marks[[1]]$data$from, "plot")
  expect_null(p$marks[[2]]$data$from)
  expect_identical(rows_from_json(p$marks[[2]]$data), old_rows(other))
})

test_that("statistical marks send their summaries, not the raw rows", {
  hist <- compile(glyph(mtcars, x = mpg) |> mark_histogram())$spec
  expect_equal(hist$data$n, 0)
  expect_gt(length(hist$marks[[1]]$data$values), 0)

  box <- compile(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot())$spec
  expect_equal(box$data$n, 0)
  # Brushing and linked selections only need each box's row indices.
  expect_equal(sort(unlist(lapply(box$marks[[1]]$data$values, `[[`, ".rows"))), 0:31)
})

test_that("statistical marks still send what facet() and marginals() read", {
  faceted <- compile(glyph(mtcars, x = mpg) |> mark_histogram() |> facet(cols = am))$spec
  expect_equal(names(faceted$data$columns), "am")
  expect_equal(faceted$data$n, 32)

  margins <- compile(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot() |>
                       marginals(x = "histogram", y = "density"))$spec
  expect_setequal(names(margins$data$columns), c(".g_boxplot_1_x", "mpg"))
})

test_that("sina rows are sent as columns and rebuilt with their offsets", {
  compiled <- compile(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_sina())
  p <- parsed(compiled$spec)
  expect_equal(p$data$n, 0)
  rows <- rows_from_json(p$marks[[1]]$data)
  expect_length(rows, 32)
  expect_true(all(c(".xc", ".offset", "mpg") %in% names(rows[[1]])))
})

test_that("keyframe animation keeps the plot's full data", {
  spec <- compile(glyph(mtcars, x = wt, y = mpg) |> mark_point() |> animate(by = gear, transition = "morph"))$spec
  expect_equal(names(spec$data$columns), names(mtcars))
})

test_that("compose() panels and inset() plots carry the new payload too", {
  p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  layout <- compile(compose(p, glyph(mtcars, x = mpg) |> mark_histogram()))$spec
  expect_equal(layout[["$schema"]], "glyph/v0.2")
  expect_equal(layout$panels[[1]]$marks[[1]]$data$from, "plot")
  expect_equal(layout$panels[[2]]$data$n, 0)
  inset_spec <- compile(inset(p, glyph(mtcars, x = cyl, y = mpg) |> mark_bar()))$spec
  expect_equal(inset_spec$layout$inset$marks[[1]]$data$from, "plot")
  expect_equal(inset_spec$layout$inset$data$n, 32)
})

test_that("the payload is far smaller than a copy per mark", {
  df <- data.frame(x = rnorm(5000), y = rnorm(5000))
  spec <- glyph(df, x = x, y = y) |> mark_point() |> mark_line()
  json <- compile(spec)$json
  old_size <- nchar(widget_json(list(values = old_records(df)))) * 3  # top level plus two marks
  expect_lt(nchar(json), old_size / 2)
})
