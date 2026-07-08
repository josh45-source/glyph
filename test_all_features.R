## test_all_features.R
## Comprehensive visual test for every glyph feature
## Run via Claude Code with headless Chrome verification

library(glyph)
library(htmlwidgets)

data <- read.csv("C:/Users/Joshua/Downloads/Results.csv")
outdir <- file.path(tempdir(), "glyph_tests")
dir.create(outdir, showWarnings = FALSE)

cat("=== Saving test widgets to:", outdir, "===\n\n")

# Helper: save a widget or layout to HTML
save_test <- function(obj, name) {
  path <- file.path(outdir, paste0(name, ".html"))
  if (inherits(obj, "glyph_layout")) {
    obj <- render(obj)
  } else if (inherits(obj, "glyph_spec")) {
    obj <- render(obj)
  }
  htmlwidgets::saveWidget(obj, path, selfcontained = TRUE)
  cat("Saved:", name, "->", path, "\n")
  path
}

# ============================================================
# GROUP 1: Basic marks (previously working)
# ============================================================

cat("\n--- GROUP 1: Basic marks ---\n")

# Test 1: mark_point with color and size
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source, size = EconomicWeight),
  "01_mark_point"
)

# Test 2: mark_line
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_line(color = Source),
  "02_mark_line"
)

# Test 3: mark_bar
save_test(
  glyph(data, x = Name, y = EconomicWeight) |>
    mark_bar(color = Source),
  "03_mark_bar"
)

# Test 4: mark_area
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_area(),
  "04_mark_area"
)

# Test 5: mark_rule (reference lines)
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    mark_rule(y_intercept = mean(data$Accuracy)),
  "05_mark_rule"
)

# ============================================================
# GROUP 2: Interactivity (previously working)
# ============================================================

cat("\n--- GROUP 2: Interactivity ---\n")

# Test 6: Tooltip
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(tooltip = TRUE),
  "06_tooltip"
)

# Test 7: Hover effect
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(hover = "enlarge"),
  "07_hover"
)

# Test 8: Brush selection
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(brush = TRUE),
  "08_brush"
)

# Test 9: Zoom
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(zoom = TRUE),
  "09_zoom"
)

# Test 10: Combined tooltip + hover + zoom
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(tooltip = TRUE, hover = "enlarge", zoom = TRUE),
  "10_combined_interact"
)

# ============================================================
# GROUP 3: Animation (slide/fade previously working)
# ============================================================

cat("\n--- GROUP 3: Animation ---\n")

# Test 11: Slide animation
save_test(
  glyph(data, x = Name, y = EconomicWeight) |>
    mark_bar(color = Source) |>
    animate(transition = "slide", stagger = 50),
  "11_animate_slide"
)

# Test 12: Fade animation
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    animate(transition = "fade", duration = 800),
  "12_animate_fade"
)

# Test 13: Morph animation (WAS BROKEN)
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source, size = EconomicWeight) |>
    animate(by = Source, transition = "morph", duration = 800),
  "13_animate_morph"
)

# ============================================================
# GROUP 4: Previously broken features
# ============================================================

cat("\n--- GROUP 4: Previously broken features ---\n")

# Test 14: mark_text with smart_repel
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    mark_text(label = Name, smart_repel = TRUE),
  "14_mark_text"
)

# Test 15: mark_ribbon
ribbon_data <- data.frame(
  x = 1:10,
  y = cumsum(rnorm(10, sd = 2)),
  y_min = cumsum(rnorm(10, sd = 2)) - 2,
  y_max = cumsum(rnorm(10, sd = 2)) + 2
)
save_test(
  glyph(ribbon_data, x = x) |>
    mark_ribbon(y_min = y_min, y_max = y_max) |>
    mark_line(y = y),
  "15_mark_ribbon"
)

# Test 16: mark_link
link_data <- data.frame(
  x = c(1, 2, 3), y = c(1, 3, 2),
  x2 = c(2, 3, 4), y2 = c(3, 2, 4)
)
save_test(
  glyph(link_data, x = x, y = y) |>
    mark_link(x2 = x2, y2 = y2),
  "16_mark_link"
)

