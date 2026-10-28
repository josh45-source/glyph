# The row numbers a widget reports as its selection: what Shiny receives as
# input$<id>_selected (see R/shiny.R and selectionValue() in glyph.js). These
# tests read the widget's "glyph-selection" events, which carry the same
# value, so they cover many cases without starting a Shiny app;
# test-browser-shiny.R runs a real one. Expected rows are computed here, in R,
# from the data.

# Records what each widget reports, under the id of the div it was saved in
# (see save_widgets() in helper-browser.R).
watch_selections <- function(s) {
  js(s, "window.__selections = {};
    document.querySelectorAll('body > div[id]').forEach(div => {
      const seen = window.__selections[div.id] = [];
      div.querySelector('.html-widget').addEventListener('glyph-selection', e => seen.push(e.detail));
    }); true")
}

# Every value the widget in div `id` has reported, as the server would get it.
reported <- function(s, id) {
  lapply(js(s, sprintf("window.__selections['%s']", id)), selection_from_json)
}

# The value the server would hold now: the last one reported.
current <- function(s, id) {
  values <- reported(s, id)
  if (length(values) == 0) return(NULL)
  values[[length(values)]]
}

# Rows 2 and 3 have a missing position, so the marks drop them.
gaps <- data.frame(
  a = c(1.3, NA, 2.5, 3.1, 4.7, 2.2, 3.8),
  b = c(2.1, 3.3, NA, 4.4, 1.6, 3.0, 2.6),
  grp = c("p", "q", "p", "q", "r", "r", "p")
)
kept <- which(!is.na(gaps$a) & !is.na(gaps$b))

test_that("a brush reports rows of the data, after NA dropping and with computed mappings", {
  skip_if_no_browser()
  s <- open_page(save_widgets(list(
    plain = render(suppressWarnings(compile(
      glyph(gaps, x = a, y = b) |> mark_point() |> interact(brush = TRUE)))),
    computed = render(suppressWarnings(compile(
      glyph(gaps, x = log(a), y = b * 2) |> mark_point() |> interact(brush = TRUE)))),
    # The second mark draws rows of another data frame, which aren't rows
    # of the plot's data.
    other = render(suppressWarnings(compile(
      glyph(gaps, x = a, y = b) |> mark_point() |>
        mark_point(data = data.frame(a = c(2, 4), b = c(2, 4)), x = a, y = b) |>
        interact(brush = TRUE))))
  )), width = 800, height = 1500)
  watch_selections(s)

  for (id in c("plain", "computed", "other")) {
    brush_over(s, id)
    expect_identical(current(s, id), kept)
    brush_around(s, id, ".marks-point circle", "d.a < 2.4")
    expect_identical(current(s, id), which(gaps$a < 2.4 & !is.na(gaps$b)))
  }
  # A brush over empty space selects no rows, which is not the same as no
  # selection.
  brush_over(s, "plain", from = c(0.9, 0.02), to = c(0.98, 0.1))
  expect_identical(current(s, "plain"), integer())
  expect_length(page_errors(s), 0)
})

test_that("a selected box, bin or sina point selects the rows it draws", {
  skip_if_no_browser()
  groups <- data.frame(
    g = rep(c("a", "b", "c"), times = c(5, 6, 4)),
    v = c(1, NA, 2, 3, 4, 2, NA, 3, 5, 6, 4, 7, NA, 8, 9)
  )
  s <- open_page(save_widgets(list(
    box = render(suppressWarnings(compile(
      glyph(groups, x = g, y = v) |> mark_boxplot() |> interact(brush = TRUE)))),
    sina = render(suppressWarnings(compile(
      glyph(groups, x = g, y = v) |> mark_sina() |> interact(brush = TRUE)))),
    hist = render(suppressWarnings(compile(
      glyph(groups, x = v) |> mark_histogram(bins = 4) |> interact(click = "select"))))
  )), width = 800, height = 1400)
  watch_selections(s)

  # A tap on a box, with brushing on, is passed through to the box as a click.
  brush_around(s, "box", ".glyph-box-rect", "d.g === 'b'")
  expect_identical(current(s, "box"), which(groups$g == "b" & !is.na(groups$v)))
  brush_over(s, "box")
  expect_identical(current(s, "box"), which(!is.na(groups$v)))

  brush_over(s, "sina")
  expect_identical(current(s, "sina"), which(!is.na(groups$v)))
  brush_around(s, "sina", ".marks-sina circle", "d.g === 'c'")
  expect_identical(current(s, "sina"), which(groups$g == "c" & !is.na(groups$v)))

  # The first bin holds every value up to its upper edge.
  upper <- unlist(js(s, "document.querySelector('#hist .glyph-bin').__data__['.x1']"))
  click_on(s, "hist", ".glyph-bin", "true")
  expect_identical(current(s, "hist"), which(groups$v <= upper))
  expect_length(page_errors(s), 0)
})

test_that("click and legend selections report rows, and clearing reports NULL", {
  skip_if_no_browser()
  s <- open_page(save_widgets(list(
    click = render(suppressWarnings(compile(
      glyph(gaps, x = a, y = b) |> mark_point(color = grp) |> interact(click = "select") |>
        selection("legend", type = "legend")))),
    brush = render(suppressWarnings(compile(
      glyph(gaps, x = a, y = b) |> mark_point() |> interact(brush = TRUE))))
  )), width = 800, height = 1000)
  watch_selections(s)

  click_on(s, "click", ".marks-point circle", "d.a === 3.1")
  expect_identical(current(s, "click"), 4L)
  # Clicking the selected point again clears the selection.
  click_on(s, "click", ".marks-point circle", "d.a === 3.1")
  expect_null(current(s, "click"))

  # Hiding group "q" leaves the rows of "p" and "r" selected.
  click_on(s, "click", ".legend-item rect", "d === 'q'")
  expect_identical(current(s, "click"), intersect(kept, which(gaps$grp != "q")))
  click_on(s, "click", ".legend-item rect", "d === 'q'")
  expect_null(current(s, "click"))

  # One value per brush, sent when it ends, not while it is dragged.
  n <- length(reported(s, "brush"))
  brush_over(s, "brush")
  expect_length(reported(s, "brush"), n + 1)
  expect_identical(current(s, "brush"), kept)

  # The Clear selection button, Escape and a click on an empty spot all clear it.
  btn <- centre_of(s, "#brush .glyph-clear-selection")
  click_at(s, btn[1], btn[2])
  expect_null(current(s, "brush"))
  brush_over(s, "brush")
  s$Input$dispatchKeyEvent(type = "keyDown", key = "Escape", code = "Escape", windowsVirtualKeyCode = 27)
  wait_until(s, "window.__selections.brush.at(-1) === null")
  brush_over(s, "brush", to = c(0.5, 1))
  expect_identical(current(s, "brush"), intersect(kept, which(gaps$a < 3)))
  # The top right corner of the plot, outside the brush and away from every
  # point.
  corner <- unlist(js(s, "(() => { const b = document.querySelector('#brush .brush .overlay').getBoundingClientRect();
    return [b.right - 3, b.top + 3]; })()"))
  click_at(s, corner[1], corner[2])
  expect_null(current(s, "brush"))

  # A redraw (here, after the plot is resized) removes the selection, and
  # says so.
  brush_over(s, "brush")
  expect_identical(current(s, "brush"), kept)
  js(s, "document.querySelector('#brush .html-widget').style.width = '500px'; window.dispatchEvent(new Event('resize')); true")
  wait_until(s, "window.__selections.brush.at(-1) === null")
  expect_length(page_errors(s), 0)
})

test_that("a facet grid reports one vector and a layout one entry per panel", {
  skip_if_no_browser()
  scatter <- glyph(gaps, x = a, y = b) |> mark_point() |> interact(brush = TRUE)
  boxes <- glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot() |> interact(click = "select")
  s <- open_page(save_widgets(list(
    facets = render(suppressWarnings(compile(scatter |> facet(cols = grp)))),
    named = render(suppressWarnings(compile(compose(scatter = scatter, boxes = boxes)))),
    nested = render(suppressWarnings(compile(compose(scatter, compose(boxes, scatter))))),
    linked = render(suppressWarnings(compile(compose(scatter, scatter, linked_selections = TRUE))))
  )), width = 1000, height = 1900)
  watch_selections(s)

  # Panels are in sorted order: p, q, r.
  brush_over(s, "facets", n = 1)
  expect_identical(current(s, "facets"), intersect(kept, which(gaps$grp == "p")))
  brush_over(s, "facets", n = 3)
  expect_identical(current(s, "facets"), intersect(kept, which(gaps$grp %in% c("p", "r"))))

  click_on(s, "named", ".glyph-box-rect", "d['.g_boxplot_1_x'] === '6'")
  expect_identical(current(s, "named"), list(scatter = NULL, boxes = which(mtcars$cyl == 6)))
  brush_over(s, "named")
  expect_identical(current(s, "named"), list(scatter = kept, boxes = which(mtcars$cyl == 6)))
  # A click outside a brushed plot clears its brush, here by selecting
  # another box.
  click_on(s, "named", ".glyph-box-rect", "d['.g_boxplot_1_x'] === '4'")
  expect_identical(current(s, "named"), list(scatter = NULL, boxes = which(mtcars$cyl == 4)))
  click_on(s, "named", ".glyph-box-rect", "d['.g_boxplot_1_x'] === '4'")
  expect_null(current(s, "named"))

  # The second brushable plot is the scatter inside the inner layout.
  brush_over(s, "nested", n = 2)
  expect_identical(current(s, "nested"), list(NULL, list(NULL, kept)))

  # A linked panel highlights the selection but reports only its own.
  brush_over(s, "linked", n = 1, to = c(0.5, 1))
  expect_identical(current(s, "linked"), list(intersect(kept, which(gaps$a < 3)), NULL))
  expect_true(js(s, "[...document.querySelectorAll('#linked .glyph-plot')][1].querySelectorAll('circle[opacity=\"0.15\"]').length > 0"))
  expect_length(page_errors(s), 0)
})

test_that("a brush on a date axis reports the rows of those dates (#39)", {
  skip_if_no_browser()
  econ <- data.frame(
    date = seq(as.Date("1967-07-01"), by = "month", length.out = 24),
    unemploy = seq(2900, by = 50, length.out = 24)
  )
  s <- open_page(save_widgets(list(
    dates = render(glyph(econ, x = date, y = unemploy) |> mark_point() |> interact(brush = TRUE))
  )), timezone = "America/Los_Angeles")
  watch_selections(s)
  brush_around(s, "dates", ".marks-point circle", "d.date < new Date(Date.UTC(1968, 6, 1))")
  expect_identical(current(s, "dates"), which(econ$date < as.Date("1968-07-01")))
  expect_length(page_errors(s), 0)
})
