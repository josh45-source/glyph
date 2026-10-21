# Each test here covers a bug we've had in the browser. See helper-browser.R
# for how they run and when they're skipped.

shapes <- data.frame(
  id = rep(c("tri", "square", "notch"), times = c(3, 4, 6)),
  x = c(0, 2, 1, 3, 5, 5, 3, 6, 9, 9, 7.5, 6, 6),
  y = c(0, 0, 2, 0, 0, 2, 2, 0, 0, 3, 1.5, 3, 0.5)
)

test_that("plots draw at all (the 0.1.0 blank plot)", {
  skip_if_no_browser()
  point <- glyph(mtcars, x = wt, y = mpg) |> mark_point(color = factor(cyl))
  bar <- glyph(mtcars, x = factor(cyl), y = mpg) |> mark_bar()
  widgets <- list(
    point = render(point),
    line = render(glyph(data.frame(x = 1:20, y = cumsum(sin(1:20))), x = x, y = y) |> mark_line()),
    bar = render(bar),
    facet = render(point |> facet(cols = am)),
    compose = render(compose(point, bar)),
    boxplot = render(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot()),
    histogram = render(glyph(mtcars, x = mpg) |> mark_histogram()),
    polygon = render(glyph(shapes, x = x, y = y) |> mark_polygon(group = id))
  )
  s <- open_page(save_widgets(widgets), width = 1000, height = 800)
  counts <- js(s, "Object.fromEntries([...document.querySelectorAll('body > div[id]')].map(d =>
    [d.id, d.querySelectorAll('g.glyph-plot circle:not(.glyph-outlier), g.glyph-plot .marks-bar rect, path.marks-line, .glyph-box, .glyph-bin, .glyph-polygon').length]))")
  expect_equal(counts$point, 32)
  expect_equal(counts$line, 1)
  expect_equal(counts$bar, 32)
  expect_equal(counts$facet, 32)
  expect_equal(counts$compose, 64)
  expect_equal(counts$boxplot, 3)
  expect_gt(counts$histogram, 3)
  expect_equal(counts$polygon, 3)
  expect_length(page_errors(s), 0)
})

test_that("slide-animated bars end at their full height", {
  skip_if_no_browser()
  df <- data.frame(g = c("a", "b", "c", "d"), v = c(3, 7, 5, 9))
  bars <- glyph(df, x = g, y = v) |> mark_bar()
  s <- open_page(save_widgets(list(
    still = render(bars),
    slide = render(bars |> animate(transition = "slide", stagger = 30))
  )))
  geometry <- function(id) unlist(js(s, sprintf(
    "[...document.querySelectorAll('#%s .marks-bar rect')].flatMap(r => [+r.getAttribute('y'), +r.getAttribute('height')])", id)))
  # Wait until the animation has finished: the bars stop changing.
  repeat { g1 <- geometry("slide"); Sys.sleep(0.3); if (identical(g1, geometry("slide"))) break }
  # The animation ends exactly where the bars are drawn without one.
  expect_equal(geometry("slide"), geometry("still"))
  heights <- geometry("slide")[c(FALSE, TRUE)]
  expect_true(all(heights > 0))
})

