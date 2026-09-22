test_that("glyph() creates a valid spec", {
  spec <- glyph(mtcars, x = wt, y = mpg)
  expect_s3_class(spec, "glyph_spec")
  expect_equal(nrow(spec$data), 32)
  expect_true("x" %in% names(spec$mappings))
  expect_true("y" %in% names(spec$mappings))
  expect_equal(spec$mappings$x$expr, "wt")
  expect_equal(spec$mappings$y$expr, "mpg")
})

test_that("glyph() with no data returns spec", {
  spec <- glyph()
  expect_s3_class(spec, "glyph_spec")
  expect_null(spec$data)
})

test_that("glyph() rejects non-data.frame input", {
  expect_error(glyph(data = "not_a_url"), "planned but not yet")
  expect_error(glyph(data = 42), "data.frame")
})

test_that("glyph() requires named mappings", {
  expect_error(glyph(mtcars, wt), "named")
})

test_that("marks are added correctly", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point(color = cyl) |>
    mark_line() |>
    mark_bar()

  expect_length(spec$marks, 3)
  expect_equal(spec$marks[[1]]$type, "point")
  expect_equal(spec$marks[[2]]$type, "line")
  expect_equal(spec$marks[[3]]$type, "bar")

  # Per-mark mappings
  expect_true("color" %in% names(spec$marks[[1]]$mappings))
  expect_equal(spec$marks[[1]]$mappings$color$expr, "cyl")
})

test_that("mark_point has correct defaults", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  style <- spec$marks[[1]]$style
  expect_equal(style$size, 5)
  expect_equal(style$opacity, 0.8)
})

test_that("mark_line has correct defaults", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_line()
  style <- spec$marks[[1]]$style
  expect_equal(style$stroke_width, 2)
  expect_equal(style$interpolate, "monotone")
})

test_that("mark_bar has correct defaults", {
  spec <- glyph(mtcars, x = cyl, y = mpg) |> mark_bar()
  style <- spec$marks[[1]]$style
  expect_equal(style$orient, "vertical")
  expect_equal(style$corner_radius, 2)
})

test_that("mark_text has smart_repel default TRUE", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_text()
  expect_true(spec$marks[[1]]$style$smart_repel)
})

test_that("mark_area has correct defaults", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_area()
  expect_equal(spec$marks[[1]]$style$opacity, 0.6)
})

test_that("mark_rule stores intercepts", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_rule(y_intercept = 25)
  expect_equal(spec$marks[[1]]$style$y_intercept, 25)
})

test_that("per-mark data override works", {
  overlay <- data.frame(x = c(1, 2), y = c(3, 4))
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    mark_point(data = overlay)

  expect_null(spec$marks[[1]]$data)
  expect_equal(nrow(spec$marks[[2]]$data), 2)
})

test_that("interact() sets interaction config", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    interact(
      tooltip = "{cyl} cyl",
      zoom = TRUE,
      brush = TRUE,
      hover = "enlarge"
    )

  expect_true(spec$interact$tooltip$enabled)
  expect_equal(spec$interact$tooltip$template, "{cyl} cyl")
  expect_true(spec$interact$zoom$enabled)
  expect_true(spec$interact$brush$enabled)
  expect_equal(spec$interact$hover$effect, "enlarge")
})

test_that("interact() with auto tooltip", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    interact(tooltip = TRUE)

  expect_equal(spec$interact$tooltip$template, "auto")
})

test_that("interact() with crossfilter and nearest", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    interact(crossfilter = TRUE, nearest = TRUE)

  expect_true(spec$interact$crossfilter$enabled)
  expect_true(spec$interact$nearest$enabled)
})

test_that("interact() rejects invalid hover type", {
  expect_error(
    glyph(mtcars, x = wt, y = mpg) |>
      mark_point() |>
      interact(hover = "invalid"),
    "arg"
  )
})

test_that("selection() adds named selections", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point(color = cyl) |>
    selection("legend_filter", type = "legend", fields = "cyl")

  expect_true("legend_filter" %in% names(spec$interact$selections))
  expect_equal(spec$interact$selections$legend_filter$type, "legend")
  expect_equal(spec$interact$selections$legend_filter$fields, "cyl")
})

