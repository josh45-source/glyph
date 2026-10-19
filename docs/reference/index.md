# Package index

## Core

Build and inspect the visualization spec.

- [`glyph()`](https://josh45-source.github.io/glyph/reference/glyph.md)
  : Create a Glyph Visualization
- [`print(`*`<glyph_spec>`*`)`](https://josh45-source.github.io/glyph/reference/print.glyph_spec.md)
  [`knit_print(`*`<glyph_spec>`*`)`](https://josh45-source.github.io/glyph/reference/print.glyph_spec.md)
  : Draw a glyph spec when it is printed
- [`summary(`*`<glyph_spec>`*`)`](https://josh45-source.github.io/glyph/reference/summary.glyph_spec.md)
  : Summarize a glyph specification

## Marks

Geometric layers that draw data onto the plot.

- [`marks`](https://josh45-source.github.io/glyph/reference/marks.md) :
  Visual Marks
- [`mark_point()`](https://josh45-source.github.io/glyph/reference/mark_point.md)
  : Add a point mark (scatterplot)
- [`mark_line()`](https://josh45-source.github.io/glyph/reference/mark_line.md)
  : Add a line mark
- [`mark_bar()`](https://josh45-source.github.io/glyph/reference/mark_bar.md)
  : Add a bar mark
- [`mark_area()`](https://josh45-source.github.io/glyph/reference/mark_area.md)
  : Add an area mark
- [`mark_text()`](https://josh45-source.github.io/glyph/reference/mark_text.md)
  : Add a text/label mark
- [`mark_rule()`](https://josh45-source.github.io/glyph/reference/mark_rule.md)
  : Add a rule (reference line) mark
- [`mark_ribbon()`](https://josh45-source.github.io/glyph/reference/mark_ribbon.md)
  : Add a ribbon/band mark (for confidence intervals, ranges)
- [`mark_link()`](https://josh45-source.github.io/glyph/reference/mark_link.md)
  : Add a link/edge mark (for networks, sankeys, slope graphs)

## Statistical marks

Marks that summarise the distribution of a variable.

- [`mark_boxplot()`](https://josh45-source.github.io/glyph/reference/mark_boxplot.md)
  : Add a boxplot mark
- [`mark_violin()`](https://josh45-source.github.io/glyph/reference/mark_violin.md)
  : Add a violin mark
- [`mark_sina()`](https://josh45-source.github.io/glyph/reference/mark_sina.md)
  : Add a sina mark
- [`mark_histogram()`](https://josh45-source.github.io/glyph/reference/mark_histogram.md)
  : Add a histogram mark

## Interactivity

Tooltips, zoom, brushing, and linked selections.

- [`interactivity`](https://josh45-source.github.io/glyph/reference/interactivity.md)
  : Interactivity
- [`interact()`](https://josh45-source.github.io/glyph/reference/interact.md)
  : Add interactive behaviors to a glyph spec
- [`selection()`](https://josh45-source.github.io/glyph/reference/selection.md)
  : Add a selection parameter (advanced)

## Animation

Transitions and entrance/exit animation.

- [`animation`](https://josh45-source.github.io/glyph/reference/animation.md)
  : Animation Grammar
- [`animate()`](https://josh45-source.github.io/glyph/reference/animate.md)
  : Add animation/transition behavior

## Scales

Control how data maps to visual properties.

- [`scale()`](https://josh45-source.github.io/glyph/reference/scale.md)
  : Define a scale for an aesthetic channel
- [`scale_color()`](https://josh45-source.github.io/glyph/reference/scales.md)
  [`scale_log()`](https://josh45-source.github.io/glyph/reference/scales.md)
  [`scale_time()`](https://josh45-source.github.io/glyph/reference/scales.md)
  : Scales

## Theming

Token-based theme system and plot titles.

- [`theming`](https://josh45-source.github.io/glyph/reference/theming.md)
  : Token-Based Theming
- [`theme_tokens()`](https://josh45-source.github.io/glyph/reference/theme_tokens.md)
  : Set theme tokens
- [`titles()`](https://josh45-source.github.io/glyph/reference/titles.md)
  : Add a title, subtitle, or caption

## Layout

Multi-plot composition and auxiliary panels.

- [`layout`](https://josh45-source.github.io/glyph/reference/layout.md)
  : Layout Composition
- [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  : Compose multiple glyph specs into a layout
- [`print(`*`<glyph_layout>`*`)`](https://josh45-source.github.io/glyph/reference/print.glyph_layout.md)
  [`knit_print(`*`<glyph_layout>`*`)`](https://josh45-source.github.io/glyph/reference/print.glyph_layout.md)
  : Draw a glyph layout when it is printed
- [`summary(`*`<glyph_layout>`*`)`](https://josh45-source.github.io/glyph/reference/summary.glyph_layout.md)
  : Summarize a glyph layout
- [`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.md)
  : Add a marginal plot (histogram/density on axes)
- [`inset()`](https://josh45-source.github.io/glyph/reference/inset.md)
  : Add an inset plot
- [`facet()`](https://josh45-source.github.io/glyph/reference/facet.md)
  : Facet a plot by one or two variables

## Rendering

Compile the spec and render or export it.

- [`rendering`](https://josh45-source.github.io/glyph/reference/rendering.md)
  : Rendering Pipeline
- [`compile()`](https://josh45-source.github.io/glyph/reference/compile.md)
  : Compile a glyph spec to a resolved representation
- [`render()`](https://josh45-source.github.io/glyph/reference/render.md)
  : Render a glyph spec as an htmlwidget
- [`export()`](https://josh45-source.github.io/glyph/reference/export.md)
  : Export to various formats
- [`to_vegalite()`](https://josh45-source.github.io/glyph/reference/to_vegalite.md)
  : Export the spec as Vega-Lite JSON (interop)