# Test 17: compose hstack
p1 <- glyph(data, x = Heritability, y = Accuracy) |>
  mark_point(color = Source) |>
  interact(tooltip = TRUE)
p2 <- glyph(data, x = DesiredGain, y = Response) |>
  mark_point(color = Source) |>
  interact(tooltip = TRUE)
save_test(
  compose(p1, p2, type = "hstack"),
  "17_compose_hstack"
)

# Test 18: compose grid (3 panels)
p3 <- glyph(data, x = Name, y = EconomicWeight) |>
  mark_bar(color = Source)
save_test(
  compose(p1, p2, p3, type = "grid"),
  "18_compose_grid"
)

# Test 19: facet
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point() |>
    facet(cols = Source),
  "19_facet"
)

# Test 20: marginals
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    marginals(x = "histogram", y = "density"),
  "20_marginals"
)

# Test 21: inset
main_plot <- glyph(data, x = Heritability, y = Response) |>
  mark_point(color = Source) |>
  interact(tooltip = TRUE)
detail_plot <- glyph(data, x = Name, y = Accuracy) |>
  mark_bar(color = Source)
save_test(
  inset(main_plot, detail_plot, position = "top-right"),
  "21_inset"
)

# Test 22: selection (legend click to filter)
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    selection("legend_filter", type = "legend", fields = "Source"),
  "22_selection_legend"
)

# Test 23: interact click = "select"
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(click = "select"),
  "23_click_select"
)

# Test 24: crossfilter (linked brushing across composed panels)
cp1 <- glyph(data, x = Heritability, y = Accuracy) |>
  mark_point(color = Source) |>
  interact(brush = TRUE)
cp2 <- glyph(data, x = DesiredGain, y = Response) |>
  mark_point(color = Source) |>
  interact(brush = TRUE)
save_test(
  compose(cp1, cp2, type = "hstack", linked_selections = TRUE),
  "24_crossfilter"
)

# ============================================================
# GROUP 5: Scales and theming
# ============================================================

cat("\n--- GROUP 5: Scales and theming ---\n")

# Test 25: scale_log with base
save_test(
  glyph(mtcars, x = wt, y = hp) |>
    mark_point() |>
    scale_log("y", base = 2),
  "25_scale_log"
)

# Test 26: theme dark
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    interact(tooltip = TRUE) |>
    theme_tokens(preset = "dark") |>
    titles(title = "Dark Theme Test"),
  "26_theme_dark"
)

# Test 27: theme presentation
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    theme_tokens(preset = "presentation") |>
    titles(title = "Presentation Theme", subtitle = "Larger fonts"),
  "27_theme_presentation"
)

# Test 28: custom theme tokens
save_test(
  glyph(data, x = Heritability, y = Accuracy) |>
    mark_point(color = Source) |>
    theme_tokens(font = "Georgia, serif", bg = "#1a1a2e", grid = "y") |>
    titles(title = "Custom Theme"),
  "28_theme_custom"
)

# ============================================================
# GROUP 6: Export and interop
# ============================================================

cat("\n--- GROUP 6: Export and interop ---\n")

# Test 29: JSON export
json_path <- file.path(outdir, "29_export.json")
spec <- glyph(data, x = Heritability, y = Accuracy) |>
  mark_point(color = Source)
export(spec, json_path)
cat("Saved: 29_export ->", json_path, "\n")
json_valid <- tryCatch({
  jsonlite::fromJSON(json_path)
  TRUE
}, error = function(e) FALSE)
cat("  JSON valid:", json_valid, "\n")

# Test 30: Vega-Lite export
vl <- to_vegalite(spec)
vl_valid <- tryCatch({
  parsed <- jsonlite::fromJSON(vl)
  grepl("vega-lite", parsed$`$schema`)
}, error = function(e) FALSE)
cat("Saved: 30_vegalite (in memory)\n")
cat("  Vega-Lite valid:", vl_valid, "\n")

cat("\n=== ALL 30 TESTS SAVED ===\n")
cat("Test directory:", outdir, "\n")
cat("Now verify each HTML file with headless Chrome.\n")