test_that("animate() sets animation config", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    animate(transition = "fade", duration = 800, easing = "bounce")

  expect_equal(spec$animate$transition, "fade")
  expect_equal(spec$animate$duration, 800)
  expect_equal(spec$animate$easing, "bounce")
})

test_that("animate() with keyframe 'by' field", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    animate(by = cyl)

  expect_equal(spec$animate$by, "cyl")
})

test_that("animate() rejects invalid transition", {
  expect_error(
    glyph(mtcars, x = wt, y = mpg) |> mark_point() |>
      animate(transition = "invalid"),
    "arg"
  )
})

test_that("animate() rejects invalid easing", {
  expect_error(
    glyph(mtcars, x = wt, y = mpg) |> mark_point() |>
      animate(easing = "invalid"),
    "arg"
  )
})

test_that("scale() sets scale config", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    scale("y", "linear", zero = TRUE, label = "MPG")

  expect_equal(spec$scales$y$type, "linear")
  expect_true(spec$scales$y$zero)
  expect_equal(spec$scales$y$label, "MPG")
})

test_that("scale_color() convenience works", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point(color = cyl) |>
    scale_color("viridis")

  expect_equal(spec$scales$color$range, "viridis")
})

test_that("scale_log() convenience works", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    scale_log("y")

  expect_equal(spec$scales$y$type, "log")
})

test_that("theme_tokens() cascading works", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    theme_tokens(bg = "#1a1a2e")

  expect_equal(spec$theme$bg, "#1a1a2e")
  expect_equal(spec$theme$fg, "#e0e0e0")
})

test_that("theme_tokens() light background auto-contrast", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    theme_tokens(bg = "#ffffff")

  expect_equal(spec$theme$fg, "#333333")
})

test_that("theme presets load correctly", {
  for (preset in c("light", "dark", "minimal", "publication", "presentation")) {
    spec <- glyph(mtcars, x = wt, y = mpg) |>
      mark_point() |>
      theme_tokens(preset = preset)
    expect_true(is.character(spec$theme$font))
    expect_true(is.numeric(spec$theme$font_size))
  }
})

test_that("theme preset dark has correct values", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    theme_tokens(preset = "dark")

  expect_equal(spec$theme$bg, "#1a1a2e")
  expect_equal(spec$theme$fg, "#e0e0e0")
  expect_equal(spec$theme$accent, "#6ec6ff")
})

test_that("theme_tokens() rejects invalid preset", {
  expect_error(
    glyph(mtcars, x = wt, y = mpg) |> mark_point() |>
      theme_tokens(preset = "nope"),
    "arg"
  )
})

test_that("titles() sets title metadata", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    titles(title = "Test", subtitle = "Sub", caption = "Source: mtcars")

  expect_equal(spec$theme$title, "Test")
  expect_equal(spec$theme$subtitle, "Sub")
  expect_equal(spec$theme$caption, "Source: mtcars")
})

test_that("compose() creates a layout", {
  p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  p2 <- glyph(mtcars, x = hp, y = mpg) |> mark_point()

  layout <- compose(p1, p2, type = "hstack", linked_selections = TRUE)
  expect_s3_class(layout, "glyph_layout")
  expect_length(layout$plots, 2)
  expect_true(layout$linked_selections)
  expect_equal(layout$type, "hstack")
})

test_that("compose() supports all layout types", {
  p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  p2 <- glyph(mtcars, x = hp, y = mpg) |> mark_point()

  for (type in c("hstack", "vstack", "grid", "wrap")) {
    layout <- compose(p1, p2, type = type)
    expect_equal(layout$type, type)
  }
})

test_that("compose() rejects non-spec inputs", {
  expect_error(compose("not_a_spec", "also_not"), "glyph_spec")
})

test_that("compose() nested layouts work", {
  p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  p2 <- glyph(mtcars, x = hp, y = mpg) |> mark_point()
  row1 <- compose(p1, p2, type = "hstack")
  full <- compose(row1, p1, type = "vstack")
  expect_s3_class(full, "glyph_layout")
  expect_s3_class(full$plots[[1]], "glyph_layout")
})

test_that("marginals() sets marginal config", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    marginals(x = "histogram", y = "density", size = 0.2)

  expect_equal(spec$layout$type, "marginals")
  expect_equal(spec$layout$x, "histogram")
  expect_equal(spec$layout$y, "density")
  expect_equal(spec$layout$size, 0.2)
})

