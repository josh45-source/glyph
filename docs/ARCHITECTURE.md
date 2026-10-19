# glyph architecture and design decisions

This document explains how glyph is put together and why. It is written
for contributors and for anyone curious about what happens between a
pipeline and the plot in the browser.

## 1. The spec comes first

Building a plot produces a plain R list that describes it completely.
Nothing is drawn at this stage:

    glyph_spec = {
      data:      data.frame or reference
      mappings:  list of quosures (lazy, not evaluated)
      marks:     list of mark descriptors
      scales:    list of scale configs
      interact:  list of interaction configs
      animate:   animation config
      theme:     token map
      layout:    composition config
    }

Most of the rest of the design follows from this. A spec can be printed,
diffed and tested without rendering anything.
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
turns it into JSON that can be saved, sent to a server or embedded in a
page. The spec says nothing about how it will be drawn, so a second
renderer could be added without changing how plots are written. Its
structure is close to Vega-Lite’s, which is what makes
[`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md)
possible.

## 2. Mappings are quosures

`glyph(data, x = wt, y = mpg)` does not evaluate `wt` or `mpg`. rlang
captures each one together with the environment it was written in.
Global mappings go on
[`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md),
and each mark can add or override its own:

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``mtcars``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  `[`mark_point`](https://josh45-source.github.io/glyph/reference/mark_point.md)`(``color ``=`` ``cyl``)`

Quosures are evaluated only during
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md).
A mapping can be a bare column name or an expression such as `log(wt)`
or `factor(cyl)`, and the expression sees both the data columns and the
variables around it.

## 3. Marks and transforms

Points, lines, bars, areas, text, rules, ribbons and links each draw the
data they are given. They do not summarise it.

Statistical summaries are planned as separate, explicit steps that run
on the data before it reaches a mark. None exist yet. The intended shape
is:

\
[`glyph`](https://josh45-source.github.io/glyph/reference/glyph.md)`(``data``, x ``=`` ``wt``, y ``=`` ``mpg``)`` ``|>`\
`  ``transform_smooth``(``method ``=`` ``"loess"``, se ``=`` ``TRUE``)`` ``|>``  ``# planned`\
`  `[`mark_ribbon`](https://josh45-source.github.io/glyph/reference/mark_ribbon.md)`(``y_min ``=`` ``.lower``, y_max ``=`` ``.upper``)`` ``|>`\
`  `[`mark_line`](https://josh45-source.github.io/glyph/reference/mark_line.md)`(``y ``=`` ``.fitted``)`

Written this way, the path from raw data to transform to mark is visible
in the code.

## 4. Interactions are selections

Vega-Lite treats a tooltip as a single-point selection that shows
values, and glyph follows that model. A brush is an interval selection
that highlights what it covers. Zoom is an interval selection on the
position channels that rescales them.

glyph stores interactions in the spec, next to the marks:

\
[`interact`](https://josh45-source.github.io/glyph/reference/interact.md)`(`\
`  tooltip ``=`` ``TRUE``,     ``# point selection, show values`\
`  brush ``=`` ``TRUE``,       ``# interval selection, highlight`\
`  zoom ``=`` ``TRUE``,        ``# interval selection, rescale`\
`  crossfilter ``=`` ``TRUE``  ``# pass the selection to linked views`\
`)`

Because they are part of the spec, interactions are kept when a plot is
exported to HTML. They can be described without knowing the renderer,
and a future Shiny integration could read selection events on the
server.

## 5. Theme tokens

Colours, fonts and spacing come from a short list of named values that
cascade through the plot:

    font       ->  all text elements
    font_size  ->  base size; title = font_size x title_size
    bg         ->  plot background; fg is derived from it for contrast
    fg         ->  text, axis lines, ticks
    accent     ->  colour for single-series marks
    grid       ->  grid visibility and colour (derived from bg)
    padding    ->  all margins

Setting `bg = "#1a1a2e"` gives light text (`fg = "#e0e0e0"`), a grid
colour that shows against the dark background (`grid_color = "#2a2a4a"`)
and matching tooltip styles. Tokens work the way CSS custom properties
do: you change one value and everything that depends on it follows.

## 6. Composition

Layout is part of the spec too.
[`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
arranges several plots in one widget:

\
[`compose`](https://josh45-source.github.io/glyph/reference/compose.md)`(``p1``, ``p2``, ``p3``,`\
`        type ``=`` ``"wrap"``,`\
`        linked_selections ``=`` ``TRUE``,`\
`        shared_scales ``=`` ``"x"``)`

Since the layout knows about every panel, a selection in one panel can
highlight rows in the others, and shared scales are computed across all
panels at once. The whole layout renders as a single widget.

## 7. Compilation and renderers

[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
resolves mappings and scales and produces the JSON that the renderer
reads. There is one renderer today:

    glyph_spec --> compile() --> D3.js + SVG (htmlwidgets)
                       |
                       +--> Canvas 2D (planned)
                       +--> WebGL / regl (planned)
                       +--> static SVG / PDF export (planned)

An earlier version of
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
chose an `engine` (“html”, “canvas” or “webgl”) from the size of the
data. Nothing downstream ever used that value, because only the D3/SVG
renderer existed, so the choice had no effect.
[`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
now accepts only `"auto"` (which means `"html"`) or `"html"`, and
rejects other engines. If a Canvas or WebGL renderer is built, it should
implement the same mark, scale and interaction behaviour, with only the
drawing code differing.

## Known gaps

Statistical transforms. There are none yet. The plan is to start with
explicit `transform_*()` functions for smoothing, binning, density and
aggregation.

Extending glyph. A new mark needs code in both R and the JavaScript
renderer, and that process is not documented yet
([\#9](https://github.com/josh45-source/glyph/issues/9)). For anything
glyph can’t draw,
[`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md)
gives a starting point in Vega-Lite.

Larger datasets. Every mark is an SVG element, and there is no density
rendering or way to switch off costly features
([\#8](https://github.com/josh45-source/glyph/issues/8)).

Static output.
[`export()`](https://josh45-source.github.io/glyph/reference/export.md)
writes HTML and JSON only. Static SVG, PNG and PDF are planned through
headless Chrome, which would keep static output identical to what the
browser draws.

## Technology choices

| Layer | Choice | Rationale |
|----|----|----|
| R API | rlang + base pipe | Bare-name mappings and the native pipe R users already know |
| Serialization | jsonlite | Mature, fast, round-trips R lists to JSON cleanly |
| Interactive rendering | htmlwidgets + D3.js v7 | The standard route from R to browser graphics |
| Large-data rendering | regl (planned) | WebGL without the boilerplate; used by deck.gl |
| Static export | headless Chrome (planned) | Output matches the interactive version |
| Interop | Vega-Lite JSON | Works with R, Python (Altair) and JavaScript |