test_that("bars, areas and histograms start at zero (#29)", {
  skip_if_no_browser()
  df <- data.frame(g = c("a", "b", "c", "d"), v = c(3, 7, 5, 9))
  signed <- data.frame(g = c("a", "b", "c"), v = c(-3, 5, 2))
  series <- data.frame(t = 1:6, v = c(4, 6, 5, 8, 7, 9))
  s <- open_page(save_widgets(list(
    bar = render(glyph(df, x = g, y = v) |> mark_bar()),
    signed = render(glyph(signed, x = g, y = v) |> mark_bar()),
    area = render(glyph(series, x = t, y = v) |> mark_area()),
    histogram = render(glyph(mtcars, x = mpg) |> mark_histogram()),
    domain = render(glyph(df, x = g, y = v) |> mark_bar() |> set_scale("y", domain = c(2, 10))),
    point = render(glyph(df, x = v, y = v) |> mark_point()),
    line = render(glyph(series, x = t, y = v) |> mark_line())
  )), width = 800, height = 3200)
  js(s, AXIS_JS)
  # Each bar's two ends, in data units: [value end, baseline end].
  bar_ends <- function(id) {
    ends <- js(s, sprintf("(() => { const root = document.getElementById('%s'), y = axisMap('y', root);
      return [...root.querySelectorAll('.marks-bar rect')].map(r =>
        [y(+r.getAttribute('y')), y(+r.getAttribute('y') + +r.getAttribute('height'))]); })()", id))
    lapply(ends, unlist)
  }
  lowest_tick <- function(id) js(s, sprintf(
    "Math.min(...[...document.querySelectorAll('#%s .axis-y .tick text')].map(t => parseFloat(t.textContent.replace('\u2212', '-'))))", id))

  # Bars run from zero to their value, so every bar has its height.
  ends <- bar_ends("bar")
  expect_equal(vapply(ends, `[`, numeric(1), 1), df$v, tolerance = 0.05)
  expect_equal(vapply(ends, `[`, numeric(1), 2), rep(0, 4), tolerance = 0.05)

  # A negative bar hangs down from zero.
  ends <- bar_ends("signed")
  expect_equal(vapply(ends, function(e) min(e), numeric(1)), pmin(signed$v, 0), tolerance = 0.05)
  expect_equal(vapply(ends, function(e) max(e), numeric(1)), pmax(signed$v, 0), tolerance = 0.05)

  # The area is filled down to zero.
  area_bottom <- js(s, "(() => { const root = document.getElementById('area'), y = axisMap('y', root);
    const ys = root.querySelector('path.marks-area').getAttribute('d').match(/-?[\\d.]+(e-?\\d+)?/g).map(Number).filter((v, i) => i % 2 === 1);
    return y(Math.max(...ys)); })()")
  expect_equal(area_bottom, 0, tolerance = 0.05)

  # Histogram counts start at zero.
  expect_equal(lowest_tick("histogram"), 0)

  # A domain set with set_scale() wins: the axis starts at 2, and bars rise from
  # the bottom of the plot.
  expect_equal(lowest_tick("domain"), 2)
  ends <- bar_ends("domain")
  expect_equal(vapply(ends, `[`, numeric(1), 1), df$v, tolerance = 0.05)
  expect_equal(vapply(ends, `[`, numeric(1), 2), rep(2, 4), tolerance = 0.05)

  # Points and lines don't get a zero baseline.
  expect_gt(lowest_tick("point"), 0)
  expect_gt(lowest_tick("line"), 0)
  expect_length(page_errors(s), 0)
})

test_that("the x axis is visible in a wide, short container (#17)", {
  skip_if_no_browser()
  p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  for (plot in list(p, p |> facet(cols = am))) {
    s <- open_page(save_page(plot), width = 1200, height = 320)
    bottoms <- js(s, "(() => {
      const labels = [...document.querySelectorAll('.axis-x .tick text')].map(t => t.getBoundingClientRect().bottom);
      return { labels: Math.max(...labels), widget: document.querySelector('.html-widget').getBoundingClientRect().bottom,
               view: innerHeight, n: labels.length };
    })()")
    expect_gt(bottoms$n, 0)
    expect_lte(bottoms$labels, bottoms$widget)
    expect_lte(bottoms$labels, bottoms$view)
  }
})

test_that("boxes are drawn at the quartiles", {
  skip_if_no_browser()
  s <- open_page(save_page(glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot()))
  js(s, AXIS_JS)
  drawn <- js(s, "(() => { const y = axisMap('y');
    return [...document.querySelectorAll('.glyph-box')]
      .map(b => ({ x: +b.querySelector('rect').getAttribute('x'),
                   upper: y(+b.querySelector('rect').getAttribute('y')),
                   lower: y(+b.querySelector('rect').getAttribute('y') + +b.querySelector('rect').getAttribute('height')),
                   median: y(+b.querySelector('.glyph-median').getAttribute('y1')) }))
      .sort((a, b) => a.x - b.x); })()")
  for (i in seq_along(drawn)) {
    q <- stats::quantile(mtcars$mpg[mtcars$cyl == c(4, 6, 8)[i]], c(0.25, 0.5, 0.75), names = FALSE)
    expect_equal(c(drawn[[i]]$lower, drawn[[i]]$median, drawn[[i]]$upper), q, tolerance = 0.01)
  }
})

