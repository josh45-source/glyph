# facet(labeller =) and the strip theme tokens (#46). Labels are worked out
# at compile time and sent by value (see facet_labels() in R/render.R); the
# browser shows the value itself for anything not sent.

p <- glyph(mtcars, x = wt, y = mpg) |> mark_point()
labels_of <- function(spec) compile(spec)$spec$facets$labels

test_that("without a labeller no labels are sent", {
  expect_null(labels_of(p |> facet(rows = cyl, cols = gear)))
})

test_that("a named vector relabels the values it names, for every variable", {
  l <- labels_of(p |> facet(rows = cyl, cols = gear, labeller = c("4" = "Four", "6" = "Six")))
  # cyl has 4 and 6; gear has 4. 8, 3 and 5 keep their own labels.
  expect_setequal(as.numeric(l$rows$values), c(4, 6))
  expect_identical(as.character(l$rows$labels)[order(l$rows$values)], c("Four", "Six"))
  expect_identical(as.numeric(l$cols$values), 4)
  expect_identical(as.character(l$cols$labels), "Four")
})

test_that("a function labels every value", {
  l <- labels_of(p |> facet(cols = gear, labeller = function(x) paste(x, "gears")))
  expect_identical(as.character(l$cols$labels)[order(l$cols$values)], c("3 gears", "4 gears", "5 gears"))
  expect_null(l$rows)
})

test_that("a list gives each variable its own labeller", {
  l <- labels_of(p |> facet(rows = cyl, cols = gear, labeller = list(
    cyl = c("8" = "Eight"),
    gear = function(x) paste0("g", x)
  )))
  expect_identical(as.character(l$rows$labels), "Eight")
  expect_identical(as.numeric(l$rows$values), 8)
  expect_length(l$cols$labels, 3)
  # A variable left out of the list keeps its own labels.
  expect_null(labels_of(p |> facet(rows = cyl, cols = gear, labeller = list(cyl = c("8" = "Eight"))))$cols)
})

test_that("a computed variable is named as it is written", {
  l <- labels_of(p |> facet(cols = factor(am), labeller = list(`factor(am)` = c("0" = "automatic", "1" = "manual"))))
  expect_identical(as.character(l$cols$values), c("1", "0"))
  expect_identical(as.character(l$cols$labels), c("manual", "automatic"))
})

test_that("dates are looked up as R prints them and sent as the data sends them", {
  df <- data.frame(d = rep(as.Date(c("2020-01-01", "2021-01-01")), each = 2), x = 1:4, y = 1:4)
  l <- labels_of(glyph(df, x = x, y = y) |> mark_point() |> facet(cols = d, labeller = c("2021-01-01" = "Year two")))
  expect_identical(as.numeric(l$cols$values), temporal_ms(as.Date("2021-01-01")))
  expect_identical(as.character(l$cols$labels), "Year two")
})

test_that("one relabelled value is still sent as an array", {
  json <- as.character(compile(p |> facet(cols = gear, labeller = c("4" = "Four")))$json)
  expect_match(json, '"labels":{"cols":{"values":[4],"labels":["Four"]}}', fixed = TRUE)
})

test_that("a labeller that is the wrong shape is an error", {
  expect_error(p |> facet(cols = gear, labeller = c("Four", "Five")), "named character vector or a function")
  expect_error(p |> facet(cols = gear, labeller = 1:3), "named character vector or a function")
  expect_error(p |> facet(cols = gear, labeller = list(cyl = c("4" = "Four"))), "Not a faceting variable")
  expect_error(p |> facet(cols = gear, labeller = list(gear = 1)), "labeller for `gear`")
  expect_error(compile(p |> facet(cols = gear, labeller = function(x) "one")), "returned 1 label for 3 values")
})

test_that("every preset has strip tokens", {
  for (preset in c("light", "dark", "minimal", "publication", "presentation")) {
    theme <- (p |> theme_tokens(preset = preset))$theme
    expect_true(is.numeric(theme$strip_size), info = preset)
    expect_false(is.null(theme$strip_weight), info = preset)
    expect_match(theme$strip_fg, "^#", info = preset)
    expect_match(theme$strip_bg, "^(#|transparent$)", info = preset)
  }
  dark <- (p |> theme_tokens(preset = "dark"))$theme
  expect_identical(dark$strip_fg, dark$fg)
  expect_false(identical(dark$strip_bg, dark$bg))
})

test_that("strip tokens follow the text size and colours unless set", {
  big <- (p |> theme_tokens(font_size = 20))$theme
  expect_identical(big$strip_size, 18)
  navy <- (p |> theme_tokens(bg = "#000080"))$theme
  expect_identical(navy$strip_fg, navy$fg)
  expect_identical(navy$strip_bg, strip_shade("#000080", navy$fg))
  expect_false(identical(toupper(navy$strip_bg), "#000080"))
  set <- (p |> theme_tokens(bg = "#000080", font_size = 20, strip_size = 9, strip_bg = "red", strip_fg = "white"))$theme
  expect_identical(set[c("strip_size", "strip_bg", "strip_fg")], list(strip_size = 9, strip_bg = "red", strip_fg = "white"))
})

test_that("strip_weight takes a name or a number", {
  expect_identical((p |> theme_tokens(strip_weight = "bold"))$theme$strip_weight, "bold")
  expect_identical((p |> theme_tokens(strip_weight = 400))$theme$strip_weight, 400)
  expect_error(p |> theme_tokens(strip_weight = "heavy"), "strip_weight")
  expect_error(p |> theme_tokens(strip_weight = 1000), "strip_weight")
})
