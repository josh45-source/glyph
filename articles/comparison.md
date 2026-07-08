# glyph vs ggplot2: Side-by-Side Comparison

## 1. Basic Scatterplot

**ggplot2:**

``` r

ggplot(mtcars, aes(x = wt, y = mpg, color = factor(cyl))) +
  geom_point(size = 3) +
  scale_color_brewer(palette = "Set2") +
  labs(
    title = "Motor Trend Cars",
    x = "Weight (1000 lbs)",
    y = "Miles per Gallon",
    color = "Cylinders"
  ) +
  theme_minimal()
```

**glyph:**

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, style = list(size = 6)) |>
  scale_color("Set2") |>
  scale("x", label = "Weight (1000 lbs)") |>
  scale("y", label = "Miles per Gallon") |>
  titles(title = "Motor Trend Cars") |>
  theme_tokens(preset = "minimal")
```

**What changed:** No `aes()`, no
[`factor()`](https://rdrr.io/r/base/factor.html) coercion, no `+`
operator. Pipeline reads left-to-right with `|>`. Color scale is one
function call.

------------------------------------------------------------------------

## 2. Interactive Exploration

**ggplot2 + plotly:**

``` r

library(plotly)

p <- ggplot(mtcars, aes(x = wt, y = mpg, color = factor(cyl),
                         text = paste("Car:", rownames(mtcars),
                                      "<br>MPG:", mpg,
                                      "<br>Weight:", wt))) +
  geom_point(size = 3)

ggplotly(p, tooltip = "text")
# Note: loses theme, some formatting; no brush-to-filter
```

**glyph:**

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(
    tooltip = "Car: {.rownames}\nMPG: {mpg}\nWeight: {wt}",
    zoom = TRUE,
    brush = TRUE,
    hover = "enlarge"
  )
# Theme, formatting, all interactions preserved — no conversion step
```

**What changed:** No lossy ggplotly() conversion. Interactions are part
of the spec, not a post-hoc wrapper. Tooltip template is a simple
string, not a paste() call inside aes().

------------------------------------------------------------------------

## 3. Animated Bar Chart

**ggplot2 + gganimate:**

``` r

library(gganimate)

p <- ggplot(gapminder, aes(x = continent, y = lifeExp, fill = continent)) +
  geom_col(stat = "summary", fun = "mean") +
  transition_states(year, transition_length = 2, state_length = 1) +
  labs(title = "Year: {closest_state}") +
  theme_minimal() +
  enter_grow() +
  ease_aes("bounce-out")

animate(p, fps = 20, width = 600, height = 400)
# Renders to GIF (not interactive)
```

**glyph:**

``` r

glyph(gapminder, x = continent, y = lifeExp) |>
  mark_bar() |>
  animate(by = year, transition = "morph", easing = "bounce") |>
  interact(tooltip = TRUE) |>
  titles(title = "Life Expectancy by Continent") |>
  theme_tokens(preset = "minimal")
# Renders as interactive HTML with playback controls
```

**What changed:** Animation is one function call in the pipeline, not a
separate package. Output is interactive HTML (play/pause/scrub), not a
static GIF. Tooltips work during animation.

------------------------------------------------------------------------

## 4. Multi-Panel Dashboard

**ggplot2 + patchwork:**

``` r

library(patchwork)

p1 <- ggplot(mtcars, aes(wt, mpg)) + geom_point() + theme_minimal()
p2 <- ggplot(mtcars, aes(hp, mpg)) + geom_point() + theme_minimal()
p3 <- ggplot(mtcars, aes(factor(cyl), mpg)) + geom_boxplot() + theme_minimal()

(p1 | p2) / p3 +
  plot_annotation(title = "Motor Trend Dashboard")
# No linked interactions between panels
```

**glyph:**

``` r

p1 <- glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

p2 <- glyph(mtcars, x = hp, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

p3 <- glyph(mtcars, x = cyl, y = mpg) |>
  mark_bar()

compose(p1, p2, p3,
        type = "wrap",
        linked_selections = TRUE,
        title = "Motor Trend Dashboard")
# Brushing in p1 highlights the same cars in p2 and p3
```

**What changed:** No extra package. Linked selections across panels via
`linked_selections = TRUE`. Brush in one panel cross-filters the others.

------------------------------------------------------------------------

## 5. Marginal Distributions