test_that("histogram bars count every row, in the right bins", {
  skip_if_no_browser()
  s <- open_page(save_page(glyph(mtcars, x = mpg) |> mark_histogram()))
  js(s, AXIS_JS)
  bins <- js(s, "(() => { const x = axisMap('x'), y = axisMap('y');
    return [...document.querySelectorAll('.glyph-bin')].map(r => {
      const rx = +r.getAttribute('x'), w = +r.getAttribute('width'), ry = +r.getAttribute('y'), h = +r.getAttribute('height');
      return { x0: x(rx - 0.5), x1: x(rx + w + 0.5), count: y(ry) - y(ry + h) };
    }).sort((a, b) => a.x0 - b.x0); })()")
  # Sturges bins on pretty breaks, closed on the right, as hist() makes them.
  breaks <- pretty(range(mtcars$mpg), n = grDevices::nclass.Sturges(mtcars$mpg), min.n = 1)
  expected <- as.vector(table(cut(mtcars$mpg, breaks, right = TRUE, include.lowest = TRUE)))
  counts <- vapply(bins, `[[`, numeric(1), "count")
  expect_equal(round(sum(counts)), nrow(mtcars))
  expect_equal(round(counts), expected[expected > 0])
  edges <- vapply(bins, `[[`, numeric(1), "x0")
  expect_equal(edges, utils::head(breaks, -1)[expected > 0], tolerance = 0.01)
})

test_that("polygon vertices are drawn where the data puts them", {
  skip_if_no_browser()
  s <- open_page(save_page(glyph(shapes, x = x, y = y) |> mark_polygon(group = id)))
  js(s, AXIS_JS)
  drawn <- js(s, "(() => { const x = axisMap('x'), y = axisMap('y');
    return [...document.querySelectorAll('.glyph-polygon')].map(p =>
      p.getAttribute('d').replace(/[MZ]/g, '').split('L').map(pt => { const [a, b] = pt.split(',').map(Number); return [x(a), y(b)]; })); })()")
  expect_length(drawn, 3)
  for (poly in drawn) {
    pts <- do.call(rbind, lapply(poly, unlist))
    want <- shapes[shapes$id == c("tri", "square", "notch")[match(nrow(pts), c(3, 4, 6))], c("x", "y")]
    expect_equal(unname(pts), unname(as.matrix(want)), tolerance = 0.01)
  }
})

test_that("a widget keeps one tooltip through repeated resizes (#23)", {
  skip_if_no_browser()
  s <- open_page(save_page(
    glyph(mtcars, x = wt, y = mpg) |> mark_point() |> interact(tooltip = TRUE, brush = TRUE, zoom = TRUE)
  ))
  sizes <- list(c(900, 650), c(600, 500), c(1100, 700), c(450, 600), c(800, 400),
                c(1000, 750), c(700, 700), c(520, 380), c(1200, 600), c(800, 600))
  for (wh in sizes) {
    s$Emulation$setDeviceMetricsOverride(width = wh[1], height = wh[2], deviceScaleFactor = 1, mobile = FALSE)
    Sys.sleep(0.3)
  }
  expect_equal(js(s, "document.querySelectorAll('.glyph-tooltip').length"), 1)
  # It still works: hovering a point shows its values.
  xy <- centre_of(s, ".marks-point circle")
  mouse(s, "mouseMoved", xy[1], xy[2])
  wait_until(s, "[...document.querySelectorAll('.glyph-tooltip')].some(t => t.style.opacity === '1')")
  expect_match(js(s, "document.querySelector('.glyph-tooltip').textContent"), "wt: ")
  expect_length(page_errors(s), 0)
})

