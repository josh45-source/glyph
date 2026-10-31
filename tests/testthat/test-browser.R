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

test_that("dates and date-times are spread along their axis, in any time zone (#39)", {
  skip_if_no_browser()
  # Monthly dates, as in ggplot2::economics, which drew every point at x = 0.
  econ <- data.frame(
    date = seq(as.Date("1967-07-01"), by = "month", length.out = 24),
    unemploy = seq(2900, by = 50, length.out = 24)
  )
  days <- data.frame(date = as.Date("2024-01-01") + 0:9, v = 1:10)
  # Hours across the start of daylight saving time in New York.
  times <- data.frame(t = as.POSIXct("2024-03-10 00:00", tz = "America/New_York") + 3600 * 0:5, v = 1:6)
  # A browser eight hours behind UTC, where a date read as local time would
  # show the day before.
  s <- open_page(save_widgets(list(
    point = render(glyph(econ, x = date, y = unemploy) |> mark_point() |> interact(tooltip = TRUE)),
    line = render(glyph(econ, x = date, y = unemploy) |> mark_line()),
    days = render(glyph(days, x = date, y = v) |> mark_point()),
    time = render(glyph(times, x = t, y = v) |> mark_point() |> interact(tooltip = TRUE)),
    ydate = render(glyph(econ, x = unemploy, y = date) |> mark_point())
  )), width = 800, height = 2300, timezone = "America/Los_Angeles")
  positions <- function(id, attr) {
    unlist(js(s, sprintf("[...document.querySelectorAll('#%s circle')].map(c => +c.getAttribute('%s'))", id, attr)))
  }

  # Each date at its own place, in date order.
  x <- positions("point", "cx")
  expect_length(unique(x), nrow(econ))
  expect_true(all(diff(x) > 0))
  expect_true(all(diff(positions("time", "cx")) > 0))
  expect_true(all(diff(positions("ydate", "cy")) < 0))
  expect_false(js(s, "document.querySelector('#line path.marks-line').getAttribute('d').includes('NaN')"))

  # Daily ticks fall on UTC midnights, each where the point for that day is
  # (d3 draws ticks half a pixel over, for a crisp line). At this scale eight
  # hours is about 17 pixels.
  ticks <- js(s, "(() => {
    const points = [...document.querySelectorAll('#days circle')];
    return [...document.querySelectorAll('#days .axis-x .tick')].map(t => {
      const p = points.find(c => +c.__data__.date === +t.__data__);
      return { midnight: t.__data__.getUTCHours() === 0,
               gap: p ? Math.abs(+t.getAttribute('transform').match(/translate\\(([-\\d.e]+)/)[1] - +p.getAttribute('cx')) : null };
    }); })()")
  expect_gt(length(ticks), 3)
  for (t in ticks) {
    expect_true(t$midnight)
    expect_lt(t$gap, 1)
  }

  # Tooltips read as R prints the values: not a day early, not in the
  # browser's time zone.
  tooltip <- function(id, i) {
    js(s, sprintf("document.querySelectorAll('#%s circle')[%d].dispatchEvent(new MouseEvent('mouseover', { bubbles: true })); true", id, i - 1))
    wait_until(s, "[...document.querySelectorAll('.glyph-tooltip')].some(t => t.style.opacity === '1')")
    text <- js(s, "[...document.querySelectorAll('.glyph-tooltip')].find(t => t.style.opacity === '1').textContent")
    js(s, sprintf("document.querySelectorAll('#%s circle')[%d].dispatchEvent(new MouseEvent('mouseout', { bubbles: true })); true", id, i - 1))
    wait_until(s, "![...document.querySelectorAll('.glyph-tooltip')].some(t => t.style.opacity === '1')")
    text
  }
  expect_match(tooltip("point", 1), "date: 1967-07-01")
  expect_match(tooltip("time", 4), "t: 2024-03-10 04:00")
  expect_length(page_errors(s), 0)
})

