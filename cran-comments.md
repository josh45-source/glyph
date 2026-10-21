## Release summary

This is a feature and bug-fix release.

* New features: Shiny support (`glyphOutput()` and `renderGlyph()`, with
  selections returned to R), boxplot, violin, sina, histogram and polygon
  marks, plots that draw themselves in R Markdown and Quarto, much faster
  preparation of plots with many rows, and two new vignettes.
* Bug fixes: plots now fit their container, bar and area charts start at
  zero, tooltips keep up on large plots, `export()` works without pandoc,
  and several touch and brushing problems are fixed.
* One breaking change: `scale()` is renamed `set_scale()`, so glyph no
  longer masks `base::scale()` when it is attached.

## Test environments

* GitHub Actions, `R CMD check` on every pull request:
  * macOS (macos-latest), R release (4.6.1)
  * Windows (windows-latest), R release (4.6.1)
  * Ubuntu 24.04 (ubuntu-latest), R devel, R release (4.6.1) and
    R oldrel-1
* GitHub Actions, Ubuntu 24.04, R 4.6.1: `R CMD check --as-cran` with the
  remote and incoming checks and the PDF manual
* local Ubuntu 24.04, R 4.5.3

## R CMD check results

0 errors | 0 warnings | 0 notes

Two notes appeared only on our own machines:

* "checking HTML version of manual ... Skipping checking HTML validation:
  no command 'tidy' found" on the GitHub Actions runner, which has no HTML
  Tidy.
* "checking for future file timestamps ... unable to verify current time"
  on the local machine, which had no network access.

## Tests

The browser tests (files `tests/testthat/test-browser*.R`) draw plots in a
headless Chrome through the chromote package, and one runs a Shiny app in a
background R process. They call `testthat::skip_on_cran()`, so they are
skipped on CRAN. They run on GitHub Actions. The other tests run on CRAN and
take a few seconds.

## Downstream dependencies

There are currently no downstream dependencies for this package.