test_that("knitted documents embed working widgets", {
  skip_if_no_browser()
  skip_if_not(rmarkdown::pandoc_available(), "pandoc is not available")
  dir <- withr::local_tempdir()
  rmd <- file.path(dir, "doc.Rmd")
  writeLines(c(
    "---", "title: Widgets", "output: html_document", "---", "",
    "```{r}", "library(glyph)", "glyph(mtcars, x = wt, y = mpg) |> mark_point()", "```", "",
    "Some text between the plots.", "",
    "```{r}", "glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot()", "```"
  ), rmd)
  html <- rmarkdown::render(rmd, quiet = TRUE, envir = new.env())
  s <- open_page(html, width = 1000, height = 900)
  widgets <- js(s, "[...document.querySelectorAll('.html-widget')].map(w => {
    const svg = w.querySelector('svg');
    return { marks: w.querySelectorAll('.marks-point circle, .glyph-box').length,
             spill: svg.getBoundingClientRect().bottom - w.getBoundingClientRect().bottom };
  })")
  expect_length(widgets, 2)
  expect_equal(widgets[[1]]$marks, 32)
  expect_equal(widgets[[2]]$marks, 3)
  # Plots stay inside their box instead of running into the text (#18).
  expect_true(all(vapply(widgets, `[[`, numeric(1), "spill") <= 1))
  expect_length(page_errors(s), 0)
})

test_that("Clear selection shows only during a selection and clears it (#26)", {
  skip_if_no_browser()
  s <- open_page(save_page(
    compose(glyph(mtcars, x = wt, y = mpg) |> mark_point() |> interact(brush = TRUE, zoom = TRUE),
            glyph(mtcars, x = factor(cyl), y = mpg) |> mark_boxplot(),
            linked_selections = TRUE)
  ), width = 1000, height = 500)
  opacities <- function() js(s, "[...document.querySelectorAll('g.glyph-plot [opacity]')].map(e => e.getAttribute('opacity')).join()")
  shown <- function() js(s, "[...document.querySelectorAll('.glyph-clear-selection')].filter(b => b.style.display !== 'none').length")
  overlay <- unlist(js(s, "(() => { const b = document.querySelector('.brush .overlay').getBoundingClientRect(); return [b.left, b.top, b.width, b.height]; })()"))
  at <- function(f) overlay[1:2] + overlay[3:4] * f
  before <- opacities()
  expect_equal(shown(), 0)

  drag(s, at(0.15), at(0.6))
  wait_until(s, "!!d3.brushSelection(document.querySelector('.brush'))")
  expect_equal(shown(), 1)
  expect_false(identical(opacities(), before))
  btn <- centre_of(s, ".glyph-clear-selection")
  click_at(s, btn[1], btn[2])
  wait_until(s, "!d3.brushSelection(document.querySelector('.brush'))")
  # Every mark is back, in the linked boxplot panel too.
  expect_identical(opacities(), before)
  expect_equal(shown(), 0)

  # Escape clears it as well.
  drag(s, at(0.15), at(0.6))
  wait_until(s, "!!d3.brushSelection(document.querySelector('.brush'))")
  s$Input$dispatchKeyEvent(type = "keyDown", key = "Escape", code = "Escape", windowsVirtualKeyCode = 27)
  wait_until(s, "!d3.brushSelection(document.querySelector('.brush'))")
  expect_identical(opacities(), before)
  expect_equal(shown(), 0)
  expect_length(page_errors(s), 0)
})

test_that("Reset zoom returns the plot to its original view", {
  skip_if_no_browser()
  s <- open_page(save_page(
    glyph(mtcars, x = wt, y = mpg) |> mark_point() |> interact(tooltip = TRUE, brush = TRUE, zoom = TRUE)
  ))
  view <- function() unlist(js(s, "(() => { const m = document.querySelector('g.glyph-plot').transform.baseVal.consolidate().matrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f]; })()"))
  original <- view()
  centre <- centre_of(s, ".brush .overlay")
  mouse(s, "mouseWheel", centre[1], centre[2], deltaX = 0, deltaY = -400)
  wait_until(s, sprintf("document.querySelector('g.glyph-plot').transform.baseVal.consolidate().matrix.a > %f", original[1] * 1.1))
  btn <- centre_of(s, ".glyph-zoom-reset")
  click_at(s, btn[1], btn[2])
  # The reset is animated on a small plot like this one.
  wait_until(s, sprintf("Math.abs(document.querySelector('g.glyph-plot').transform.baseVal.consolidate().matrix.a - %f) < 1e-9", original[1]))
  Sys.sleep(0.4)
  expect_equal(view(), original, tolerance = 1e-9)
  expect_length(page_errors(s), 0)
})
