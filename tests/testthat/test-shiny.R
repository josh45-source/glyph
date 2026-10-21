# glyphOutput() and renderGlyph(), and the value input$<id>_selected takes.
# test-browser-shiny.R checks what a running app receives.

# What renderGlyph() sends for `x`, parsed: the widget's data, or NULL.
rendered <- function(x) {
  value <- NULL
  shiny::testServer(function(input, output, session) output$plot <- renderGlyph(x), {
    value <<- output$plot
  })
  if (is.null(value)) NULL else jsonlite::fromJSON(value, simplifyVector = FALSE)
}

test_that("glyphOutput() makes a glyph output element", {
  skip_if_not_installed("shiny")
  out <- glyphOutput("plot", height = "300px")
  html <- as.character(out)
  expect_match(html, 'id="plot"')
  expect_match(html, 'class="glyph html-widget html-widget-output')
  expect_match(html, "height:300px")
  expect_match(as.character(glyphOutput("plot", width = 500)), "width:500px")
})

test_that("renderGlyph() takes a spec, a layout or a widget", {
  skip_if_not_installed("shiny")
  p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  from_spec <- rendered(p)
  expect_identical(from_spec$x$spec$`$schema`, "glyph/v0.2")
  expect_identical(from_spec$x$spec$marks[[1]]$type, "point")
  expect_identical(rendered(render(p))$x$spec$marks, from_spec$x$spec$marks)
  layout <- rendered(compose(p, p))
  expect_identical(layout$x$spec$type, "layout")
  expect_length(layout$x$spec$panels, 2)
  # NULL shows nothing, and clears any selection: the widget gets no plot.
  expect_identical(rendered(NULL)$x, list(empty = TRUE))
})

test_that("renderGlyph() evaluates its expression in `env`, or a quoted one", {
  skip_if_not_installed("shiny")
  env <- new.env()
  env$cars <- mtcars[1:5, ]
  value <- NULL
  shiny::testServer(function(input, output, session) {
    output$plot <- renderGlyph(quote(glyph(cars, x = wt, y = mpg) |> mark_point()), env = env, quoted = TRUE)
  }, {
    value <<- jsonlite::fromJSON(output$plot, simplifyVector = FALSE)
  })
  expect_identical(value$x$spec$data$n, 5L)
})

test_that("renderGlyph() converts what its expression returns early", {
  skip_if_not_installed("shiny")
  value <- NULL
  shiny::testServer(function(input, output, session) {
    output$plot <- renderGlyph({
      if (TRUE) return(glyph(mtcars, x = wt, y = mpg) |> mark_point())
      NULL
    })
  }, {
    value <<- jsonlite::fromJSON(output$plot, simplifyVector = FALSE)
  })
  expect_identical(value$x$spec$marks[[1]]$type, "point")
})

test_that("renderGlyph() says what it needs when given something else", {
  skip_if_not_installed("shiny")
  expect_error(rendered(mtcars), "needs a plot from")
})

test_that("Shiny can read selections from glyph widgets", {
  skip_if_not_installed("shiny")
  loadNamespace("shiny")
  # Registered when shiny is loaded, so it is there before any app runs:
  # shiny refuses to register a second handler for it.
  expect_error(shiny::registerInputHandler("glyph.selection", identity), "already")
})

test_that("selections become row numbers, or one entry per layout panel", {
  # Shiny hands the handler the JSON parsed without simplifying, so arrays
  # arrive as lists.
  as_shiny <- function(json) selection_from_json(jsonlite::parse_json(json, simplifyVector = FALSE))
  expect_null(as_shiny("null"))
  expect_identical(as_shiny("[3, 18, 20]"), c(3L, 18L, 20L))
  expect_identical(as_shiny("[]"), integer())
  expect_identical(as_shiny('{"panels": [[1, 2], null]}'), list(1:2, NULL))
  expect_identical(
    as_shiny('{"panels": [[1, 2], {"panels": [null, [5]]}], "names": ["cars", "more"]}'),
    list(cars = 1:2, more = list(NULL, 5L))
  )
})

test_that("statistical marks say which plot rows they kept", {
  df <- data.frame(g = c("a", "a", "b", "b", "b"), v = c(1, NA, 2, NA, 3))
  marks <- suppressWarnings(compile(
    glyph(df, x = g, y = v) |> mark_boxplot() |> mark_sina() |> mark_point()
  ))$spec$marks
  # Box and sina rows count only the rows kept, so these map them back.
  expect_equal(as.integer(marks[[1]]$plot_rows), c(0L, 2L, 4L))
  expect_equal(as.integer(marks[[2]]$plot_rows), c(0L, 2L, 4L))
  # A mark drawing the plot's rows names them in its data instead.
  expect_null(marks[[3]]$plot_rows)
  expect_equal(as.integer(marks[[3]]$data$rows), c(0L, 2L, 4L))
  # With nothing dropped there is nothing to map.
  expect_null(compile(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot())$spec$marks[[1]]$plot_rows)
})

test_that("a mark sending its own copy of the plot's rows says which they are", {
  # The data already has a column named like the one computed for `log(a)`,
  # so the mark can't refer to the plot's columns and sends its own.
  df <- data.frame(a = c(1, NA, 4), b = c(2, 3, 5), .g_point_1_x = c(9, 9, 9))
  mark <- suppressWarnings(compile(glyph(df, x = log(a), y = b) |> mark_point()))$spec$marks[[1]]
  expect_false(identical(mark$data$from, "plot"))
  expect_equal(as.integer(mark$plot_rows), c(0L, 2L))
})

test_that("a mark with its own data takes no part in the plot's selection", {
  other <- data.frame(x = 1:3, y = 3:1)
  marks <- compile(glyph(mtcars, x = wt, y = mpg) |> mark_point() |>
    mark_line(data = other, x = x, y = y))$spec$marks
  expect_null(marks[[1]]$own_data)
  expect_true(marks[[2]]$own_data)
})

test_that("compose() sends its panels in order, with their names", {
  p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  spec <- compile(compose(cars = p, again = p))$spec
  json <- jsonlite::fromJSON(compile(compose(cars = p, again = p))$json, simplifyVector = FALSE)
  # An array, not an object keyed by name, which the renderer couldn't draw.
  expect_null(names(json$panels))
  expect_length(json$panels, 2)
  expect_identical(unlist(json$panel_names), c("cars", "again"))
  expect_null(compile(compose(p, p))$spec$panel_names)
})

test_that("the example app lists the selected cars", {
  skip_if_not_installed("shiny")
  app <- system.file("examples", "shiny-brush", package = "glyph")
  shiny::testServer(shiny::shinyAppDir(app), {
    expect_identical(output$count, "No cars selected.")
    session$setInputs(plot_selected = c(1L, 3L))
    expect_identical(output$count, "2 cars selected.")
    expect_match(output$rows, "Mazda RX4")
    expect_match(output$rows, "Datsun 710")
    expect_no_match(output$rows, "Hornet")
    session$setInputs(plot_selected = 5L)
    expect_identical(output$count, "1 car selected.")
  })
})