test_that("inset() sets inset config", {
  main <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  mini <- glyph(mtcars, x = hp, y = mpg) |> mark_point()
  spec <- inset(main, mini, position = "top-right")

  expect_equal(spec$layout$type, "inset")
  expect_s3_class(spec$layout$inset, "glyph_spec")
  expect_equal(spec$layout$position, "top-right")
})

test_that("facet() sets faceting config", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(cols = cyl, free_scales = "both")

  # Like an aesthetic mapping, the facet variable keeps its quosure
  # alongside the label text so a computed expression can be evaluated at
  # compile time (see facet(cols = factor(cyl)) further down).
  expect_equal(spec$facets$cols$expr, "cyl")
  expect_equal(spec$facets$free_scales, "both")
  expect_null(spec$facets$rows)
})

test_that("facet() with rows and cols", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(rows = gear, cols = cyl)

  expect_equal(spec$facets$rows$expr, "gear")
  expect_equal(spec$facets$cols$expr, "cyl")
})

test_that("compile() produces valid JSON", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point(color = cyl) |>
    interact(tooltip = TRUE)

  compiled <- compile(spec)
  expect_s3_class(compiled, "glyph_compiled")
  expect_true(nchar(compiled$json) > 100)

  parsed <- jsonlite::fromJSON(compiled$json)
  expect_equal(parsed[["$schema"]], "glyph/v0.1")
  expect_equal(parsed$width, 600)
  expect_equal(parsed$height, 400)
})

test_that("compile() always resolves to the html engine, regardless of data size", {
  # There is no canvas/webgl renderer, so compile() no longer pretends to
  # auto-select one by data size — "auto" always resolves to "html".
  small <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  compiled_small <- compile(small)
  expect_equal(compiled_small$engine, "html")

  big_data <- mtcars[rep(seq_len(32), 3200), ]
  big <- glyph(big_data, x = wt, y = mpg) |> mark_point()
  compiled_big <- compile(big)
  expect_equal(compiled_big$engine, "html")
})

test_that("compile() accepts an explicit html engine", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  compiled <- compile(spec, engine = "html")
  expect_equal(compiled$engine, "html")
})

test_that("compile() rejects unimplemented engines instead of silently accepting them", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  expect_error(compile(spec, engine = "canvas"), "arg")
  expect_error(compile(spec, engine = "webgl"), "arg")
})

test_that("compile() resolves scale types from data", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  compiled <- compile(spec)
  expect_equal(compiled$spec$scales$x$type, "linear")
  expect_equal(compiled$spec$scales$y$type, "linear")
})

test_that("compile() for layouts works", {
  p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  p2 <- glyph(mtcars, x = hp, y = mpg) |> mark_point()
  layout <- compose(p1, p2, type = "hstack")
  compiled <- compile(layout)
  expect_s3_class(compiled, "glyph_compiled")
  expect_equal(compiled$spec$type, "layout")
  expect_length(compiled$spec$panels, 2)
})

test_that("to_vegalite() produces valid Vega-Lite JSON", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  vl_json <- to_vegalite(spec)
  vl <- jsonlite::fromJSON(vl_json)
  expect_true(grepl("vega-lite", vl[["$schema"]]))
  expect_equal(vl$mark, "point")
})

test_that("export() to JSON works", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  result <- export(spec, tmp)
  expect_true(file.exists(tmp))
  content <- jsonlite::fromJSON(readLines(tmp, warn = FALSE))
  expect_equal(content[["$schema"]], "glyph/v0.1")
})

test_that("summary.glyph_spec works", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    interact(tooltip = TRUE) |>
    animate(transition = "fade")
  expect_no_error(summary(spec))
})

test_that("full pipeline: spec -> compile -> JSON round-trip", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point(color = cyl, size = hp) |>
    mark_line() |>
    interact(tooltip = TRUE, zoom = TRUE) |>
    animate(transition = "fade", duration = 300) |>
    scale("y", "linear", zero = TRUE, label = "Miles per Gallon") |>
    scale_color("Set2") |>
    theme_tokens(preset = "dark") |>
    titles(title = "Test Plot") |>
    facet(cols = cyl)

  compiled <- compile(spec)
  parsed <- jsonlite::fromJSON(compiled$json)
  expect_equal(length(parsed$marks$type), 2)
  expect_equal(parsed$theme$title, "Test Plot")
  expect_true(parsed$interact$tooltip$enabled)
  expect_true(parsed$interact$zoom$enabled)
  expect_equal(parsed$animate$transition, "fade")
})

