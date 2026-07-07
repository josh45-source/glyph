# Add animation/transition behavior

Add animation/transition behavior

## Usage

``` r
animate(
  spec,
  transition = "morph",
  duration = 500,
  stagger = 0,
  by = NULL,
  easing = "ease-in-out",
  loop = FALSE
)
```

## Arguments

- spec:

  A glyph_spec

- transition:

  Transition type: "morph", "fade", "slide", "none"

- duration:

  Duration in milliseconds

- stagger:

  Delay between successive marks in ms (for entrance effects)

- by:

  Column that defines animation keyframes (like gganimate's
  transition_states). e.g. by = year plays through years.

- easing:

  Easing function: "linear", "ease-in", "ease-out", "ease-in-out",
  "bounce", "elastic"

- loop:

  Repeat animation (TRUE, FALSE, or number of times)

## Value

Modified glyph_spec

## Examples

``` r
# Entrance animation: bars grow from baseline
glyph(mtcars, x = cyl, y = mpg) |>
  mark_bar() |>
  animate(transition = "slide", stagger = 50)
#> <glyph_spec: 32 x 11, 1 mark(s)>

# Keyframe animation: morph between groups
glyph(mtcars, x = wt, y = mpg) |>
  mark_point(size = hp, color = cyl) |>
  animate(by = gear, transition = "morph", duration = 800)
#> <glyph_spec: 32 x 11, 1 mark(s)>
```
