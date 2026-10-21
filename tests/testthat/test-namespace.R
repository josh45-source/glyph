# glyph must not mask functions from the packages R attaches at startup:
# library(glyph) printed "The following object is masked from
# 'package:base': scale", and base uses of scale() then failed (#36).

test_that("glyph exports nothing with the name of a function R attaches at startup", {
  attached <- c("stats", "graphics", "grDevices", "utils", "datasets", "methods")
  startup <- unique(c(ls(baseenv(), all.names = TRUE), unlist(lapply(attached, getNamespaceExports))))
  expect_identical(intersect(getNamespaceExports("glyph"), startup), character())
})

test_that("scale() is base::scale() once glyph is attached", {
  if (!"package:glyph" %in% search()) {
    library(glyph)
    withr::defer(detach("package:glyph"))
  }
  # Looked up from the global environment, as in a script or the console.
  scaled <- eval(quote(scale(c(1, 2, 3))), new.env(parent = globalenv()))
  expect_identical(scaled, base::scale(c(1, 2, 3)))
  expect_equal(as.vector(scaled), c(-1, 0, 1))
})

test_that("set_scale() and its shortcuts set the same scale config", {
  p <- glyph(mtcars, x = wt, y = mpg) |> mark_point(color = factor(cyl))
  expect_identical(
    scale_color(p, "Set2")$scales$color,
    set_scale(p, "color", range = "Set2")$scales$color
  )
  expect_identical(
    scale_log(p, "y", base = 2)$scales$y,
    set_scale(p, "y", type = "log", base = 2)$scales$y
  )
  expect_identical(
    scale_time(p, "x")$scales$x,
    set_scale(p, "x", type = "time")$scales$x
  )
})
