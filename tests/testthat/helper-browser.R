# Browser tests: they draw plots in headless Chrome through chromote and read
# back what was drawn. They never run on CRAN, and are skipped wherever
# chromote or Chrome isn't available, so they can't affect a CRAN check.

skip_if_no_browser <- function() {
  skip_on_cran()
  # The browser-tests workflow sets this, so the tests fail there instead of
  # quietly skipping when chromote or Chrome is missing.
  required <- identical(Sys.getenv("GLYPH_REQUIRE_BROWSER"), "true")
  if (!requireNamespace("chromote", quietly = TRUE)) {
    if (required) stop("chromote is not installed")
    skip("chromote is not installed")
  }
  chrome <- tryCatch(suppressMessages(chromote::find_chrome()), error = function(e) NULL)
  if (is.null(chrome) || !nzchar(chrome)) {
    if (required) stop("Chrome is not available")
    skip("Chrome is not available")
  }
  # Keep timers and animation frames running in a tab Chrome considers
  # hidden (headless windows on Windows can count as covered), or
  # transitions never finish. Chrome refuses to start as root (as in some
  # containers) without --no-sandbox.
  args <- c("--disable-background-timer-throttling",
            "--disable-backgrounding-occluded-windows",
            "--disable-renderer-backgrounding")
  if (identical(unname(Sys.info()[["effective_user"]]), "root")) args <- c(args, "--no-sandbox")
  missing <- setdiff(args, chromote::get_chrome_args())
  if (length(missing)) chromote::set_chrome_args(c(chromote::get_chrome_args(), missing))
  # Chrome can take more than chromote's default 10 seconds to start on a
  # busy CI runner.
  if (getOption("chromote.timeout", 10) < 60) options(chromote.timeout = 60)
}

# Saves `x` (a spec, layout or widget) to a page in a temporary folder.
save_page <- function(x, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  widget <- if (inherits(x, "htmlwidget")) x else render(x)
  file <- file.path(dir, "page.html")
  htmlwidgets::saveWidget(widget, file, selfcontained = FALSE, libdir = "lib")
  file
}

# Puts several widgets on one page, each in a div with the given id.
save_widgets <- function(widgets, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  file <- file.path(dir, "page.html")
  tags <- lapply(names(widgets), function(id) {
    htmltools::div(id = id, style = "width:600px;height:400px;margin-bottom:20px;", widgets[[id]])
  })
  htmltools::save_html(htmltools::tagList(tags), file, libdir = "lib")
  file
}

# A file:// URL for a local file, on Windows ("file:///C:/...") as elsewhere.
file_url <- function(file) {
  path <- normalizePath(file, winslash = "/")
  if (!startsWith(path, "/")) path <- paste0("/", path)
  paste0("file://", utils::URLencode(path))
}

# Opens a page (a file, or the URL of a running Shiny app) in a new headless
# Chrome tab of the given size, waits until every widget on it has drawn, and
# closes the tab when the calling test ends. Script errors are collected in
# `window.__errors`. `timezone` sets the browser's time zone.
open_page <- function(file, width = 800, height = 600, env = parent.frame(), timezone = NULL) {
  s <- chromote::ChromoteSession$new(width = width, height = height)
  withr::defer(s$close(), envir = env)
  # The browser's time zone, such as "America/Los_Angeles".
  if (!is.null(timezone)) s$Emulation$setTimezoneOverride(timezoneId = timezone)
  s$Page$addScriptToEvaluateOnNewDocument(
    "window.__errors = []; addEventListener('error', e => window.__errors.push(e.message));"
  )
  loaded <- s$Page$loadEventFired(wait_ = FALSE)
  s$Page$navigate(if (grepl("^https?://", file)) file else file_url(file), wait_ = FALSE)
  s$wait_for(loaded)
  wait_until(s, "[...document.querySelectorAll('.html-widget')].every(w => w.querySelector('svg'))")
  # Let entrance animations and transitions finish.
  Sys.sleep(1)
  s
}

# Evaluates JavaScript in the page and returns its value. Promises are
# awaited, so `code` can be an async expression.
js <- function(s, code) {
  r <- s$Runtime$evaluate(code, returnByValue = TRUE, awaitPromise = TRUE)
  if (!is.null(r$exceptionDetails)) {
    stop("JavaScript error: ", r$exceptionDetails$exception$description %||% r$exceptionDetails$text)
  }
  r$result$value
}

wait_until <- function(s, condition, timeout = 10) {
  end <- Sys.time() + timeout
  while (!isTRUE(js(s, condition))) {
    if (Sys.time() > end) stop("Timed out waiting for: ", condition)
    Sys.sleep(0.05)
  }
  invisible(TRUE)
}

page_errors <- function(s) unlist(js(s, "window.__errors"))

