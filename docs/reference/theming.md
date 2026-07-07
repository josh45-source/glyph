# Token-Based Theming

Instead of ggplot2's 90+ theme() arguments, glyph uses a design-token
system. A small set of semantic tokens (font, colors, spacing, sizes)
cascade through the entire visualization. Think of it like CSS custom
properties for plots.

## Details

Tokens cascade: setting `bg` changes the background, but also
automatically adjusts text color for contrast, grid line opacity, and
tooltip styling. You override only what you want; everything else
adapts.
