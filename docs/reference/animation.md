# Animation Grammar

Animations in glyph are declarative state transitions, not
frame-by-frame rendering. You describe *what changes* and *how it should
interpolate*, and the renderer handles the rest.

## Details

Two animation paradigms:

- **Transitions**: animate between data states (e.g. year 2020 → 2021).
  Marks morph smoothly, entering/exiting as data changes.

- **Entrances**: animate marks appearing on first render (stagger bars
  growing from zero, points fading in).