**ggplot2 + ggExtra:**

``` r

library(ggExtra)

p <- ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
  geom_point() +
  theme_minimal()

ggMarginal(p, type = "histogram", groupColour = TRUE)
```

**glyph:**

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  marginals(x = "histogram", y = "density", size = 0.2)
```

**What changed:** Built-in. One function call. Size is configurable.

------------------------------------------------------------------------

## 6. Dark Theme

**ggplot2:**

``` r

ggplot(mtcars, aes(wt, mpg)) +
  geom_point(color = "#6ec6ff") +
  theme(
    plot.background = element_rect(fill = "#1a1a2e"),
    panel.background = element_rect(fill = "#1a1a2e"),
    panel.grid.major = element_line(color = "#2a2a4a"),
    panel.grid.minor = element_blank(),
    axis.text = element_text(color = "#e0e0e0"),
    axis.title = element_text(color = "#e0e0e0"),
    text = element_text(color = "#e0e0e0")
  )
# 9 lines of theme overrides
```

**glyph:**

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  theme_tokens(preset = "dark")
# 1 line. All contrast/grid/text colors auto-derived.
```

Or with custom colors:

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  theme_tokens(bg = "#1a1a2e")
  # fg, grid_color, accent all adapt automatically
```

------------------------------------------------------------------------

## 7. Export Flexibility

**ggplot2:**

``` r

ggsave("plot.png", width = 8, height = 6)   # static only
ggsave("plot.pdf", width = 8, height = 6)   # static only
ggsave("plot.svg", width = 8, height = 6)   # static only
# No interactive HTML export. No spec export.
```

**glyph:**

``` r

spec <- glyph(mtcars, x = wt, y = mpg) |>
  mark_point() |>
  interact(tooltip = TRUE, zoom = TRUE)

export(spec, "plot.html")              # interactive HTML
export(spec, "plot.svg")               # static SVG
export(spec, "plot.json")             # raw spec (inspect/debug)
cat(to_vegalite(spec))                 # Vega-Lite JSON (use in Python/JS)
```

------------------------------------------------------------------------

## Summary: When to Use Which

**Use ggplot2 when:** - You need a specific extension (ggridges,
ggalluvial, etc.) - You’re producing static plots for print/PDF - You
want maximum community support and StackOverflow answers - Statistical
transforms (smooth, density2d) are central to your workflow

**Use glyph when:** - Interactivity is part of the deliverable
(dashboards, reports, exploration) - You want linked views without
Shiny - Animation is important (presentations, storytelling) - You’re
working with large datasets (\>10K points) - You want a cleaner, more
composable API - You need to export specs to JavaScript (Vega-Lite,
D3) - Theme consistency across many plots matters (token system)

------------------------------------------------------------------------

## Live Examples

The code above is illustrative — here are four of those exact patterns
rendered for real, using `mtcars`. Every widget below is a live D3
chart, not a screenshot; hover, click, brush, and zoom them the same way
you would in your own R session.

### Colored scatterplot

The one-line color scale and label calls from section 1, rendered.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl, style = list(size = 6)) |>
  scale_color("Set2") |>
  scale("x", label = "Weight (1000 lbs)") |>
  scale("y", label = "Miles per Gallon") |>
  titles(title = "Motor Trend Cars") |>
  theme_tokens(preset = "minimal") |>
  render()
```

### Tooltip, zoom, and brush — no `ggplotly()` conversion

The interactions from section 2, declared directly in the pipeline and
fully preserved (unlike a lossy `ggplotly()` wrap).

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(
    tooltip = "{cyl} cyl, {mpg} mpg at {wt} tons",
    zoom = TRUE,
    brush = TRUE,
    hover = "enlarge"
  ) |>
  render()
```

### Linked dashboard panels

The
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md) +
`linked_selections` pattern from section 4. Brush points in the left
panel and watch the same cars highlight on the right.

``` r

p1 <- glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

p2 <- glyph(mtcars, x = hp, y = mpg) |>
  mark_point(color = cyl) |>
  interact(brush = TRUE)

compose(p1, p2, type = "hstack", linked_selections = TRUE) |>
  render()
```

### Marginal distributions

The one-line
[`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.md)
call from section 5, in place of `ggExtra`.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  marginals(x = "histogram", y = "density", size = 0.2) |>
  render()
```
