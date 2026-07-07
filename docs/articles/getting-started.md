# Getting Started with glyph

``` r

library(glyph)
#> 
#> Attaching package: 'glyph'
#> The following object is masked from 'package:base':
#> 
#>     scale
```

This vignette walks through glyph’s core grammar with live, interactive
output. Every plot below is a real `glyph_spec` built with the package
and rendered to an actual D3-backed htmlwidget — not a screenshot.

One thing worth knowing up front: printing a `glyph_spec` at the console
auto-renders it (like a ggplot2 plot), but that auto-render only fires
in an interactive R session. Inside a vignette or pkgdown article the
code runs non-interactively, so each example below ends the pipeline
with an explicit
[`render()`](https://josh45-source.github.io/glyph/reference/render.md)
call to produce the widget.

## 1. A basic scatterplot

No [`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), no
[`factor()`](https://rdrr.io/r/base/factor.html) coercion — aesthetic
mappings are just bare column names passed straight to
[`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md)
and
[`mark_point()`](https://josh45-source.github.io/glyph/reference/mark_point.md).

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  render()
```

## 2. Tooltips and hover, declared in the pipeline

Interactivity is grammar, not glue.
[`interact()`](https://josh45-source.github.io/glyph/reference/interact.md)
turns on tooltips and a hover effect right where the plot is built, and
[`titles()`](https://josh45-source.github.io/glyph/reference/titles.md)
adds a title in the same pipe — no
[`ggplotly()`](https://rdrr.io/pkg/plotly/man/ggplotly.html) conversion
step, no lost formatting.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(tooltip = TRUE, hover = "enlarge") |>
  titles(title = "Motor Trend Cars") |>
  render()
```

Hover over a point to see it enlarge; hover longer to see the tooltip.

## 3. Animated bar chart

[`animate()`](https://josh45-source.github.io/glyph/reference/animate.md)
declares a transition as part of the spec. `stagger` offsets each bar’s
entrance animation so they draw in sequence rather than all at once.

``` r

glyph(mtcars, x = cyl, y = mpg) |>
  mark_bar() |>
  animate(transition = "slide", stagger = 50) |>
  render()
```

Reload this page (or re-run the chunk in an R session) to see the bars
slide in.

## 4. Token-based dark theme

Instead of ggplot2’s dozens of individual
[`theme()`](https://ggplot2.tidyverse.org/reference/theme.html)
arguments,
[`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)
takes a small preset (or individual tokens like `bg`, `font`, `accent`)
and cascades foreground, grid, and title colors automatically for
contrast.

``` r

glyph(mtcars, x = wt, y = mpg) |>
  mark_point(color = cyl) |>
  interact(tooltip = TRUE) |>
  theme_tokens(preset = "dark") |>
  titles(title = "Dark Theme Example") |>
  render()
```

## 5. Composed multi-plot layout

[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
arranges multiple `glyph_spec` objects into a single layout — here, two
scatterplots side by side — without reaching for `patchwork` or
`cowplot`. Composed layouts are rendered the same way as a single spec:
pass the layout to
[`render()`](https://josh45-source.github.io/glyph/reference/render.md).

``` r

p1 <- glyph(mtcars, x = wt, y = mpg) |> mark_point(color = cyl)
p2 <- glyph(mtcars, x = hp, y = mpg) |> mark_point(color = cyl)

compose(p1, p2, type = "hstack") |>
  render()
```

## Where to next

- Browse the [function
  reference](https://josh45-source.github.io/glyph/reference/index.md)
  for every mark, scale, and layout primitive glyph provides.
- Read [glyph vs ggplot2: Side-by-Side
  Comparison](https://josh45-source.github.io/glyph/articles/comparison.md)
  for a broader tour of how the two grammars differ.
