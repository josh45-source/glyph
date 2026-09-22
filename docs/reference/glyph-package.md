# glyph: A Next-Generation Grammar of Interactive Graphics

A modern visualization grammar that treats interactivity, animation, and
composable layouts as first-class concepts rather than afterthoughts.
Designed to address key limitations of existing grammars: native hover,
click, and zoom events, built-in multi-plot composition, and a
token-based theming system. Renders interactive HTML widgets via 'D3.js'
from a single declarative specification.

## Acknowledgements

glyph's design draws directly on the ideas and prior art of others:

- **Leland Wilkinson's *The Grammar of Graphics*** — the layered
  data/mark/scale vocabulary that glyph's spec is structured around.

- **ggplot2** — the aesthetic-mapping model
  ([`aes()`](https://ggplot2.tidyverse.org/reference/aes.html), here
  bare names instead) and the pipeline style of building a plot up in
  layers.

- **Vega-Lite** — the idea of a declarative, serializable JSON spec that
  compiles to a render tree, and treating interactions as selections.

- **ggvis** — an earlier reactive, D3-backed grammar of graphics for R;
  glyph's D3-via-htmlwidgets rendering follows the same path.

- **ggiraph** — ggplot2 output with D3-powered tooltips, hover, and
  selection; a direct influence on glyph's own tooltip/hover/brush
  model.

- **plotly** — the baseline for what an "interactive R plot" should
  offer (zoom, pan, tooltips), which glyph aims to provide natively.

- **patchwork** — the model for glyph's
  [`compose()`](https://josh45-source.github.io/glyph/reference/compose.md)
  multi-plot layout API.

- **gganimate** — the `transition_states()`-style keyframe grammar
  behind `animate(by = ..., transition = "morph")`.

- **ggExtra** — the marginal histogram/density/boxplot pattern behind
  [`marginals()`](https://josh45-source.github.io/glyph/reference/marginals.md).

- **ggrepel** — the inspiration for `mark_text(smart_repel = TRUE)`'s
  label decluttering (glyph uses a simpler iterative pairwise-nudge
  approach rather than ggrepel's force simulation — see
  [`mark_text()`](https://josh45-source.github.io/glyph/reference/mark_text.md)).

This package also bundles [D3.js](https://d3js.org) (Copyright Mike
Bostock, ISC License); see `inst/COPYRIGHTS` for the full notice.

## See also

Useful links:

- <https://github.com/josh45-source/glyph>

- <https://josh45-source.github.io/glyph/>

- Report bugs at <https://github.com/josh45-source/glyph/issues>

## Author

**Maintainer**: Joash Joshua Ayo <joashjoshua789@gmail.com>

Authors:

- Joash Joshua Ayo <joashjoshua789@gmail.com>

Other contributors:

- Mike Bostock (Author of the bundled D3.js library) \[contributor,
  copyright holder\]