# ---- Computed mappings ---------------------------------------------------

test_that("plain column mappings still resolve to their column name", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  compiled <- compile(spec)
  enc <- compiled$spec$marks[[1]]$encoding
  expect_equal(enc$x$field, "wt")
  expect_equal(enc$x$type, "quantitative")
})

test_that("a computed numeric mapping (log(wt)) is evaluated, not dropped", {
  spec <- glyph(mtcars, x = log(wt), y = mpg) |> mark_point()
  compiled <- compile(spec)
  enc <- compiled$spec$marks[[1]]$encoding

  expect_false(is.null(enc$x$field))
  expect_equal(enc$x$type, "quantitative")
  expect_equal(enc$x$label, "log(wt)")

  # The generated column actually holds log(wt) values, not zeros.
  mark_values <- compiled$spec$marks[[1]]$data$values
  expect_equal(mark_values[[1]][[enc$x$field]], log(mtcars$wt[1]))

  # Expression text becomes the default axis label.
  expect_equal(compiled$spec$scales$x$label, "log(wt)")
})

test_that("a computed categorical mapping (factor(cyl)) is evaluated", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point(color = factor(cyl))
  compiled <- compile(spec)
  enc <- compiled$spec$marks[[1]]$encoding

  expect_false(is.null(enc$color$field))
  expect_equal(enc$color$type, "nominal")
  expect_equal(enc$color$label, "factor(cyl)")
})

test_that("mark-level (not just global) computed mappings are evaluated", {
  spec <- glyph(mtcars) |> mark_point(x = log(wt), y = mpg)
  compiled <- compile(spec)
  enc <- compiled$spec$marks[[1]]$encoding
  expect_false(is.null(enc$x$field))
  expect_equal(enc$x$label, "log(wt)")
})

test_that("computed mapping columns are folded into the top-level compiled data", {
  spec <- glyph(mtcars, x = log(wt), y = mpg) |> mark_point()
  compiled <- compile(spec)
  field <- compiled$spec$marks[[1]]$encoding$x$field
  top_level_row1 <- compiled$spec$data$values[[1]]
  expect_true(field %in% names(top_level_row1))
})

test_that("an unresolvable mapping expression falls back to 'expression' instead of erroring", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point(size = totally_unknown_col_xyz)
  expect_no_error(compiled <- compile(spec))
  expect_equal(compiled$spec$marks[[1]]$encoding$size$type, "expression")
})

test_that("interact() tooltip templates still work unchanged", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    interact(tooltip = "{mpg} mpg")
  compiled <- compile(spec)
  expect_equal(compiled$spec$interact$tooltip$template, "{mpg} mpg")
})

# ---- NA handling ----------------------------------------------------------

test_that("rows with NA in a mapped position aesthetic are dropped with a warning", {
  df <- mtcars
  df$wt[c(2, 5)] <- NA
  spec <- glyph(df, x = wt, y = mpg) |> mark_point()

  expect_warning(compiled <- compile(spec), "Removed 2 row")
  mark_values <- compiled$spec$marks[[1]]$data$values
  expect_equal(length(mark_values), nrow(df) - 2)
})

test_that("the NA warning names the offending aesthetic", {
  df <- mtcars
  df$mpg[1] <- NA
  spec <- glyph(df, x = wt, y = mpg) |> mark_point()
  expect_warning(compile(spec), "y")
})

test_that("no warning and no rows dropped when there are no NAs", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  expect_no_warning(compiled <- compile(spec))
  expect_equal(length(compiled$spec$marks[[1]]$data$values), nrow(mtcars))
})

test_that("NA-dropping is per-mark, not global", {
  df <- mtcars
  df$wt[1] <- NA
  spec <- glyph(df, x = wt, y = mpg) |>
    mark_point() |>
    mark_bar(x = cyl, y = mpg)

  expect_warning(compiled <- compile(spec), "Removed 1 row")
  # The bar mark doesn't map wt at all, so none of its rows are dropped.
  bar_values <- compiled$spec$marks[[2]]$data$values
  expect_equal(length(bar_values), nrow(df))
})

