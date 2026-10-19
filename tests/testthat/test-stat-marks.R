# Statistical marks: boxplot, violin, sina, histogram.
#
# The statistics are computed in R at compile time (R/stats.R), so these tests
# check the compiled records against base R's own quantile(), density() and
# cut(), and check that the marks work with computed mappings, NA dropping,
# facets and compose(). Rendering in a browser is checked separately.

compiled_mark <- function(spec, i = 1) compile(spec)$spec$marks[[i]]
records <- function(mark) mark$data$values
pluck_num <- function(recs, name) vapply(recs, function(r) as.numeric(r[[name]]), numeric(1))

# ---- Boxplot -----------------------------------------------------------------

test_that("mark_boxplot() computes quartiles, whiskers and outliers per group", {
  mark <- compiled_mark(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot())
  recs <- records(mark)
  expect_equal(mark$stat$type, "boxplot")
  expect_length(recs, 3)

  for (r in recs) {
    v <- mtcars$mpg[as.character(mtcars$cyl) == as.character(r[[".g_boxplot_1_x"]])]
    q <- stats::quantile(v, c(0.25, 0.5, 0.75), names = FALSE)
    iqr <- q[3] - q[1]
    in_whiskers <- v >= q[1] - 1.5 * iqr & v <= q[3] + 1.5 * iqr
    expect_equal(c(r$.lower, r$.middle, r$.upper), q)
    expect_equal(r$.ymin, min(v[in_whiskers]))
    expect_equal(r$.ymax, max(v[in_whiskers]))
    expect_equal(as.numeric(r$.outliers), sort(v[!in_whiskers]))
    expect_equal(r$.n, length(v))
    # .rows points back at exactly this group's rows (0-based).
    expect_setequal(mtcars$mpg[as.integer(r$.rows) + 1], v)
    expect_length(r$.rows, length(v))
  }
  # The 8-cylinder group has values beyond its whiskers.
  eight <- recs[[3]]
  expect_equal(as.character(eight[[".g_boxplot_1_x"]]), "8")
  expect_gt(length(eight$.outliers), 0)
})

test_that("mark_boxplot() treats a numeric x as groups and keeps their order", {
  mark <- compiled_mark(glyph(mtcars, x = cyl, y = mpg) |> mark_boxplot())
  expect_equal(mark$encoding$x$type, "nominal")
  expect_equal(as.numeric(mark$encoding$x$domain), c(4, 6, 8))
  expect_equal(pluck_num(records(mark), "cyl"), c(4, 6, 8))
})

test_that("mark_boxplot() with no x draws one box labelled by y", {
  mark <- compiled_mark(glyph(mtcars, y = mpg) |> mark_boxplot())
  expect_length(records(mark), 1)
  expect_equal(as.character(mark$encoding$x$domain), "mpg")
  expect_equal(records(mark)[[1]]$.middle, stats::median(mtcars$mpg))
})

test_that("mark_boxplot() coef and outliers change the whiskers and points", {
  all_range <- records(compiled_mark(
    glyph(mtcars, x = cyl, y = mpg) |> mark_boxplot(coef = Inf)))
  for (r in all_range) {
    v <- mtcars$mpg[mtcars$cyl == r$cyl]
    expect_equal(c(r$.ymin, r$.ymax), range(v))
    expect_length(r$.outliers, 0)
  }
  hidden <- records(compiled_mark(
    glyph(mtcars, x = cyl, y = mpg) |> mark_boxplot(outliers = FALSE)))
  shown <- records(compiled_mark(glyph(mtcars, x = cyl, y = mpg) |> mark_boxplot()))
  expect_length(hidden[[3]]$.outliers, 0)
  expect_equal(hidden[[3]]$.ymax, shown[[3]]$.ymax)
})

test_that("mark_boxplot() places colour groups side by side within x", {
  recs <- records(compiled_mark(
    glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot(color = factor(am), width = 0.8)))
  expect_length(recs, 6)  # 3 cylinder groups x 2 transmission types
  expect_setequal(pluck_num(recs, ".xc"), c(0.25, 0.75))
  expect_equal(unique(pluck_num(recs, ".xw")), 0.4)
  r <- recs[[1]]
  v <- mtcars$mpg[mtcars$cyl == 4 & mtcars$am == as.numeric(as.character(r[[".g_boxplot_1_color"]]))]
  expect_equal(r$.middle, stats::median(v))
})

test_that("colour mapped to the same variable as x colours groups without splitting them", {
  for (spec in list(
    glyph(mtcars, x = factor(gear), y = mpg) |> mark_violin(color = factor(gear)),
    glyph(mtcars, x = gear, y = mpg) |> mark_violin(color = gear)
  )) {
    recs <- records(compiled_mark(spec))
    expect_length(recs, 3)
    expect_equal(unique(pluck_num(recs, ".xc")), 0.5)
    expect_equal(unique(pluck_num(recs, ".xw")), 0.9)
  }
})

