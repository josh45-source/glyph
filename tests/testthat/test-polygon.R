# mark_polygon(): rows are vertices, collected into one record per polygon at
# compile time (stat_polygon() in R/stats.R). Rendering is checked separately
# in a browser.

polygon_records <- function(spec, i = 1) compile(spec)$spec$marks[[i]]$data$values
as_xy <- function(r) cbind(as.numeric(r$.x), as.numeric(r$.y))

shapes <- data.frame(
  id   = rep(c("tri", "square", "notch"), times = c(3, 4, 6)),
  name = rep(c("Triangle", "Square", "Notch"), times = c(3, 4, 6)),
  x    = c(0, 2, 1,   3, 5, 5, 3,   6, 9, 9, 7.5, 6, 6),
  y    = c(0, 0, 2,   0, 0, 2, 2,   0, 0, 3, 1.5, 3, 0.5),
  size = c(1:13)
)

test_that("mark_polygon() keeps each group's vertices in row order", {
  recs <- polygon_records(glyph(shapes, x = x, y = y) |> mark_polygon(group = id))
  expect_length(recs, 3)
  by_id <- setNames(recs, vapply(recs, function(r) r$id, ""))
  for (id in unique(shapes$id)) {
    rows <- which(shapes$id == id)
    expect_equal(as_xy(by_id[[id]]), cbind(shapes$x[rows], shapes$y[rows]), ignore_attr = TRUE)
    expect_equal(as.integer(by_id[[id]]$.rows), rows - 1L)
    expect_equal(by_id[[id]]$.n, length(rows))
  }
})

test_that("mark_polygon() without a group draws all rows as one polygon", {
  recs <- polygon_records(glyph(shapes, x = x, y = y) |> mark_polygon())
  expect_length(recs, 1)
  expect_equal(as_xy(recs[[1]]), cbind(shapes$x, shapes$y), ignore_attr = TRUE)
})

test_that("mark_polygon() keeps columns that are constant within a polygon", {
  recs <- polygon_records(glyph(shapes, x = x, y = y) |> mark_polygon(group = id))
  expect_equal(vapply(recs, function(r) r$name, ""), c("Notch", "Square", "Triangle"))
  expect_false(any(vapply(recs, function(r) "size" %in% names(r), logical(1))))
})

test_that("mark_polygon() splits a polygon whose rows have different colours", {
  df <- shapes
  df$part <- c(rep("a", 3), rep("b", 4), rep("c", 3), rep("d", 3))
  recs <- polygon_records(glyph(df, x = x, y = y) |> mark_polygon(group = id, color = part))
  expect_length(recs, 4)
  expect_setequal(vapply(recs, function(r) r$part, ""), c("a", "b", "c", "d"))
  c_part <- Filter(function(r) r$part == "c", recs)[[1]]
  expect_equal(as.numeric(c_part$.x), c(6, 9, 9))
})

test_that("mark_polygon() evaluates computed mappings", {
  recs <- polygon_records(
    glyph(shapes, x = x * 10, y = -y) |> mark_polygon(group = toupper(id))
  )
  sq <- recs[[which(vapply(recs, function(r) r[[".g_polygon_1_group"]], "") == "SQUARE")]]
  expect_equal(as.numeric(sq$.x), c(30, 50, 50, 30))
  expect_equal(as.numeric(sq$.y), c(0, 0, -2, -2))
})

test_that("mark_polygon() drops missing vertices and polygons too small to draw", {
  df <- shapes
  df$y[2] <- NA          # the triangle loses a vertex
  df$x[5] <- NA          # the square loses one too
  expect_warning(
    expect_warning(
      recs <- polygon_records(glyph(df, x = x, y = y) |> mark_polygon(group = id)),
      "Removed 2 rows"
    ),
    "1 polygon in mark \"polygon_1\" has fewer than three vertices and was left out"
  )
  ids <- vapply(recs, function(r) r$id, "")
  expect_setequal(ids, c("square", "notch"))
  sq <- recs[[which(ids == "square")]]
  expect_equal(as_xy(sq), cbind(c(3, 5, 3), c(0, 2, 2)), ignore_attr = TRUE)
  # .rows indexes the rows left after dropping (the mark's own data).
  expect_equal(as.integer(sq$.rows), c(2L, 3L, 4L))
})

test_that("the too-small warning agrees in number", {
  df <- data.frame(id = c("a", "a", "b", "b", "c", "c", "c"), x = c(0, 1, 0, 1, 0, 1, 0), y = c(0, 1, 0, 1, 0, 0, 1))
  expect_warning(glyph(df, x = x, y = y) |> mark_polygon(group = id) |> compile(),
                 "2 polygons in mark .* have fewer than three vertices and were left out")
})

test_that("mark_polygon() treats a missing group as a polygon of its own", {
  df <- shapes
  df$id[shapes$id == "square"] <- NA
  recs <- polygon_records(glyph(df, x = x, y = y) |> mark_polygon(group = id))
  expect_length(recs, 3)
  expect_true(any(vapply(recs, function(r) is.na(r$id), logical(1))))
})

test_that("mark_polygon() splits polygons by facet panel", {
  df <- rbind(transform(shapes, panel = "left"), transform(shapes, panel = "right", x = x + 1))
  recs <- polygon_records(glyph(df, x = x, y = y) |> mark_polygon(group = id) |> facet(cols = panel))
  expect_length(recs, 6)
  right <- Filter(function(r) r$panel == "right" && r$id == "tri", recs)[[1]]
  expect_equal(as.numeric(right$.x), c(1, 3, 2))
})

test_that("mark_polygon() works inside compose() and keeps interaction settings", {
  p <- glyph(shapes, x = x, y = y) |>
    mark_polygon(group = id, color = id, radius = 4, style = list(stroke = "#000")) |>
    interact(tooltip = "{name}", brush = TRUE, zoom = TRUE)
  panels <- compile(compose(p, p, linked_selections = TRUE))$spec$panels
  expect_equal(panels[[1]]$marks[[1]]$type, "polygon")
  expect_equal(panels[[1]]$marks[[1]]$style$radius, 4)
  expect_equal(panels[[1]]$marks[[1]]$style$stroke, "#000")
  expect_equal(panels[[1]]$interact$tooltip$template, "{name}")
})

test_that("mark_polygon() vertex arrays stay arrays in JSON", {
  json <- compile(glyph(shapes, x = x, y = y) |> mark_polygon(group = id))$json
  expect_match(json, '".x":[3,5,5,3]', fixed = TRUE)
})

test_that("mark_polygon() checks its arguments", {
  p <- glyph(shapes, x = x, y = y)
  expect_error(mark_polygon(p, radius = -1), "radius")
  expect_error(compile(glyph(shapes, x = id, y = y) |> mark_polygon()), "numeric")
})
