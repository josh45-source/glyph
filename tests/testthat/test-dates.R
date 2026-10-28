# Dates and date-times go to the browser as milliseconds, named in
# `temporal`, and the renderer turns them back into dates (#39). They used to
# go as strings, which marks placed at x = NaN. See temporal_ms() and
# df_to_columns() in R/render.R, and inflateSpec() in glyph.js.

# Monthly dates, as in ggplot2::economics.
econ <- data.frame(
  date = seq(as.Date("1967-07-01"), by = "month", length.out = 24),
  unemploy = seq(2900, by = 50, length.out = 24)
)

# Milliseconds back to the clock time they stand for.
as_clock <- function(ms) format(as.POSIXct(ms / 1000, origin = "1970-01-01", tz = "UTC"), "%Y-%m-%d %H:%M:%S")

test_that("a Date is midnight UTC of its day, and a missing one stays missing", {
  d <- as.Date(c("1967-07-01", "1970-01-01", NA, "2024-02-29"))
  expect_identical(temporal_ms(d), c(-79056000000, 0, NA, 1709164800000))
})

test_that("a date-time keeps the clock time of its own time zone", {
  utc <- as.POSIXct("2024-01-01 12:00:00", tz = "UTC")
  expect_identical(temporal_ms(utc), as.numeric(utc) * 1000)
  # Either side of both daylight saving changes in New York.
  ny <- as.POSIXct(c("2024-03-10 01:30", "2024-03-10 03:30", "2024-11-03 00:30", "2024-11-03 02:30"),
                   tz = "America/New_York")
  expect_identical(as_clock(temporal_ms(ny)), format(ny, "%Y-%m-%d %H:%M:%S"))
  # With no time zone, as the session prints it.
  local <- as.POSIXct("2024-06-01 08:15:00")
  attr(local, "tzone") <- NULL
  expect_identical(as_clock(temporal_ms(local)), format(local, "%Y-%m-%d %H:%M:%S"))
  expect_identical(temporal_ms(as.POSIXct(NA, tz = "UTC")), NA_real_)
})

test_that("the plot's data sends dates as numbers and names them", {
  spec <- compile(glyph(econ, x = date, y = unemploy) |> mark_point())$spec
  expect_identical(as.character(spec$data$temporal), "date")
  expect_identical(spec$data$columns$date, temporal_ms(econ$date))
  expect_identical(spec$data$columns$unemploy, econ$unemploy)
  expect_identical(spec$marks[[1]]$encoding$x$type, "temporal")
  # The JSON has the exact numbers, not rounded or in exponent form.
  expect_match(as.character(compile(glyph(econ, x = date, y = unemploy) |> mark_point())$json),
               '"date":[-79056000000,-76377600000', fixed = TRUE)
})

test_that("computed date mappings and a mark's own data send dates too", {
  spec <- compile(glyph(econ, x = date + 14, y = unemploy) |> mark_line())$spec
  field <- spec$marks[[1]]$encoding$x$field
  expect_true(field %in% spec$data$temporal)
  expect_identical(spec$data$columns[[field]], temporal_ms(econ$date + 14))

  times <- data.frame(t = as.POSIXct("2024-01-01", tz = "UTC") + 3600 * 0:2, v = 1:3)
  mark <- compile(glyph(econ, x = date, y = unemploy) |> mark_point(data = times, x = t, y = v))$spec$marks[[1]]
  expect_identical(as.character(mark$data$temporal), "t")
  expect_identical(mark$data$columns$t, temporal_ms(times$t))
})

test_that("statistical marks grouped by date send their groups as numbers", {
  df <- data.frame(d = rep(as.Date(c("2020-01-01", "2021-01-01")), each = 4), v = c(1:4, 3:6))
  box <- compile(glyph(df, x = d, y = v) |> mark_boxplot())$spec$marks[[1]]
  expect_identical(as.character(box$data$temporal), "d")
  expect_identical(vapply(box$data$values, function(r) r$d, numeric(1)), temporal_ms(unique(df$d)))
  expect_equal(as.numeric(box$encoding$x$domain), temporal_ms(unique(df$d)))

  sina <- compile(glyph(df, x = d, y = v) |> mark_sina())$spec$marks[[1]]
  expect_identical(as.character(sina$data$temporal), "d")
  expect_equal(as.numeric(sina$encoding$x$domain), temporal_ms(unique(df$d)))
})

test_that("a scale domain of dates is sent as numbers", {
  dom <- as.Date(c("2000-01-01", "2010-01-01"))
  spec <- compile(glyph(econ, x = date, y = unemploy) |> mark_line() |> set_scale("x", domain = dom))$spec
  expect_identical(spec$scales$x$domain, temporal_ms(dom))
})

test_that("to_vegalite() still writes dates as dates", {
  vl <- jsonlite::fromJSON(to_vegalite(glyph(econ, x = date, y = unemploy) |> mark_line()),
                           simplifyVector = FALSE)
  expect_identical(vl$data$values[[1]]$date, "1967-07-01")
  expect_identical(vl$encoding$x$type, "temporal")
})