test_that("lines and areas show the tooltip of the point under the pointer (#42)", {
  skip_if_no_browser()
  econ <- data.frame(date = seq(as.Date("1967-07-01"), by = "month", length.out = 12),
                     unemploy = c(2944, 2945, 2958, 3143, 3066, 3018, 2878, 3001, 2877, 2709, 2740, 2938))
  # Rows out of order along x.
  unsorted <- data.frame(x = c(5, 1, 4, 2, 3), y = c(50, 10, 40, 20, 30))
  # Two lines that cross, with the same x values.
  two <- data.frame(x = rep(1:10, 2), y = c(1:10, 10:1), g = rep(c("a", "b"), each = 10))
  s <- open_page(save_widgets(list(
    auto = render(glyph(econ, x = date, y = unemploy) |> mark_line() |> interact(tooltip = TRUE)),
    template = render(glyph(econ, x = date, y = unemploy) |> mark_line() |> interact(tooltip = "{date}: {unemploy}")),
    unsorted = render(glyph(unsorted, x = x, y = y) |> mark_line() |> interact(tooltip = TRUE)),
    two = render(glyph(two, x = x, y = y) |> mark_line(color = g) |> interact(tooltip = TRUE)),
    area = render(glyph(unsorted, x = x, y = y) |> mark_area() |> interact(tooltip = TRUE)),
    brushed = render(glyph(econ, x = date, y = unemploy) |> mark_line() |> mark_point(data = econ[1:2, ]) |>
                       interact(tooltip = TRUE, brush = TRUE))
  )), height = 2600)

  # The page position of the drawn vertex for row `i` of the `k`th line or
  # area in div `id`, moved by (dx, dy). Each path segment ends at a vertex.
  vertex <- function(id, i, k = 1, dx = 0, dy = 0) {
    unlist(js(s, sprintf(
      "(() => { const p = document.querySelectorAll('#%s .marks-line, #%s .marks-area')[%d];
                const v = p.getAttribute('d').split(/[A-Za-z]/).filter(x => x).map(seg => seg.split(',').slice(-2).map(Number))[%d];
                const m = p.getScreenCTM();
                return [m.a * v[0] + m.c * v[1] + m.e + %f, m.b * v[0] + m.d * v[1] + m.f + %f]; })()",
      id, id, k - 1, i - 1, dx, dy)))
  }
  visible <- "[...document.querySelectorAll('.glyph-tooltip')].find(t => t.style.opacity === '1')"
  hover <- function(xy) {
    mouse(s, "mouseMoved", xy[1], xy[2])
    wait_until(s, sprintf("!!%s", visible))
    text <- js(s, sprintf("%s.textContent", visible))
    mouse(s, "mouseMoved", 795, 2595)
    wait_until(s, sprintf("!%s", visible))
    text
  }

  # Near a point, not on it.
  expect_match(hover(vertex("auto", 4, dx = 4)), "date: 1967-10-01unemploy: 3143", fixed = TRUE)
  expect_match(hover(vertex("template", 9, dx = -4)), "^1968-03-01: 2877$")
  # Row 3 is x = 4, between rows 5 and 4 along the line.
  expect_match(hover(vertex("unsorted", 3, dx = 3)), "x: 4y: 40", fixed = TRUE)
  # At x = 3 line a is at 3 and line b at 8: the pointer is just below b's
  # point, so b's point, not the first row at x = 3.
  expect_match(hover(vertex("two", 3, k = 2, dy = 5)), "x: 3y: 8g: b", fixed = TRUE)
  expect_match(hover(vertex("two", 3, k = 1, dy = -5)), "x: 3y: 3g: a", fixed = TRUE)
  expect_match(hover(vertex("area", 1, dx = -3)), "x: 5y: 50", fixed = TRUE)
  # A brush covers the line; away from the points, the line still answers.
  expect_match(hover(vertex("brushed", 7, dy = 6)), "date: 1968-01-01unemploy: 2878", fixed = TRUE)
  # The dot sits on the point, in the line's colour.
  mouse(s, "mouseMoved", vertex("two", 6, k = 2)[1], vertex("two", 6, k = 2)[2])
  wait_until(s, sprintf("!!%s", visible))
  dot <- js(s, "(() => { const d = document.querySelectorAll('#two .glyph-line-dot')[0], b = d.getBoundingClientRect();
                         return [b.left + b.width / 2, b.top + b.height / 2, d.getAttribute('fill'),
                                 document.querySelectorAll('#two .marks-line')[1].getAttribute('stroke')]; })()")
  expect_equal(unlist(dot[1:2]), vertex("two", 6, k = 2), tolerance = 1)
  expect_identical(dot[[3]], dot[[4]])

  # One tooltip per widget, as for other marks.
  expect_equal(js(s, "document.querySelectorAll('.glyph-tooltip').length"), 6)
  expect_length(page_errors(s), 0)
})

