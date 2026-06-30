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

  expect_equal(spec$facets$cols, "cyl")
  expect_equal(spec$facets$free_scales, "both")
  expect_null(spec$facets$rows)
})

test_that("facet() with rows and cols", {
  spec <- glyph(mtcars, x = wt, y = mpg) |>
    mark_point() |>
    facet(rows = gear, cols = cyl)

  expect_equal(spec$facets$rows, "gear")
  expect_equal(spec$facets$cols, "cyl")
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

test_that("compile() auto-selects engine by data size", {
  small <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  compiled_small <- compile(small)
  expect_equal(compiled_small$engine, "html")

  big_data <- mtcars[rep(seq_len(32), 3200), ]
  big <- glyph(big_data, x = wt, y = mpg) |> mark_point()
  compiled_big <- compile(big)
  expect_equal(compiled_big$engine, "webgl")
})

test_that("compile() respects explicit engine", {
  spec <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  compiled <- compile(spec, engine = "canvas")
  expect_equal(compiled$engine, "canvas")
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