test_that("rows with a missing colour form a group of their own instead of being dropped", {
  df <- mtcars
  df$am[1:3] <- NA
  box <- records(compiled_mark(glyph(df, x = factor(cyl), y = mpg) |> mark_boxplot(color = am)))
  expect_equal(sum(pluck_num(box, ".n")), nrow(df))
  hist <- records(compiled_mark(glyph(df, x = mpg) |> mark_histogram(color = am)))
  expect_equal(sum(pluck_num(hist, ".count")), nrow(df))
})

test_that("a single outlier still serializes as a JSON array", {
  df <- data.frame(g = "a", y = c(1, 2, 3, 4, 100))
  json <- compile(glyph(df, x = g, y = y) |> mark_boxplot())$json
  expect_match(json, '".outliers":[100]', fixed = TRUE)
})

# ---- Histogram ----------------------------------------------------------------

test_that("mark_histogram() counts rows per bin like hist()", {
  mark <- compiled_mark(glyph(mtcars, x = mpg) |> mark_histogram())
  recs <- records(mark)
  breaks <- pretty(range(mtcars$mpg), n = grDevices::nclass.Sturges(mtcars$mpg), min.n = 1)
  expect_equal(as.numeric(mark$stat$breaks), breaks)

  expected <- table(cut(mtcars$mpg, breaks, include.lowest = TRUE, right = TRUE))
  expected <- as.integer(expected[expected > 0])
  expect_equal(as.integer(pluck_num(recs, ".count")), expected)
  expect_equal(sum(pluck_num(recs, ".count")), nrow(mtcars))
  expect_equal(mark$encoding$y$field, ".count")
  expect_equal(compile(glyph(mtcars, x = mpg) |> mark_histogram())$spec$scales$y$label, "count")
})

test_that("mark_histogram() bins and binwidth set the bin edges", {
  b5 <- compiled_mark(glyph(mtcars, x = mpg) |> mark_histogram(bins = 5))
  expect_equal(as.numeric(b5$stat$breaks), seq(10.4, 33.9, length.out = 6))
  expect_equal(sum(pluck_num(records(b5), ".count")), 32)

  bw <- compiled_mark(glyph(mtcars, x = mpg) |> mark_histogram(binwidth = 5))
  expect_equal(as.numeric(bw$stat$breaks), seq(10, 35, by = 5))
  expect_equal(sum(pluck_num(records(bw), ".count")), 32)
})

test_that("mark_histogram() stacks colour groups within each bin", {
  recs <- records(compiled_mark(
    glyph(mtcars, x = mpg) |> mark_histogram(color = factor(am), binwidth = 5)))
  by_bin <- split(recs, pluck_num(recs, ".x0"))
  for (bin in by_bin) {
    expect_equal(bin[[1]]$.ymin, 0)
    if (length(bin) > 1) expect_equal(bin[[2]]$.ymin, bin[[1]]$.ymax)
    expect_equal(bin[[length(bin)]]$.ymax, sum(pluck_num(bin, ".count")))
  }
  expect_equal(sum(pluck_num(recs, ".count")), 32)
})

test_that("mark_histogram() rejects a y mapping and a non-numeric x", {
  expect_error(compile(glyph(mtcars, x = mpg, y = hp) |> mark_histogram()), "maps")
  expect_error(compile(glyph(iris, x = Species) |> mark_histogram()), "numeric")
})

# ---- Violin and sina ------------------------------------------------------------

test_that("mark_violin() matches stats::density() for each group", {
  mark <- compiled_mark(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_violin())
  recs <- records(mark)
  expect_length(recs, 3)
  dens <- lapply(split(mtcars$mpg, mtcars$cyl), function(v) {
    stats::density(v, n = 64, from = min(v), to = max(v))
  })
  overall_max <- max(vapply(dens, function(d) max(d$y), numeric(1)))
  for (i in seq_along(recs)) {
    expect_equal(as.numeric(recs[[i]]$.dens_y), dens[[i]]$x)
    expect_equal(as.numeric(recs[[i]]$.dens_w), dens[[i]]$y / overall_max)
  }
  # Every violin is drawn on the same density scale.
  expect_equal(max(unlist(lapply(recs, function(r) as.numeric(r$.dens_w)))), 1)
})

test_that("mark_violin() leaves out groups that have no density, with a warning", {
  df <- data.frame(g = c("a", "a", "a", "b"), y = c(1, 2, 3, 5))
  expect_warning(mark <- compiled_mark(glyph(df, x = g, y = y) |> mark_violin()),
                 "fewer than two distinct values")
  expect_length(records(mark), 1)
})

