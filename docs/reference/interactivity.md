# First-Class Interactivity

Unlike ggplot2 where interactivity is bolted on via ggplotly(), glyph
treats interaction as part of the visualization grammar. Interactions
are declared in the spec and compiled to the appropriate backend (D3
events for HTML, Shiny bindings for server-side).

## Details

Design philosophy: interactions are *selections* that filter or
highlight marks. This follows Vega-Lite's insight that most interactions
are really about defining subsets of the data. A tooltip is "select the
nearest point, show its values." Brushing is "select points in a
rectangle, highlight them."