test_that("tooltips show above dashboard cards, next to the pointer (#43)", {
  skip_if_no_browser()
  # Laid out as a Quarto dashboard: a body that doesn't scroll, and a card
  # whose body is its own layer (z-index 4), with overflow. The tooltip used
  # to be drawn under it.
  dir <- withr::local_tempdir()
  file <- file.path(dir, "page.html")
  # A tooltip big enough to reach the window's edge from the last point.
  df <- data.frame(x = 1:20, y = c(20:2, 0), note = "a note long enough to make the tooltip wide")
  widget <- render(glyph(df, x = x, y = y) |> mark_point() |>
                     interact(tooltip = "x: {x}\ny: {y}\n{note}\n{note}\n{note}\n{note}"))
  htmltools::save_html(htmltools::tagList(
    htmltools::tags$style(
      "html, body { margin: 0; height: 100%; overflow: hidden; }
       body { display: flex; }
       .card { flex: 1; display: flex; position: relative; overflow: auto; margin: 16px; }
       .card-body { flex: 1; display: flex; z-index: 4; overflow: hidden; }
       .card-body > * { flex: 1; }
       .card.full-screen { position: fixed; inset: 40px 16px 16px; z-index: 1070; }"),
    htmltools::div(class = "card", htmltools::div(class = "card-body", widget))
  ), file, libdir = "lib")
  s <- open_page(file, width = 700, height = 450)

  # Hovers the point with the given x, and returns where the tooltip is
  # relative to the pointer, whether it is in the window, and whether it is
  # what is drawn at its centre.
  hover <- function(x) {
    xy <- unlist(js(s, sprintf(
      "(() => { const b = [...document.querySelectorAll('.marks-point circle')].find(e => e.__data__.x === %d)
                  .getBoundingClientRect(); return [b.left + b.width / 2, b.top + b.height / 2]; })()", x)))
    mouse(s, "mouseMoved", xy[1], xy[2])
    wait_until(s, "[...document.querySelectorAll('.glyph-tooltip')].some(t => t.style.opacity === '1')")
    r <- js(s, "(() => { const t = [...document.querySelectorAll('.glyph-tooltip')].find(t => t.style.opacity === '1');
                         t.style.pointerEvents = 'auto';
                         const b = t.getBoundingClientRect();
                         const onTop = t.contains(document.elementFromPoint(b.left + b.width / 2, b.top + b.height / 2));
                         t.style.pointerEvents = 'none';
                         return { box: [b.left, b.top, b.right, b.bottom], onTop, text: t.textContent,
                                  window: [document.documentElement.clientWidth, document.documentElement.clientHeight] }; })()")
    mouse(s, "mouseMoved", 1, 1)
    wait_until(s, "![...document.querySelectorAll('.glyph-tooltip')].some(t => t.style.opacity === '1')")
    box <- unlist(r$box)
    list(text = r$text, on_top = r$onTop, from_pointer = box[1:2] - xy, right_of_pointer = box[1] > xy[1],
         in_window = all(box >= 0) && box[3] <= r$window[[1]] && box[4] <= r$window[[2]])
  }

  # Mid-plot: on top, 12px right of and above the pointer, as in a page.
  mid <- hover(10)
  expect_match(mid$text, "x: 10y: 11", fixed = TRUE)
  expect_true(mid$on_top)
  expect_equal(mid$from_pointer, c(12, -12), tolerance = 1.5)
  # In the bottom right corner it moves left of and above the pointer
  # rather than leave the window.
  corner <- hover(20)
  expect_true(corner$on_top)
  expect_true(corner$in_window)
  expect_false(corner$right_of_pointer)
  expect_lt(corner$from_pointer[2], -12)

  # A card in full-screen mode, as bslib does it (z-index 1070).
  js(s, "document.querySelector('.card').classList.add('full-screen')")
  wait_until(s, "Math.abs(document.querySelector('.html-widget svg').getBoundingClientRect().top - 40) < 30")
  Sys.sleep(0.5)
  full <- hover(10)
  expect_true(full$on_top)
  expect_equal(full$from_pointer, c(12, -12), tolerance = 1.5)
  expect_length(page_errors(s), 0)
})

test_that("facet strips sit on top and on the right, with outer axes only (#46)", {
  skip_if_no_browser()
  p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
  s <- open_page(save_widgets(list(
    grid = render(p |> facet(rows = cyl, cols = gear)),
    labelled = render(p |> facet(rows = cyl, cols = gear, labeller = list(
      cyl = c("4" = "Four cylinders"), gear = function(x) paste(x, "gears")))),
    wrapped = render(p |> facet(cols = carb, wrap = 4)),
    dark = render(p |> facet(cols = am) |> theme_tokens(preset = "dark", strip_size = 14, strip_weight = 400))
  )), width = 700, height = 1800)

  # Strip text and boxes, and each panel's plot area (its axis lines), in
  # page coordinates, for the plot in div `id`.
  layout <- function(id) js(s, sprintf("(() => {
    const box = e => { const b = e.getBoundingClientRect(); return [b.left, b.top, b.right, b.bottom]; };
    const root = document.querySelector('#%s');
    const strips = cls => [...root.querySelectorAll('.glyph-strip-' + cls)].map(e => ({ text: e.textContent, box: box(e),
      vertical: getComputedStyle(e).writingMode.startsWith('vertical') }));
    const panels = [...root.querySelectorAll('.glyph-facet-panel')].map(p => {
      const x = p.querySelector('.axis-x .domain').getBoundingClientRect(), y = p.querySelector('.axis-y .domain').getBoundingClientRect();
      return { plot: [x.left, y.top, x.right, y.bottom],
               xLabels: [...p.querySelectorAll('.axis-x .tick text')].some(t => t.textContent !== ''),
               yLabels: [...p.querySelectorAll('.axis-y .tick text')].some(t => t.textContent !== '') };
    });
    const w = root.querySelector('.html-widget');
    return { top: strips('top'), right: strips('right'), panels, widget: box(w),
             overflow: [w.scrollWidth - w.clientWidth, w.scrollHeight - w.clientHeight],
             titles: [...root.querySelectorAll('.glyph-facet-axis-title')].map(e => e.textContent) };
  })()", id))
  num <- function(l, k) vapply(l, function(e) e[[k]], numeric(1))
  boxes <- function(l) do.call(rbind, lapply(l, function(e) unlist(e$box)))
  plots <- function(l) do.call(rbind, lapply(l, function(e) unlist(e$plot)))

  g <- layout("grid")
  # Gear across the top, cyl down the right, rotated; the value alone.
  expect_identical(vapply(g$top, `[[`, "", "text"), c("3", "4", "5"))
  expect_identical(vapply(g$right, `[[`, "", "text"), c("4", "6", "8"))
  expect_false(any(vapply(g$top, `[[`, TRUE, "vertical")))
  expect_true(all(vapply(g$right, `[[`, TRUE, "vertical")))
  # Nine panels of the same size, in rows of three.
  pl <- plots(g$panels)
  expect_equal(nrow(pl), 9)
  expect_lt(diff(range(pl[, 3] - pl[, 1])), 1)
  expect_lt(diff(range(pl[, 4] - pl[, 2])), 1)
  # Column strips span their column's plot area just above the top row;
  # row strips span their row's plot area just right of the last column.
  top <- boxes(g$top); right <- boxes(g$right)
  expect_equal(top[, 1], pl[1:3, 1], tolerance = 1)
  expect_equal(top[, 3], pl[1:3, 3], tolerance = 1)
  expect_true(all(top[, 4] <= pl[1:3, 2] & pl[1:3, 2] - top[, 4] < 10))
  expect_equal(right[, 2], pl[c(3, 6, 9), 2], tolerance = 1)
  expect_equal(right[, 4], pl[c(3, 6, 9), 4], tolerance = 1)
  expect_true(all(right[, 1] >= pl[c(3, 6, 9), 3] & right[, 1] - pl[c(3, 6, 9), 3] < 10))
  # Panels sit close together: under 30px between plot areas (about 100px
  # before #46).
  expect_lt(pl[2, 1] - pl[1, 3], 30)
  expect_lt(pl[4, 2] - pl[1, 4], 30)
  # Tick labels on the left column and the bottom row only, and the axis
  # titles once.
  expect_identical(vapply(g$panels, `[[`, TRUE, "yLabels"), rep(c(TRUE, FALSE, FALSE), 3))
  expect_identical(vapply(g$panels, `[[`, TRUE, "xLabels"), rep(c(FALSE, TRUE), c(6, 3)))
  expect_setequal(unlist(g$titles), c("wt", "mpg"))
  # It all fits the widget.
  expect_identical(unlist(g$overflow), c(0L, 0L))
  expect_true(all(right[, 3] <= g$widget[[3]]))

  # A labeller: a lookup for cyl (6 and 8 keep their values), a function
  # for gear.
  l <- layout("labelled")
  expect_identical(vapply(l$top, `[[`, "", "text"), c("3 gears", "4 gears", "5 gears"))
  expect_identical(vapply(l$right, `[[`, "", "text"), c("Four cylinders", "6", "8"))

  # cols alone, wrapped: a strip on top of each panel, x labels on the
  # lowest panel of each column (here, 3 and 4 have no panel below them).
  w <- layout("wrapped")
  expect_identical(vapply(w$top, `[[`, "", "text"), c("1", "2", "3", "4", "6", "8"))
  expect_length(w$right, 0)
  expect_identical(vapply(w$panels, `[[`, TRUE, "xLabels"), c(FALSE, FALSE, TRUE, TRUE, TRUE, TRUE))
  expect_identical(vapply(w$panels, `[[`, TRUE, "yLabels"), c(TRUE, FALSE, FALSE, FALSE, TRUE, FALSE))
  wp <- plots(w$panels); wt <- boxes(w$top)
  expect_true(all(wt[, 4] <= wp[, 2] & wp[, 2] - wt[, 4] < 10))

  # Strip tokens: the dark preset's colours, with the size and weight set.
  style <- js(s, "(() => { const c = getComputedStyle(document.querySelector('#dark .glyph-strip'));
                           return [c.fontSize, c.fontWeight, c.color, c.backgroundColor]; })()")
  expect_identical(unlist(style), c("14px", "400", "rgb(224, 224, 224)", "rgb(42, 42, 74)"))
  expect_length(page_errors(s), 0)
})
