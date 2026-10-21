# Runs a real Shiny app in a background R process, brushes and clicks its
# plots in headless Chrome, and checks the row numbers the server received
# in input$<id>_selected. The server saves every value it receives to a
# file, and the test reads them.

# Fails rather than skips where the browser tests are required to run (see
# skip_if_no_browser()).
skip_if_no_shiny <- function() {
  for (pkg in c("shiny", "callr")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      if (identical(Sys.getenv("GLYPH_REQUIRE_BROWSER"), "true")) stop(pkg, " is not installed")
      skip(paste(pkg, "is not installed"))
    }
  }
}

# Where the app finds the glyph being tested: the source tree under
# devtools::test(), or the installed package under R CMD check, where the
# tests run without the source.
glyph_location <- function() {
  source <- normalizePath(test_path("..", ".."))
  if (file.exists(file.path(source, "R", "shiny.R"))) {
    list(source = source)
  } else {
    list(lib = dirname(find.package("glyph")))
  }
}

# The app. It runs in another process, so it takes everything it needs as
# arguments.
run_app <- function(glyph, port, log_dir) {
  if (!is.null(glyph$source)) {
    pkgload::load_all(glyph$source, quiet = TRUE)
  } else {
    library(glyph, lib.loc = glyph$lib)
  }
  gaps <- data.frame(
    a = c(1.3, NA, 2.5, 3.1, 4.7, 2.2, 3.8),
    b = c(2.1, 3.3, NA, 4.4, 1.6, 3.0, 2.6)
  )
  # Each value goes to a new file in `log_dir`, written under another name and
  # then renamed, so the test never reads a file that is being written, and
  # no file is replaced while the test may have it open.
  n <- 0
  record <- function(name, value) {
    n <<- n + 1
    file <- file.path(log_dir, sprintf("%04d", n))
    saveRDS(list(input = name, value = value), paste0(file, ".tmp"))
    file.rename(paste0(file, ".tmp"), paste0(file, ".rds"))
  }
  # A plot in a module gets its selection in the module's own input.
  module_server <- function(id) {
    shiny::moduleServer(id, function(input, output, session) {
      output$plot <- renderGlyph(glyph(mtcars, x = wt, y = mpg) |> mark_point() |> interact(brush = TRUE))
      shiny::observeEvent(input$plot_selected, ignoreNULL = FALSE, ignoreInit = TRUE, {
        record(paste0(id, ":plot_selected"), input$plot_selected)
      })
    })
  }
  ui <- shiny::fluidPage(
    glyphOutput("scatter", width = "600px", height = "400px"),
    glyphOutput("layout", width = "900px", height = "400px"),
    glyphOutput(shiny::NS("module", "plot"), width = "600px", height = "300px")
  )
  server <- function(input, output, session) {
    module_server("module")
    output$scatter <- renderGlyph(
      glyph(gaps, x = a, y = b) |> mark_point() |> interact(brush = TRUE)
    )
    output$layout <- renderGlyph({
      if (isTRUE(input$hide)) return(NULL)
      compose(
        cars = glyph(mtcars, x = wt, y = mpg) |> mark_point() |> interact(brush = TRUE),
        gaps = glyph(gaps, x = a, y = log(b)) |> mark_point() |> interact(brush = TRUE)
      )
    })
    for (id in c("scatter", "layout")) local({
      name <- paste0(id, "_selected")
      shiny::observeEvent(input[[name]], ignoreNULL = FALSE, ignoreInit = TRUE, {
        record(name, input[[name]])
      })
    })
  }
  suppressWarnings(shiny::runApp(shiny::shinyApp(ui, server), port = port, launch.browser = FALSE))
}

# The values the server has received so far, in order.
all_received <- function(log_dir) sort(list.files(log_dir, "[.]rds$", full.names = TRUE))

# Waits for the next value the server receives, and returns it as
# list(input = <input name>, value = <its value>).
next_received <- function(log_dir, seen, timeout = 10) {
  end <- Sys.time() + timeout
  repeat {
    files <- all_received(log_dir)
    if (length(files) > seen) return(readRDS(files[[seen + 1]]))
    if (Sys.time() > end) stop("The server received no new value after ", seen)
    Sys.sleep(0.05)
  }
}

test_that("a Shiny server receives the selected rows", {
  skip_if_no_browser()
  skip_if_no_shiny()
  log_dir <- withr::local_tempdir()
  port <- httpuv::randomPort()
  app <- callr::r_bg(run_app, list(glyph_location(), port, log_dir))
  withr::defer(app$kill())
  url <- sprintf("http://127.0.0.1:%d", port)
  end <- Sys.time() + 60
  started <- function() {
    tryCatch(suppressWarnings(length(readLines(url, warn = FALSE)) > 0), error = function(e) FALSE)
  }
  while (!started()) {
    if (!app$is_alive()) stop("The app stopped:\n", app$read_all_error())
    if (Sys.time() > end) stop("The app did not start")
    Sys.sleep(0.2)
  }

  s <- open_page(url, width = 1000, height = 1300)
  gaps <- data.frame(a = c(1.3, NA, 2.5, 3.1, 4.7, 2.2, 3.8), b = c(2.1, 3.3, NA, 4.4, 1.6, 3.0, 2.6))
  kept <- which(!is.na(gaps$a) & !is.na(gaps$b))

  seen <- 0
  received <- function() {
    value <- next_received(log_dir, seen)
    seen <<- seen + 1
    value
  }

  # Rows 2 and 3 have missing values and are not drawn, but row numbers
  # still count them.
  brush_over(s, "scatter")
  expect_identical(received(), list(input = "scatter_selected", value = kept))
  # brush_over() starts by clicking the plot's Clear selection button.
  brush_over(s, "scatter", to = c(0.5, 1))
  expect_identical(received(), list(input = "scatter_selected", value = NULL))
  expect_identical(received(), list(input = "scatter_selected", value = intersect(kept, which(gaps$a < 3))))
  # Escape clears it too.
  s$Input$dispatchKeyEvent(type = "keyDown", key = "Escape", code = "Escape", windowsVirtualKeyCode = 27)
  expect_identical(received(), list(input = "scatter_selected", value = NULL))

  # In a layout, one entry per panel, named as in compose(). The second
  # panel maps log(b), and drops rows 2 and 3.
  brush_over(s, "layout", n = 1)
  expect_identical(received(), list(input = "layout_selected", value = list(cars = seq_len(nrow(mtcars)), gaps = NULL)))
  brush_over(s, "layout", n = 2)
  expect_identical(received(), list(input = "layout_selected", value = list(cars = seq_len(nrow(mtcars)), gaps = kept)))

  # A plot replaced by NULL takes its selection with it. (Set from the page,
  # as a click on a button would also clear the brushes, being a click
  # outside them.)
  js(s, "Shiny.setInputValue('hide', true); true")
  expect_identical(received(), list(input = "layout_selected", value = NULL))

  brush_over(s, "module-plot")
  expect_identical(received(), list(input = "module:plot_selected", value = seq_len(nrow(mtcars))))

  # Nothing else was sent: one value for each change.
  Sys.sleep(0.5)
  expect_length(all_received(log_dir), seen)
  expect_length(page_errors(s), 0)
})