test_that("mark_sina() keeps every row and spreads it within the violin outline", {
  spec <- glyph(mtcars, x = factor(cyl), y = mpg) |> mark_sina(width = 0.8)
  mark <- compiled_mark(spec)
  recs <- records(mark)
  expect_length(recs, nrow(mtcars))
  expect_equal(pluck_num(recs, "mpg"), mtcars$mpg)

  violin <- records(compiled_mark(
    glyph(mtcars, x = factor(cyl), y = mpg) |> mark_violin(width = 0.8)))
  for (i in seq_along(recs)) {
    r <- recs[[i]]
    v <- violin[[match(as.character(r[[".g_sina_1_x"]]), c("4", "6", "8"))]]
    half_width <- stats::approx(as.numeric(v$.dens_y), as.numeric(v$.dens_w), r$mpg)$y * 0.8 / 2
    expect_lte(abs(r$.offset), half_width + 1e-12)
  }
  # Points do spread out, and the layout is the same on every compile.
  expect_gt(max(abs(pluck_num(recs, ".offset"))), 0.1)
  expect_identical(records(compiled_mark(spec)), recs)
})

# ---- Integration with existing features -----------------------------------------

test_that("statistical marks evaluate computed y mappings", {
  r <- records(compiled_mark(glyph(mtcars, x = factor(cyl), y = log(mpg)) |> mark_boxplot()))
  expect_equal(r[[1]]$.middle, stats::median(log(mtcars$mpg[mtcars$cyl == 4])))
  h <- records(compiled_mark(glyph(mtcars, x = mpg / 10) |> mark_histogram()))
  expect_equal(sum(pluck_num(h, ".count")), 32)
})

test_that("statistical marks drop rows with missing values before summarising", {
  df <- mtcars
  df$mpg[c(1, 5)] <- NA
  df$cyl[3] <- NA
  expect_warning(
    box <- compiled_mark(glyph(df, x = factor(cyl), y = mpg) |> mark_boxplot()),
    "Removed 3 rows"
  )
  expect_equal(sum(pluck_num(records(box), ".n")), 29)
  expect_warning(
    hist <- compiled_mark(glyph(df, x = mpg) |> mark_histogram()),
    "Removed 2 rows"
  )
  expect_equal(sum(pluck_num(records(hist), ".count")), 30)
})

test_that("statistical marks compute their summaries per facet panel", {
  box <- records(compiled_mark(
    glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot() |> facet(cols = am)))
  expect_length(box, 6)
  for (r in box) {
    v <- mtcars$mpg[mtcars$am == r$am & mtcars$cyl == as.numeric(as.character(r[[".g_boxplot_1_x"]]))]
    expect_equal(r$.middle, stats::median(v))
  }

  # A computed facet variable is carried on every summary record.
  hist <- compiled_mark(glyph(mtcars, x = mpg) |> mark_histogram() |> facet(cols = factor(gear)))
  recs <- records(hist)
  expect_true(all(vapply(recs, function(r) ".g_facet_cols" %in% names(r), logical(1))))
  counts <- tapply(pluck_num(recs, ".count"),
                   vapply(recs, function(r) as.character(r[[".g_facet_cols"]]), ""), sum)
  expect_equal(as.integer(counts[c("3", "4", "5")]), as.integer(table(mtcars$gear)))
})

test_that("statistical marks compile inside compose() layouts", {
  layout <- compose(
    glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot(),
    glyph(mtcars, x = mpg) |> mark_histogram(),
    glyph(mtcars, x = factor(cyl), y = mpg) |> mark_violin() |> mark_sina(),
    linked_selections = TRUE
  )
  panels <- compile(layout)$spec$panels
  types <- vapply(panels, function(p) paste(vapply(p$marks, `[[`, "", "type"), collapse = "+"), "")
  expect_equal(types, c("boxplot", "histogram", "violin+sina"))
})

test_that("statistical marks keep the plot's interaction and theme settings", {
  spec <- glyph(mtcars, x = factor(cyl), y = mpg) |>
    mark_boxplot() |>
    interact(tooltip = TRUE, hover = "brighten", brush = TRUE) |>
    theme_tokens(preset = "dark")
  compiled <- compile(spec)$spec
  expect_true(compiled$interact$tooltip$enabled)
  expect_true(compiled$interact$brush$enabled)
  expect_equal(compiled$theme$bg, get_preset("dark")$bg)
})

test_that("statistical marks check their arguments", {
  p <- glyph(mtcars, x = factor(cyl), y = mpg)
  expect_error(mark_boxplot(p, coef = -1), "coef")
  expect_error(mark_boxplot(p, width = 1.5), "width")
  expect_error(mark_boxplot(p, outliers = NA), "outliers")
  expect_error(mark_violin(p, bw = -1), "bw")
  expect_error(mark_violin(p, adjust = 0), "adjust")
  expect_error(mark_histogram(p, bins = 2.5), "whole number")
  expect_error(mark_histogram(p, binwidth = 0), "binwidth")
  expect_error(compile(glyph(iris, x = Sepal.Length, y = Species) |> mark_boxplot()), "numeric")
})