# ---- Facets combined with computed mappings and NA handling ---------------

test_that("facet() on a plain column is unaffected", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(cols = cyl)
  compiled <- compile(spec)

  expect_equal(compiled$spec$facets$cols, "cyl")
  top_row1 <- compiled$spec$data$values[[1]]
  expect_true("cyl" %in% names(top_row1))
})

test_that("facet() on a computed expression is evaluated into a real field", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(cols = factor(cyl))
  compiled <- compile(spec)

  facet_field <- compiled$spec$facets$cols
  expect_false(is.null(facet_field))
  expect_false(identical(facet_field, "factor(cyl)"))

  # The generated column must be present on BOTH the shared top-level data
  # (used to enumerate the set of facet values) and each mark's own
  # resolved data (used to slice that mark's rows per facet cell) —
  # otherwise faceting would work for the panel grid but marks within each
  # panel would show every row again.
  top_row1 <- compiled$spec$data$values[[1]]
  mark_row1 <- compiled$spec$marks[[1]]$data$values[[1]]
  expect_true(facet_field %in% names(top_row1))
  expect_true(facet_field %in% names(mark_row1))

  # Values should match factor(cyl) applied to the first row.
  expect_equal(as.character(top_row1[[facet_field]]), as.character(factor(mtcars$cyl[1])))
})

test_that("facet() on rows and cols can both be computed expressions", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(rows = factor(am), cols = factor(cyl))
  compiled <- compile(spec)

  expect_false(identical(compiled$spec$facets$rows, "factor(am)"))
  expect_false(identical(compiled$spec$facets$cols, "factor(cyl)"))
  expect_false(identical(compiled$spec$facets$rows, compiled$spec$facets$cols))

  mark_row1 <- compiled$spec$marks[[1]]$data$values[[1]]
  expect_true(compiled$spec$facets$rows %in% names(mark_row1))
  expect_true(compiled$spec$facets$cols %in% names(mark_row1))
})

test_that("facet() on an unresolvable expression falls back instead of erroring", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(cols = totally_unknown_col_xyz)
  expect_no_error(compiled <- compile(spec))
  expect_equal(compiled$spec$facets$cols, "totally_unknown_col_xyz")
})

test_that("a computed mapping still resolves correctly when facet() is also used", {
  spec <- glyph(mtcars, x = log(wt), y = mpg) |>
    mark_point() |>
    facet(cols = cyl)
  compiled <- compile(spec)

  enc <- compiled$spec$marks[[1]]$encoding
  mark_row1 <- compiled$spec$marks[[1]]$data$values[[1]]
  expect_equal(mark_row1[[enc$x$field]], log(mtcars$wt[1]))
  # The mark's own data must also carry the facet field, so each facet
  # panel can filter this mark's (computed) rows by facet value.
  expect_true("cyl" %in% names(mark_row1))
})

test_that("NA-dropping still applies to a mark's resolved data when facet() is also used", {
  df <- mtcars
  df$wt[c(2, 5)] <- NA
  spec <- glyph(df, x = wt, y = mpg) |>
    mark_point() |>
    facet(cols = cyl)

  expect_warning(compiled <- compile(spec), "Removed 2 row")
  mark_values <- compiled$spec$marks[[1]]$data$values
  expect_equal(length(mark_values), nrow(df) - 2)
  # Every remaining row must still carry the facet field.
  expect_true(all(vapply(mark_values, function(r) "cyl" %in% names(r), logical(1))))
})

test_that("NA-dropping and a computed facet expression combine correctly", {
  df <- mtcars
  df$wt[1] <- NA
  spec <- glyph(df, x = wt, y = mpg) |>
    mark_point() |>
    facet(cols = factor(cyl))

  expect_warning(compiled <- compile(spec), "Removed 1 row")
  facet_field <- compiled$spec$facets$cols
  mark_values <- compiled$spec$marks[[1]]$data$values
  expect_equal(length(mark_values), nrow(df) - 1)
  expect_true(all(vapply(mark_values, function(r) facet_field %in% names(r), logical(1))))
})
