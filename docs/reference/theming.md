# Token-Based Theming

A theme is set with design tokens: a small set of named values (font,
colours, spacing, sizes) that cascade through the whole plot, much like
CSS custom properties.

## Details

Tokens cascade: setting `bg` changes the background, but also
automatically adjusts text color for contrast, grid line opacity, and
tooltip styling. You override only what you want; everything else
adapts.
