# Visual Marks

Marks are the visual encodings in glyph — analogous to ggplot2's geoms
but with key differences:

1.  **Mappings without aes()**: pass bare column names directly.

2.  **Per-mark data**: each mark can have its own data source, enabling
    multi-dataset plots without awkward data parameter overrides.

3.  **Built-in interaction hints**: marks carry interaction metadata
    (what happens on hover, click, drag) as part of the spec.

4.  **Transition-aware**: marks know how to interpolate between states
    for animation.