# Real input, through Chrome's input pipeline rather than synthetic DOM events.
mouse <- function(s, type, x, y, ..., buttons = 0L) {
  s$Input$dispatchMouseEvent(type = type, x = x, y = y, buttons = as.integer(buttons), ...)
}
click_at <- function(s, x, y) {
  mouse(s, "mousePressed", x, y, button = "left", buttons = 1L, clickCount = 1L)
  mouse(s, "mouseReleased", x, y, button = "left", clickCount = 1L)
}
drag <- function(s, from, to, steps = 6) {
  mouse(s, "mouseMoved", from[1], from[2])
  mouse(s, "mousePressed", from[1], from[2], button = "left", buttons = 1L, clickCount = 1L)
  for (k in seq_len(steps)) {
    p <- from + (to - from) * k / steps
    mouse(s, "mouseMoved", p[1], p[2], button = "left", buttons = 1L)
  }
  mouse(s, "mouseReleased", to[1], to[2], button = "left", clickCount = 1L)
  # After a drag, d3 swallows the next click until a zero-delay timer runs,
  # so a click sent straight away (as a person couldn't) would be lost.
  js(s, "new Promise(r => setTimeout(r, 50))")
  invisible()
}

# The centre of the first element matching `selector`, in page coordinates.
centre_of <- function(s, selector) {
  r <- js(s, sprintf(
    "(() => { const b = document.querySelector(%s).getBoundingClientRect();
              return [b.left + b.width / 2, b.top + b.height / 2]; })()",
    jsonlite::toJSON(selector, auto_unbox = TRUE)
  ))
  unlist(r)
}

# A drag that starts inside a brush moves it, so a new brush starts by
# clearing the plot's current one with its Clear selection button.
clear_brush <- function(s, id, n = 1) {
  xy <- unlist(js(s, sprintf(
    "(() => { const brush = document.querySelectorAll('#%s .brush')[%d];
              if (!d3.brushSelection(brush)) return null;
              const b = brush.ownerSVGElement.parentNode.querySelector('.glyph-clear-selection').getBoundingClientRect();
              return [b.left + b.width / 2, b.top + b.height / 2]; })()", id, n - 1)))
  if (!is.null(xy)) click_at(s, xy[1], xy[2])
}

# Drags a brush over the `n`th brushable plot in div `id`, between fractions
# `from` and `to` of its width and height. Points can sit on the plot's
# edges, so a drag to an edge goes past it (the brush stops at the edge).
brush_over <- function(s, id, from = c(0, 0), to = c(1, 1), n = 1) {
  clear_brush(s, id, n)
  b <- unlist(js(s, sprintf(
    "(() => { const b = document.querySelectorAll('#%s .brush .overlay')[%d].getBoundingClientRect();
              return [b.left, b.top, b.width, b.height]; })()", id, n - 1)))
  at <- function(f) b[1:2] + b[3:4] * f
  drag(s, at(from), at(to) + ifelse(to >= 1, 10, 0))
}

# Drags a brush just around the elements matching `selector` in div `id`
# whose data pass `test` (JavaScript, of `d`).
brush_around <- function(s, id, selector, test) {
  clear_brush(s, id)
  box <- unlist(js(s, sprintf(
    "(() => { const bs = [...document.querySelectorAll('#%s %s')].filter(e => (d => %s)(e.__data__))
                .map(e => e.getBoundingClientRect());
              const o = document.querySelector('#%s .brush .overlay').getBoundingClientRect();
              return [Math.min(...bs.map(b => b.left)), Math.min(...bs.map(b => b.top)),
                      Math.max(...bs.map(b => b.right)), Math.max(...bs.map(b => b.bottom)),
                      o.left, o.top]; })()",
    id, selector, test, id)))
  # The drag has to start inside the plot, even for elements on its edge.
  drag(s, pmax(box[1:2] - 4, box[5:6]), box[3:4] + 4)
}

# Clicks the centre of the first element matching `selector` in div `id`
# whose data pass `test`.
click_on <- function(s, id, selector, test) {
  xy <- unlist(js(s, sprintf(
    "(() => { const e = [...document.querySelectorAll('#%s %s')].find(e => (d => %s)(e.__data__));
              const b = e.getBoundingClientRect(); return [b.left + b.width / 2, b.top + b.height / 2]; })()",
    id, selector, test)))
  click_at(s, xy[1], xy[2])
}

# Script that converts drawn positions back to data values using the axis
# ticks of the first plot on the page (or of the plot inside `root`), so the
# tests check what was drawn against values computed in R, not against
# glyph's own calculations.
AXIS_JS <- "
window.axisMap = function(axis, root) {
  const ticks = [...(root || document).querySelectorAll('.axis-' + axis + ' .tick')].map(t => {
    const m = t.getAttribute('transform').match(/translate\\(([-\\d.e]+),\\s*([-\\d.e]+)\\)/);
    const v = parseFloat(t.textContent.replace('\\u2212', '-').replace(/,/g, ''));
    return { px: +m[axis === 'x' ? 1 : 2], v };
  }).filter(t => isFinite(t.v));
  const a = ticks[0], b = ticks[ticks.length - 1];
  const slope = (b.px - a.px) / (b.v - a.v);
  return px => a.v + (px - a.px) / slope;
};
"
