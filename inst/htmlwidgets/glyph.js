// glyph.js — D3.js rendering engine for the glyph R package
// This is the htmlwidgets binding that compiles glyph specs into interactive SVG

console.log("glyph widget loaded");

HTMLWidgets.widget({
  name: "glyph",
  type: "output",

  factory: function(el, width, height) {
    let spec = null;
    // What is selected in the current drawing (see selectionSlot()), and the
    // last value reported, as JSON.
    let selection = null;
    let reported = "null";

    // Tells Shiny (as input$<id>_selected) and anything listening on the
    // widget (a "glyph-selection" event) when the selection changes. Every
    // redraw starts with nothing selected, so a redraw that removes a
    // selection reports NULL.
    function reportSelection() {
      const value = selectionValue(selection);
      const json = JSON.stringify(value);
      if (json === reported) return;
      reported = json;
      el.dispatchEvent(new CustomEvent("glyph-selection", { detail: value }));
      if (HTMLWidgets.shinyMode && el.id && window.Shiny && typeof Shiny.setInputValue === "function") {
        Shiny.setInputValue(el.id + "_selected:glyph.selection", value);
      }
    }

    return {
      renderValue: function(x) {
        // In Shiny, renderGlyph() turns NULL into an empty widget, which
        // clears the last plot and its selection.
        if (!x || x.empty) {
          spec = null;
          selection = null;
          el.innerHTML = "";
          reportSelection();
          return;
        }
        try {
          doRender(x);
        } catch (err) {
          console.error("glyph widget renderValue failed:", err);
          el.innerHTML = "";
          const msg = document.createElement("pre");
          msg.style.color = "#b00020";
          msg.style.fontFamily = "monospace";
          msg.style.fontSize = "12px";
          msg.style.whiteSpace = "pre-wrap";
          msg.textContent = "glyph render error: " + (err && err.message ? err.message : err);
          el.appendChild(msg);
        }
      },

      resize: function(newW, newH) {
        if (spec) this.renderValue({ spec });
      }
    };

    // Draws the plot at the size of the container it is actually in. Using the
    // spec's own width and height (600 x 400 unless set) instead made the SVG,
    // which fills the container's width and keeps the spec's aspect ratio,
    // taller than a wide, short container such as RStudio's Viewer pane, so
    // its x axis was cut off (#17). When the container has no size yet (e.g.
    // it is hidden), fall back to the spec's size.
    function doRender(x) {
      spec = inflateSpec(x.spec);
      const box = el.getBoundingClientRect();
      let w = Math.floor(box.width) || spec.width || width || 600;
      let h = Math.floor(box.height) || spec.height || height || 400;
      draw(w, h);

      // Anything drawn outside the SVG (a layout title, facet labels, the
      // keyframe play/pause button) takes space too. If the content still
      // overflows the container, redraw smaller by the overflow.
      for (let i = 0; i < 2; i++) {
        const overX = el.scrollWidth - el.clientWidth;
        const overY = el.scrollHeight - el.clientHeight;
        if (overX <= 0 && overY <= 0) break;
        w = Math.max(80, w - Math.max(0, overX));
        h = Math.max(80, h - Math.max(0, overY));
        draw(w, h);
      }
      reportSelection();
    }

    function draw(w, h) {
      el.innerHTML = "";

      if (spec.type === "layout") {
        el.style.background = "transparent";
        selection = selectionSlot("layout", reportSelection, spec.panel_names);
        renderLayout(el, spec, w, h, selection);
        return;
      }

      if (spec.facets && (spec.facets.cols || spec.facets.rows)) {
        el.style.background = "transparent";
        selection = selectionSlot("facets", reportSelection);
        renderFacets(el, spec, w, h, selection);
        return;
      }

      const theme = spec.theme || {};
      el.style.background = theme.bg || "#fff";
      selection = selectionSlot("plot", reportSelection);
      renderSpecInto(el, spec, { width: w, height: h, standalone: true, selectionSlot: selection });
    }
  }
});

// ---- Data payload ---------------------------------------------------------------
//
// The R side sends a plot's rows one column at a time ({columns: {name:
// [...]}, n}), which serializes far faster than one object per row. A mark
// that draws the plot's own rows doesn't send them again: it names the
// columns it uses and, when rows were dropped for missing values, the rows it
// keeps ({from: "plot", fields, rows}). Statistical summaries still arrive as
// one object per box, bin or polygon ({values}). inflateSpec() turns the
// first two back into row objects ({values}) with the same keys, in the same
// order, so everything below works on exactly the data it always has.
//
// Date and date-time fields arrive as milliseconds and are named in
// `temporal` (see temporal_ms() in R/render.R). They become Date objects here,
// once, so scales, marks, tooltips and brushing all see the same values. A
// Date's UTC fields hold the date or clock time as R prints it, so they are
// drawn on UTC scales and shown with UTC formats.

// jsonlite writes a one-element vector as a bare value, not an array.
function columnArray(v) {
  return Array.isArray(v) ? v : [v];
}

// Each row object remembers which row of the plot's data it is (0-based),
// so a selection can be reported to Shiny as rows of the data frame given to
// glyph(), whatever was dropped or recomputed on the way. A symbol key, so
// it never shows up among the row's fields (tooltips, the legend).
const GLYPH_ROW = Symbol("glyph row");

// `plotRows` maps column position to plot row: null when they are the same,
// false for rows of another data frame (a mark's own `data`). `temporal` is
// the set of date and date-time fields.
function rowsFromColumns(columns, n, fields, rowIndex, plotRows, temporal) {
  const names = fields ? columnArray(fields) : Object.keys(columns || {});
  const cols = names.map(f => (n > 0 ? columnArray(columns[f]) : []));
  const isDate = names.map(f => !!temporal && temporal.has(f));
  const index = rowIndex === null || rowIndex === undefined ? null : columnArray(rowIndex);
  const count = index ? index.length : n;
  const rows = new Array(count);
  for (let r = 0; r < count; r++) {
    const i = index ? index[r] : r;
    const row = {};
    for (let c = 0; c < names.length; c++) row[names[c]] = isDate[c] ? toDate(cols[c][i]) : cols[c][i];
    if (plotRows !== false) row[GLYPH_ROW] = plotRows ? plotRows[i] : i;
    rows[r] = row;
  }
  return rows;
}

// The date and date-time fields of a data payload.
function temporalFields(d) {
  return new Set(d && d.temporal ? columnArray(d.temporal) : []);
}

// A missing date stays missing rather than becoming 1970-01-01.
function toDate(v) {
  return v === null || v === undefined ? v : new Date(v);
}

// Rebuilds row objects throughout a compiled spec: the plot's own data, each
// mark's data, compose() panels and an inset() plot. Safe to call again on a
// spec it has already inflated (e.g. when the widget is resized).
function inflateSpec(spec) {
  if (!spec || spec.__glyphInflated) return spec;
  Object.defineProperty(spec, "__glyphInflated", { value: true });

  if (spec.type === "layout") {
    (spec.panels || []).forEach(inflateSpec);
    return spec;
  }

  const top = spec.data || {};
  const topTemporal = temporalFields(top);
  if (top.columns) spec.data = { values: rowsFromColumns(top.columns, top.n, null, null, undefined, topTemporal) };

  for (const mark of (spec.marks || [])) {
    const d = mark.data;
    if (!d) continue;
    const temporal = d.from === "plot" ? topTemporal : temporalFields(d);
    if (d.from === "plot") {
      mark.data = { values: rowsFromColumns(top.columns, top.n, d.fields, d.rows, undefined, temporal) };
    } else if (d.columns) {
      const plotRows = mark.own_data ? false : (mark.plot_rows === undefined ? null : columnArray(mark.plot_rows));
      mark.data = { values: rowsFromColumns(d.columns, d.n, null, null, plotRows, temporal) };
    } else if (d.values && temporal.size) {
      // Statistical summaries: dates in their grouping fields.
      d.values.forEach(rec => temporal.forEach(f => { if (f in rec) rec[f] = toDate(rec[f]); }));
    }
    // A statistical mark's groups of dates, which its axis lists.
    for (const enc of Object.values(mark.encoding || {})) {
      if (enc && enc.domain && temporal.has(enc.field)) enc.domain = columnArray(enc.domain).map(toDate);
    }
  }

  if (spec.layout && spec.layout.inset) inflateSpec(spec.layout.inset);
  return spec;
}

// ---- Selections reported to Shiny ---------------------------------------------
//
// A widget keeps what the user has selected as rows of the plot's data, in a
// small tree of slots: one slot per plot, holding a Set of 0-based row
// numbers, or null when nothing is selected. A brush, a click select or a
// legend click replaces its plot's set. A facet() grid has a slot per panel;
// the panels split one data frame, so it reports their union. A compose()
// layout has a slot per panel, nested layouts included.

function selectionSlot(kind, onChange, names) {
  return { kind, rows: null, children: [], names: names === undefined ? null : columnArray(names), onChange };
}

function childSlot(parent, kind, names) {
  if (!parent) return null;
  const slot = selectionSlot(kind, parent.onChange, names);
  parent.children.push(slot);
  return slot;
}

function setSlotRows(slot, rows) {
  if (!slot) return;
  slot.rows = rows;
  slot.onChange();
}

// The value Shiny receives, before R turns it into input$<id>_selected (see
// selection_from_json() in R/shiny.R): null when nothing is selected, the
// sorted 1-based row numbers for a plot or facet grid, and for a layout
// {panels: [one value per panel], names: [...]}, or null when no panel has a
// selection.
function selectionValue(slot) {
  if (!slot) return null;
  if (slot.kind === "layout") {
    const panels = slot.children.map(selectionValue);
    if (panels.every(v => v === null)) return null;
    return slot.names ? { panels, names: slot.names } : { panels };
  }
  const sets = (slot.kind === "facets" ? slot.children.map(c => c.rows) : [slot.rows]).filter(Boolean);
  if (sets.length === 0) return null;
  const rows = new Set();
  sets.forEach(s => s.forEach(r => rows.add(r)));
  return [...rows].sort((a, b) => a - b).map(r => r + 1);
}

// ---- Core single-spec renderer ------------------------------------------------
//
// Renders one glyph_spec (marks + scales + theme + optional marginals/inset
// layout) into `container`. Used for: the top-level widget, each panel of a
// compose() layout, and each panel of a facet() grid.
//
// Returns a descriptor object used by the layout/facet/crossfilter machinery:
//   { svg, plotArea, scales, data, applyExternalSelection, onSelectionChange }

function renderSpecInto(container, spec, opts) {
  opts = opts || {};
  const theme = spec.theme || {};
  const W = opts.width || spec.width || 600;
  const H = opts.height || spec.height || 400;
  const basePad = theme.padding || 40;

  const marginal = spec.layout && spec.layout.type === "marginals" ? spec.layout : null;
  const marginalFrac = marginal ? Math.max(0, Math.min(0.4, marginal.size ?? 0.15)) : 0;
  const topPad = basePad + (marginal && marginal.x ? H * marginalFrac : 0);
  const rightPad = basePad + (marginal && marginal.y ? W * marginalFrac : 0);

  let svg;
  if (opts.targetSvg) {
    svg = opts.targetSvg.attr("width", W).attr("height", H).attr("viewBox", `0 0 ${W} ${H}`);
  } else {
    // Responsive sizing: drop the fixed pixel width/height attributes and
    // let the SVG fill its container via CSS, using the viewBox to keep the
    // W×H coordinate system (and aspect ratio) intact. Previously the SVG
    // had a hardcoded width (600 by default), so on a narrower column
    // (e.g. a phone) it either overflowed past the container's edge or, on
    // a wider column, left a gap — both showing the page's own background
    // instead of the plot's, defeating dark themes.
    svg = d3.select(container).append("svg")
      .attr("viewBox", `0 0 ${W} ${H}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .style("width", "100%")
      .style("height", "auto")
      .style("display", "block");
  }

  // Always paint a background rect covering the full plot area (in viewBox
  // units, so it scales with the responsive SVG) rather than relying only
  // on the container div's CSS background — that keeps the theme's
  // background under the plot even where the SVG's rendered box doesn't
  // exactly match the container (e.g. letterboxing, or the inset's nested
  // <svg>, which already draws its own border rect before this runs).
  svg.insert("rect", ":first-child")
    .attr("class", "glyph-bg")
    .attr("width", W).attr("height", H)
    .attr("fill", theme.bg || "#fff");

  const plotArea = svg.append("g")
    .attr("class", "glyph-plot")
    .attr("transform", `translate(${basePad}, ${topPad})`);

  const innerW = W - basePad - rightPad;
  const innerH = H - topPad - basePad;
  const data = opts.data || spec.data?.values || [];

  // --- Build scales ---
  // Each mark may carry its own resolved `data` (row records) distinct from
  // the panel-level `data` above: the R side attaches this when a mapping is
  // a computed expression (e.g. x = log(wt)), whose generated column only
  // exists on that mark's data, or when rows were dropped for NA values in a
  // mapped position aesthetic. Fall back to the shared panel data otherwise.
  const scales = {};
  const forced = opts.forceDomain || {};
  // A quantitative position scale spans every mark's values, not just the
  // first mark's, so a later mark (an outlier, a histogram bin, a wider
  // second dataset) isn't drawn outside the axes.
  const extents = {
    x: unionExtents((spec.marks || []).map(m => markExtent(m, (m.data && m.data.values) || data, "x"))),
    y: unionExtents((spec.marks || []).map(m => markExtent(m, (m.data && m.data.values) || data, "y")))
  };
  for (const mark of (spec.marks || [])) {
    const enc = mark.encoding || {};
    const markData = (mark.data && mark.data.values) || data;

    if (enc.x?.field) {
      scales.x = scales.x || buildScale(enc.x, markData, [0, innerW], spec.scales?.x, forced.x, extents.x);
    }
    if (enc.y?.field) {
      scales.y = scales.y || buildScale(enc.y, markData, [innerH, 0], spec.scales?.y, forced.y, extents.y);
    }
    if (enc.x2?.field && !scales.x) {
      scales.x = buildScale(enc.x2, markData, [0, innerW], spec.scales?.x, forced.x);
    }
    if (enc.y2?.field && !scales.y) {
      scales.y = buildScale(enc.y2, markData, [innerH, 0], spec.scales?.y, forced.y);
    }
    // Ribbon marks map y_min/y_max instead of a plain y; build the y-scale
    // from the combined extent of both fields.
    if (!scales.y && enc.y_min?.field && enc.y_max?.field) {
      const domain = forced.y || [
        d3.min(markData, d => Math.min(+d[enc.y_min.field], +d[enc.y_max.field])),
        d3.max(markData, d => Math.max(+d[enc.y_min.field], +d[enc.y_max.field]))
      ];
      scales.y = buildScale(enc.y_max, markData, [innerH, 0], spec.scales?.y, domain);
    }
    if (enc.color?.field) {
      const unique = [...new Set(markData.map(d => d[enc.color.field]))];
      scales.color = d3.scaleOrdinal(d3.schemeTableau10).domain(unique);
    }
    if (enc.size?.field) {
      const ext = d3.extent(markData, d => +d[enc.size.field]);
      scales.size = d3.scaleLinear().domain(ext).range([3, 20]);
    }
  }

  // --- Draw grid ---
  if (theme.grid !== false) {
    drawGrid(plotArea, scales, innerW, innerH, theme);
  }

  // --- Draw axes ---
  drawAxes(plotArea, scales, innerW, innerH, theme, spec.scales);

  // --- Crossfilter plumbing ---
  let externalListener = null;
  const emitSelection = (idxSet) => { if (externalListener) externalListener(idxSet); };

  // What this plot reports as selected: a Set of the plot's rows, or null.
  const report = rows => setSlotRows(opts.selectionSlot, rows);

  // --- Draw marks ---
  const markRegistry = [];
  for (const mark of (spec.marks || [])) {
    const markData = (mark.data && mark.data.values) || data;
    const before = markRegistry.length;
    drawMark(plotArea, mark, markData, scales, innerW, innerH, theme, spec, markRegistry);
    for (let k = before; k < markRegistry.length; k++) markRegistry[k].mark = mark;
  }
  // wire up emitSelection into interactive marks (click select) drawn above
  markRegistry.forEach(entry => { entry.emitSelection = emitSelection; entry.report = report; });

  // --- Brush and zoom ---
  // One brush and one zoom per plot, covering every mark, so with several
  // brushable marks (points over boxplots, say) a drag still selects from
  // all of them; a brush per mark would leave only the last one reachable.
  // Brush and zoom share one drag state so a drag does only one of them.
  const interact = spec.interact || {};
  const dragState = createDragState(interact);
  if (interact.brush?.enabled) {
    const brushable = markRegistry.filter(e => e.brush);
    if (brushable.length) {
      addBrush(plotArea, brushable, innerW, innerH, dragState, emitSelection, report);
    }
  }
  if (interact.zoom?.enabled) {
    addZoom(svg.node(), plotArea, dragState);
  }

  // --- Legend (for selection(type = "legend")) ---
  const selections = spec.interact?.selections || {};
  const legendSel = Object.values(selections).find(s => s.type === "legend");
  if (legendSel && scales.color) {
    drawLegend(svg, scales.color, legendSel, markRegistry, W, basePad, theme, spec.scales?.color?.label, report);
  }

  // --- Draw titles ---
  if (theme.title) {
    svg.append("text")
      .attr("x", W / 2)
      .attr("y", 20)
      .attr("text-anchor", "middle")
      .attr("font-family", theme.font || "system-ui")
      .attr("font-size", (theme.font_size || 12) * (theme.title_size || 1.4))
      .attr("font-weight", 600)
      .attr("fill", theme.fg || "#333")
      .text(theme.title);
  }

  // --- Marginals ---
  if (marginal) {
    const fields = { x: getPanelField(spec, "x"), y: getPanelField(spec, "y") };
    drawMarginals(svg, scales, data, marginal, theme, fields, {
      basePad, topPad, rightPad, innerW, innerH, W, H
    });
  }

  // --- Inset ---
  if (spec.layout && spec.layout.type === "inset") {
    drawInset(svg, spec.layout, W, H);
  }

  // --- Apply entrance / keyframe animations ---
  if (spec.animate) {
    applyAnimation(plotArea, spec.animate, spec, scales, data, theme);
  }

  // A selection from a linked panel is a set of row indices. Each element is
  // highlighted when any of the rows it draws is selected: a point draws one
  // row, a box or histogram bin draws many (its `.rows`).
  function applyExternalSelection(idxSet) {
    markRegistry.forEach(entry => {
      entry.selection.attr("opacity", function(d, i) {
        if (!idxSet || idxSet.size === 0) return entry.baseOpacity;
        return rowsOfDatum(entry, d, i).some(r => idxSet.has(r))
          ? Math.max(entry.baseOpacity, 0.9) : Math.min(entry.baseOpacity, 0.15);
      });
    });
  }

  function onSelectionChange(fn) { externalListener = fn; }

  return { svg, plotArea, scales, data, markRegistry, applyExternalSelection, onSelectionChange, emitSelection };
}

// ---- Layout (compose) renderer -------------------------------------------------

function computePanelGrid(type, n, widths, heights) {
  if (type === "hstack") return { rows: 1, cols: n };
  if (type === "vstack") return { rows: n, cols: 1 };
  let cols = widths ? widths.length : Math.ceil(Math.sqrt(n));
  let rows = heights ? heights.length : Math.ceil(n / cols);
  if (cols * rows < n) cols = Math.ceil(n / rows);
  return { rows: Math.max(rows, 1), cols: Math.max(cols, 1) };
}

function getPanelField(panel, aesthetic) {
  for (const mark of (panel.marks || [])) {
    const f = mark.encoding?.[aesthetic]?.field;
    if (f) return f;
  }
  return null;
}

// Computes a shared domain (per aesthetic) across a set of compiled panel
// specs, for `shared_scales` (compose) / the inverse of `free_scales` (facet).
function computeSharedDomains(panels, sharedAxes) {
  if (!sharedAxes) return {};
  const wantX = sharedAxes === true || sharedAxes === "both" || sharedAxes === "x";
  const wantY = sharedAxes === true || sharedAxes === "both" || sharedAxes === "y";
  const out = {};

  // Every mark of every panel contributes, using the mark's own rows (which
  // carry computed columns and statistical summaries) when it has them.
  // A numeric domain set with set_scale() stands in for the panel's data.
  const panelExtent = (p, axis) => {
    const domain = p.scales?.[axis]?.domain;
    if (Array.isArray(domain) && domain.length === 2 && domain.every(Number.isFinite)) return domain;
    return unionExtents((p.marks || []).map(m =>
      markExtent(m, (m.data && m.data.values) || p.data?.values || [], axis)));
  };

  if (wantX) {
    const ext = unionExtents(panels.map(p => panelExtent(p, "x")));
    if (ext) out.x = ext;
  }
  if (wantY) {
    const ext = unionExtents(panels.map(p => panelExtent(p, "y")));
    if (ext) out.y = ext;
  }
  return out;
}

// The range of values a mark draws along a position axis, or null when it
// draws nothing numeric there (no mapping, or a categorical one). Statistical
// marks report the extent of what they draw (whiskers and outliers, bin
// edges, counts from zero) rather than of a raw data column.
function markExtent(mark, data, axis) {
  const enc = mark.encoding || {};
  const stat = mark.stat && mark.stat.type;
  const vals = [];

  if (stat === "polygon" && (axis === "x" || axis === "y")) {
    const key = axis === "x" ? ".x" : ".y";
    data.forEach(d => (d[key] || []).forEach(v => vals.push(v)));
  } else if (stat === "boxplot" && axis === "y") {
    data.forEach(d => {
      vals.push(d[".ymin"], d[".ymax"]);
      (d[".outliers"] || []).forEach(v => vals.push(v));
    });
  } else if (stat === "violin" && axis === "y") {
    data.forEach(d => vals.push(d[".ymin"], d[".ymax"]));
  } else if (stat === "histogram" && axis === "x") {
    const breaks = mark.stat.breaks || [];
    if (breaks.length) vals.push(breaks[0], breaks[breaks.length - 1]);
    data.forEach(d => vals.push(d[".x0"], d[".x1"]));
  } else if (stat === "histogram" && axis === "y") {
    vals.push(0);
    data.forEach(d => vals.push(d[".ymax"]));
  } else if (enc[axis]?.field && enc[axis].type !== "nominal" && enc[axis].type !== "ordinal") {
    const f = enc[axis].field;
    data.forEach(d => vals.push(d[f]));
    // Bars and areas are measured from zero, so their value axis includes it
    // (#29). A domain set with set_scale() is used instead of this extent.
    if (axis === "y" && (mark.type === "bar" || mark.type === "area")) vals.push(0);
  } else if (axis === "y" && enc.y_min?.field && enc.y_max?.field) {
    data.forEach(d => vals.push(d[enc.y_min.field], d[enc.y_max.field]));
  } else {
    return null;
  }

  const nums = vals.filter(v => v !== null && v !== undefined && v !== "" && isFinite(+v)).map(Number);
  if (nums.length === 0) return null;
  return d3.extent(nums);
}

function unionExtents(extents) {
  const valid = extents.filter(Boolean);
  if (valid.length === 0) return null;
  return [d3.min(valid, e => e[0]), d3.max(valid, e => e[1])];
}

// `slot` collects the panels' selections, one child slot per panel in order.
function renderLayout(container, layoutSpec, fallbackW, fallbackH, slot) {
  const panels = layoutSpec.panels || [];
  const n = panels.length;
  const gap = layoutSpec.gap ?? 10;
  const { rows, cols } = computePanelGrid(layoutSpec.layout_type, n, layoutSpec.widths, layoutSpec.heights);

  const totalW = fallbackW || (600 * cols);
  const totalH = fallbackH || (400 * rows);

  const wProps = (layoutSpec.widths && layoutSpec.widths.length === cols) ? layoutSpec.widths : new Array(cols).fill(1);
  const hProps = (layoutSpec.heights && layoutSpec.heights.length === rows) ? layoutSpec.heights : new Array(rows).fill(1);
  const wSum = wProps.reduce((a, b) => a + b, 0) || 1;
  const hSum = hProps.reduce((a, b) => a + b, 0) || 1;

  const colWidths = wProps.map(p => Math.max(20, (p / wSum) * (totalW - gap * (cols - 1))));
  const rowHeights = hProps.map(p => Math.max(20, (p / hSum) * (totalH - gap * (rows - 1))));

  const wrap = d3.select(container).append("div")
    .attr("class", "glyph-layout")
    .style("display", "grid")
    .style("grid-template-columns", colWidths.map(w => `${w}px`).join(" "))
    .style("grid-template-rows", rowHeights.map(h => `${h}px`).join(" "))
    .style("gap", `${gap}px`);

  if (layoutSpec.title) {
    d3.select(container).insert("div", ":first-child")
      .attr("class", "glyph-layout-title")
      .style("font-family", "system-ui")
      .style("font-weight", 600)
      .style("font-size", "14px")
      .style("margin-bottom", "6px")
      .text(layoutSpec.title);
  }

  const sharedAxes = layoutSpec.shared_scales === true ? "both" : (layoutSpec.shared_scales || null);
  const flatPanels = panels.map(p => (p.type === "layout" ? null : p)).filter(Boolean);
  const forceDomain = computeSharedDomains(flatPanels, sharedAxes);

  const panelResults = [];
  panels.forEach((panelSpec, i) => {
    const r = Math.floor(i / cols);
    const c = i % cols;
    const cell = wrap.append("div")
      .style("grid-column", c + 1)
      .style("grid-row", r + 1)
      .style("overflow", "hidden")
      .style("position", "relative");

    let result;
    if (panelSpec.type === "layout") {
      renderLayout(cell.node(), panelSpec, colWidths[c], rowHeights[r],
                   childSlot(slot, "layout", panelSpec.panel_names));
      result = null;
    } else {
      result = renderSpecInto(cell.node(), panelSpec, {
        width: colWidths[c],
        height: rowHeights[r],
        forceDomain: forceDomain,
        selectionSlot: childSlot(slot, "plot")
      });
    }
    panelResults.push(result);
  });

  const wantsCrossfilter = layoutSpec.linked_selections ||
    panels.some(p => p.interact?.crossfilter?.enabled);
  if (wantsCrossfilter) {
    wireCrossfilter(panelResults.filter(Boolean));
  }

  return { panels: panelResults };
}

function wireCrossfilter(panelResults) {
  panelResults.forEach((p, i) => {
    if (!p || !p.onSelectionChange) return;
    p.onSelectionChange(idxSet => {
      panelResults.forEach((other, j) => {
        if (j !== i && other && other.applyExternalSelection) {
          other.applyExternalSelection(idxSet);
        }
      });
    });
  });
}

// ---- Facet renderer -------------------------------------------------------------

function sharedAxesFromFree(free) {
  if (free === "both") return null;
  if (free === "x") return "y";
  if (free === "y") return "x";
  return "both"; // "none" (default)
}

// `slot` collects the panels' selections, one child slot per panel.
function renderFacets(container, spec, fallbackW, fallbackH, slot) {
  const facets = spec.facets;
  const data = spec.data?.values || [];
  const colsField = facets.cols;
  const rowsField = facets.rows;

  let cellSpecs = []; // { label, match, row, col }
  let rows, cols;

  // A field's values, one per panel, as [key, value] pairs. Dates are
  // compared and ordered by their time (valueKey()), and panels match rows by
  // the same key. Other values keep their string order.
  const panelValues = field => {
    const byKey = new Map();
    data.forEach(d => { const k = valueKey(d[field]); if (!byKey.has(k)) byKey.set(k, d[field]); });
    const keys = [...byKey.keys()];
    const dates = [...byKey.values()].some(v => v instanceof Date);
    return (dates ? keys.sort((a, b) => a - b) : keys.sort()).map(k => [k, byKey.get(k)]);
  };

  if (colsField && rowsField) {
    const colVals = panelValues(colsField);
    const rowVals = panelValues(rowsField);
    rowVals.forEach(([rk, rv], ri) => {
      colVals.forEach(([ck, cv], ci) => {
        cellSpecs.push({
          label: `${rowsField}=${formatValue(rv)}, ${colsField}=${formatValue(cv)}`,
          match: d => valueKey(d[rowsField]) === rk && valueKey(d[colsField]) === ck,
          row: ri, col: ci
        });
      });
    });
    rows = rowVals.length;
    cols = colVals.length;
  } else {
    const field = colsField || rowsField;
    const vals = panelValues(field);
    cols = facets.wrap || Math.ceil(Math.sqrt(vals.length));
    vals.forEach(([k, v], i) => {
      cellSpecs.push({
        label: `${field} = ${formatValue(v)}`,
        match: d => valueKey(d[field]) === k,
        row: Math.floor(i / cols), col: i % cols
      });
    });
    rows = Math.ceil(vals.length / cols);
  }

  const gap = 16;
  const cellW = Math.max(120, ((fallbackW || 600) - gap * (cols - 1)) / cols);
  const cellH = Math.max(100, ((fallbackH || 400) - gap * (rows - 1)) / rows);

  const wrap = d3.select(container).append("div")
    .attr("class", "glyph-facets")
    .style("display", "grid")
    .style("grid-template-columns", `repeat(${cols}, ${cellW}px)`)
    .style("grid-template-rows", `repeat(${rows}, auto)`)
    .style("gap", `${gap}px`);

  // Build a synthetic per-facet spec (same marks/scales/theme). Each mark
  // keeps its own resolved `data` — generated columns from computed
  // mappings, NA rows already dropped, a generated column for a computed
  // facet variable (see resolve_facets() on the R side) — but sliced down
  // to just the rows matching this facet cell, instead of being reset to
  // the shared top-level data. That keeps computed mappings and
  // NA-dropping working the same way inside facet() as in an unfaceted
  // plot; a mark with no data of its own still falls back to filtering the
  // shared panel-level data, same as before.
  const facetSpecs = cellSpecs.map(cs => Object.assign({}, spec, {
    data: { values: data.filter(cs.match) },
    facets: null,
    layout: null,
    marks: (spec.marks || []).map(m => {
      const markData = (m.data && m.data.values) || data;
      return Object.assign({}, m, { data: { values: markData.filter(cs.match) } });
    })
  }));

  const sharedAxes = sharedAxesFromFree(facets.free_scales);
  const forceDomain = computeSharedDomains(facetSpecs, sharedAxes);

  cellSpecs.forEach((cs, i) => {
    const cell = wrap.append("div")
      .style("grid-column", cs.col + 1)
      .style("grid-row", cs.row + 1);

    cell.append("div")
      .attr("class", "glyph-facet-label")
      .style("font-family", "system-ui")
      .style("font-size", "11px")
      .style("font-weight", 600)
      .style("color", (spec.theme && spec.theme.fg) || "#333")
      .style("margin-bottom", "2px")
      .text(cs.label);

    renderSpecInto(cell.node(), facetSpecs[i], {
      width: cellW,
      height: cellH - 18,
      forceDomain: forceDomain,
      selectionSlot: childSlot(slot, "plot")
    });
  });
}

// ---- Scale builder ----------------------------------------------------------

// `dataExtent`, when given, is the range of values every mark draws on this
// axis (see markExtent); it replaces the extent of `field` in `data` alone.
function buildScale(encoding, data, range, scaleOpts, forcedDomain, dataExtent) {
  const field = encoding.field;
  const type = encoding.type;
  const opts = scaleOpts || {};

  if (type === "quantitative") {
    let domain = forcedDomain || opts.domain || dataExtent || d3.extent(data, d => +d[field]);
    if (domain[0] === undefined || domain[1] === undefined || (domain[0] === domain[1] && !isFinite(domain[0]))) {
      domain = [0, 1];
    }
    if (domain[0] === domain[1]) domain = [domain[0] - 1, domain[1] + 1];
    if (opts.zero) domain = [Math.min(0, domain[0]), Math.max(0, domain[1])];

    if (opts.type === "log") {
      const base = opts.base || 10;
      const safeDomain = [Math.max(domain[0], 1e-6), Math.max(domain[1], 1e-6 + 1)];
      const s = d3.scaleLog().base(base).domain(safeDomain).range(range);
      return opts.nice !== false ? s.nice() : s;
    }
    if (opts.type === "sqrt") {
      return d3.scaleSqrt().domain(domain).range(range);
    }

    if (opts.nice !== false) {
      return d3.scaleLinear().domain(domain).range(range).nice();
    }
    return d3.scaleLinear().domain(domain).range(range);
  }

  if (type === "temporal") {
    // UTC, since dates and date-times arrive with their values in UTC fields
    // (see inflateSpec()). A domain may be dates or milliseconds.
    let domain = (forcedDomain || opts.domain || dataExtent || d3.extent(data, d => d[field])).map(v => +v);
    if (!(isFinite(domain[0]) && isFinite(domain[1]))) domain = [0, 864e5];
    if (domain[0] === domain[1]) domain = [domain[0] - 864e5, domain[1] + 864e5];
    const s = d3.scaleUtc().domain(domain).range(range);
    return opts.nice !== false ? s.nice() : s;
  }

  if (type === "nominal" || type === "ordinal") {
    // Statistical marks send their groups in display order (factor levels or
    // sorted values), so every facet panel shows the same categories.
    const domain = encoding.domain || [...new Set(data.map(d => d[field]))];
    return d3.scaleBand().domain(domain).range(range).padding(0.1);
  }

  // Fallback
  return d3.scaleLinear()
    .domain(forcedDomain || d3.extent(data, d => +d[field]))
    .range(range)
    .nice();
}

// ---- Grid -------------------------------------------------------------------

function drawGrid(g, scales, w, h, theme) {
  const gridColor = theme.grid_color || "#e5e5e5";
  const showX = theme.grid === true || theme.grid === "x";
  const showY = theme.grid === true || theme.grid === "y";

  if (showY && scales.y) {
    g.append("g")
      .attr("class", "grid-y")
      .selectAll("line")
      .data(scales.y.ticks ? scales.y.ticks(6) : [])
      .join("line")
      .attr("x1", 0).attr("x2", w)
      .attr("y1", d => scales.y(d))
      .attr("y2", d => scales.y(d))
      .attr("stroke", gridColor)
      .attr("stroke-width", 0.5);
  }

  if (showX && scales.x && scales.x.ticks) {
    g.append("g")
      .attr("class", "grid-x")
      .selectAll("line")
      .data(scales.x.ticks(6))
      .join("line")
      .attr("x1", d => scales.x(d))
      .attr("x2", d => scales.x(d))
      .attr("y1", 0).attr("y2", h)
      .attr("stroke", gridColor)
      .attr("stroke-width", 0.5);
  }
}

// ---- Axes -------------------------------------------------------------------

function drawAxes(g, scales, w, h, theme, scaleSpecs) {
  const font = theme.font || "system-ui";
  const fontSize = (theme.font_size || 12) * 0.85;
  const fg = theme.fg || "#333";

  if (scales.x) {
    // Groups on a band axis can be dates (a boxplot by date, say).
    const xAxis = scales.x.bandwidth
      ? d3.axisBottom(scales.x).tickFormat(formatValue)
      : d3.axisBottom(scales.x).ticks(6);

    const xG = g.append("g")
      .attr("class", "axis-x")
      .attr("transform", `translate(0, ${h})`)
      .call(xAxis);

    xG.selectAll("text")
      .attr("font-family", font)
      .attr("font-size", fontSize)
      .attr("fill", fg);

    // Axis label
    const xLabel = scaleSpecs?.x?.label;
    if (xLabel) {
      g.append("text")
        .attr("x", w / 2).attr("y", h + 35)
        .attr("text-anchor", "middle")
        .attr("font-family", font)
        .attr("font-size", fontSize)
        .attr("fill", fg)
        .text(xLabel);
    }
  }

  if (scales.y) {
    const yAxis = scales.y.bandwidth
      ? d3.axisLeft(scales.y).tickFormat(formatValue)
      : d3.axisLeft(scales.y).ticks(6);
    const yG = g.append("g")
      .attr("class", "axis-y")
      .call(yAxis);

    yG.selectAll("text")
      .attr("font-family", font)
      .attr("font-size", fontSize)
      .attr("fill", fg);

    const yLabel = scaleSpecs?.y?.label;
    if (yLabel) {
      g.append("text")
        .attr("transform", `rotate(-90)`)
        .attr("x", -h / 2).attr("y", -30)
        .attr("text-anchor", "middle")
        .attr("font-family", font)
        .attr("font-size", fontSize)
        .attr("fill", fg)
        .text(yLabel);
    }
  }
}

// ---- Mark rendering ---------------------------------------------------------

function drawMark(g, mark, data, scales, w, h, theme, spec, markRegistry) {
  const enc = mark.encoding || {};
  const style = mark.style || {};
  const interact = spec.interact || {};

  switch (mark.type) {
    case "point":
      drawPoints(g, data, enc, scales, style, w, h, interact, theme, markRegistry);
      break;
    case "bar":
      drawBars(g, data, enc, scales, style, w, h, interact, theme, markRegistry);
      break;
    case "line":
      drawLine(g, data, enc, scales, style, w, h, interact, theme);
      break;
    case "area":
      drawArea(g, data, enc, scales, style, h, interact, theme);
      break;
    case "rule":
      drawRule(g, enc, scales, style, w, h, theme);
      break;
    case "text":
      drawText(g, data, enc, scales, style, interact, theme);
      break;
    case "ribbon":
      drawRibbon(g, data, enc, scales, style, interact, theme);
      break;
    case "link":
      drawLink(g, data, enc, scales, style, interact, theme);
      break;
    case "sina":
      drawPoints(g, data, enc, scales, style, w, h, interact, theme, markRegistry, "marks-sina");
      break;
    case "boxplot":
      drawBoxplot(g, data, enc, scales, style, interact, theme, markRegistry);
      break;
    case "violin":
      drawViolin(g, data, enc, scales, style, interact, theme, markRegistry);
      break;
    case "histogram":
      drawHistogram(g, data, enc, scales, style, interact, theme, markRegistry);
      break;
    case "polygon":
      drawPolygon(g, data, enc, scales, style, interact, theme, markRegistry);
      break;
  }
}

// Each entry describes one mark's drawn elements for the selection
// machinery (brush, click, crossfilter, legend):
//   selection    the d3 selection whose opacity reflects a selection
//   baseOpacity  its normal opacity
//   rowsOf       optional (d, i) => row indices the element draws; by
//                default element i draws row i
//   brush        optional adapter for the plot's brush (see addBrush)
function registerMark(markRegistry, selection, baseOpacity, extra) {
  if (markRegistry) markRegistry.push(Object.assign({ selection, baseOpacity }, extra || {}));
}

function rowsOfDatum(entry, d, i) {
  return entry.rowsOf ? entry.rowsOf(d, i) : [i];
}

// The rows of the plot's data (0-based) an element draws, for the selection
// reported to Shiny: a row-level element's own row, or every row a box, bin
// or polygon summarises. A summary's `.rows` count only the rows its mark
// kept, so they go through the mark's `plot_rows` when rows were dropped
// for missing values. A mark with its own `data` draws rows of another data
// frame and contributes none.
function plotRowsOfDatum(entry, d, i) {
  const mark = entry.mark;
  if (!mark || mark.own_data) return [];
  if (entry.rowsOf) {
    const map = mark.plot_rows === undefined ? null : columnArray(mark.plot_rows);
    return entry.rowsOf(d, i).map(r => (map ? map[r] : r));
  }
  const row = d ? d[GLYPH_ROW] : undefined;
  return row === undefined ? [] : [row];
}

// Horizontal position of a row-level mark (points, sina). On a band
// (categorical) scale the point sits in its band: at the centre, or at the
// slot (`.xc`) and sideways offset (`.offset`, both fractions of the band)
// a sina mark computed. `slotWidth` stands in for the band width when x is a
// continuous scale.
function xPos(scales, enc, d, slotWidth) {
  if (!scales.x) return 0;
  const v = scales.x(getVal(d, enc.x));
  if (scales.x.bandwidth) {
    const bw = scales.x.bandwidth();
    return v + bw * (d[".xc"] ?? 0.5) + bw * (d[".offset"] ?? 0);
  }
  return v + (slotWidth || 0) * (((d[".xc"] ?? 0.5) - 0.5) + (d[".offset"] ?? 0));
}

function yPos(scales, enc, d) {
  return scales.y ? scales.y(getVal(d, enc.y)) : 0;
}

// Width available to one group of a statistical mark: the band width on a
// categorical x scale, or, on a continuous one (when another mark built the
// x scale from the same numeric column), 80% of the closest spacing between
// the group positions.
function groupSlotWidth(scales, enc, fallback) {
  if (!scales.x) return fallback;
  if (scales.x.bandwidth) return scales.x.bandwidth();
  const pos = (enc.x?.domain || []).map(v => scales.x(v)).filter(isFinite).sort((a, b) => a - b);
  let gap = Infinity;
  for (let i = 1; i < pos.length; i++) gap = Math.min(gap, pos[i] - pos[i - 1]);
  return isFinite(gap) && gap > 0 ? gap * 0.8 : fallback;
}

// Left edge of a group's slot and its width, in pixels, for statistical marks
// that draw one element per group (boxplot, violin).
function groupGeometry(scales, enc, d, slotWidth) {
  const v = scales.x ? scales.x(getVal(d, enc.x)) : 0;
  const start = scales.x && scales.x.bandwidth ? v : v - slotWidth / 2;
  const center = start + slotWidth * (d[".xc"] ?? 0.5);
  const half = slotWidth * (d[".xw"] ?? 0.8) / 2;
  return { center, half };
}

function drawPoints(g, data, enc, scales, style, w, h, interact, theme, markRegistry, cls) {
  const baseOpacity = style.opacity || 0.8;
  const slotWidth = groupSlotWidth(scales, enc, 40);
  const px = d => xPos(scales, enc, d, slotWidth);
  const py = d => yPos(scales, enc, d);
  const layer = g.append("g").attr("class", cls || "marks-point");
  const points = layer
    .selectAll("circle")
    .data(data)
    .join("circle")
    .attr("cx", px)
    .attr("cy", py)
    .attr("r", d => scales.size ? scales.size(getVal(d, enc.size)) : (style.size || 5))
    .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
    .attr("opacity", baseOpacity)
    .attr("stroke", "#fff")
    .attr("stroke-width", 1);

  // Keyframe animation rebinds the points' data (see applyMorphAnimation),
  // and reaches the finder through the layer to rebuild it.
  const finder = pointFinder(points, px, py);
  layer.node().__glyphFinder = finder;

  registerMark(markRegistry, points, baseOpacity, {
    // A point is hit by a brush when its centre is inside the brushed area.
    brush: {
      rowLevel: true,
      nearest: (mx, my, tolerance) => finder.nearest(mx, my, tolerance),
      hit: (d, i, node, [[x0, y0], [x1, y1]]) => {
        const cx = px(d), cy = py(d);
        return cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1;
      },
      opacity: hit => hit ? 1 : 0.1
    }
  });

  if (interact.tooltip?.enabled) {
    addTooltip(points, data, enc, interact.tooltip, theme);
  }
  if (interact.hover?.enabled) {
    addHoverEffect(points, interact.hover, style);
  }
  if (interact.click?.enabled) {
    addClickSelect(points, interact.click.action, baseOpacity, markRegistry);
  }
  const selections = Object.values(interact.selections || {});
  if (selections.some(s => s.type === "point")) {
    addClickSelect(points, "select", baseOpacity, markRegistry);
  }
}

function drawBars(g, data, enc, scales, style, w, h, interact, theme, markRegistry) {
  const bandwidth = scales.x?.bandwidth ? scales.x.bandwidth() : w / Math.max(data.length, 1) * 0.8;
  // Bars run from zero to their value, kept inside the plot when a domain
  // set with set_scale() leaves zero or the value outside it.
  const clampY = v => Math.max(0, Math.min(h, v));
  const base = scales.y ? clampY(scales.y(0)) : h;
  const end = d => clampY(scales.y(getVal(d, enc.y)));

  const bars = g.append("g").attr("class", "marks-bar")
    .selectAll("rect")
    .data(data)
    .join("rect")
    .attr("x", d => {
      const val = scales.x ? scales.x(getVal(d, enc.x)) : 0;
      return scales.x?.bandwidth ? val : val - bandwidth / 2;
    })
    .attr("y", d => scales.y ? Math.min(end(d), base) : 0)
    .attr("width", bandwidth)
    .attr("height", d => scales.y ? Math.abs(base - end(d)) : 0)
    .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
    .attr("rx", style.corner_radius || 0)
    // Below zero: the slide animation grows these downward (applyAnimation).
    .property("__glyphGrowsDown", d => !!scales.y && end(d) > base);

  registerMark(markRegistry, bars, 1);

  if (interact.tooltip?.enabled) addTooltip(bars, data, enc, interact.tooltip, theme);
  if (interact.hover?.enabled) addHoverEffect(bars, interact.hover, style);
  if (interact.click?.enabled) addClickSelect(bars, interact.click.action, 1, markRegistry);
}

function drawLine(g, data, enc, scales, style, w, h, interact, theme) {
  const line = d3.line()
    .x(d => scales.x(getVal(d, enc.x)))
    .y(d => scales.y(getVal(d, enc.y)));

  if (style.interpolate === "monotone") line.curve(d3.curveMonotoneX);
  else if (style.interpolate === "step") line.curve(d3.curveStep);
  else if (style.interpolate === "basis") line.curve(d3.curveBasis);

  // Group by color field if present
  const groups = enc.color?.field
    ? d3.groups(data, d => d[enc.color.field])
    : [[null, data]];

  for (const [key, values] of groups) {
    g.append("path")
      .datum(values)
      .attr("class", "marks-line")
      .attr("d", line)
      .attr("fill", "none")
      .attr("stroke", key && scales.color ? scales.color(key) : (theme.accent || "#4269d0"))
      .attr("stroke-width", style.stroke_width || 2);
  }

  // Add nearest-point interaction dot
  if (interact.nearest?.enabled || interact.tooltip?.enabled) {
    addNearestInteraction(g, data, enc, scales, interact, theme, w, h);
  }
}

function drawArea(g, data, enc, scales, style, h, interact, theme) {
  // Filled down to zero, or to the edge of the plot when a domain set with
  // set_scale() leaves zero outside it.
  const area = d3.area()
    .x(d => scales.x(getVal(d, enc.x)))
    .y0(Math.max(0, Math.min(h, scales.y(0))))
    .y1(d => scales.y(getVal(d, enc.y)));

  if (style.interpolate === "monotone") area.curve(d3.curveMonotoneX);

  g.append("path")
    .datum(data)
    .attr("class", "marks-area")
    .attr("d", area)
    .attr("fill", theme.accent || "#4269d0")
    .attr("opacity", style.opacity || 0.6);
}

function drawRule(g, enc, scales, style, w, h, theme) {
  const rg = g.append("g").attr("class", "marks-rule");

  if (style.y_intercept != null && scales.y) {
    rg.append("line")
      .attr("x1", 0).attr("x2", w)
      .attr("y1", scales.y(style.y_intercept))
      .attr("y2", scales.y(style.y_intercept))
      .attr("stroke", theme.fg || "#333")
      .attr("stroke-width", style.stroke_width || 1)
      .attr("stroke-dasharray", style.dash || "4 2");
  }
  if (style.x_intercept != null && scales.x) {
    rg.append("line")
      .attr("x1", scales.x(style.x_intercept))
      .attr("x2", scales.x(style.x_intercept))
      .attr("y1", 0).attr("y2", h)
      .attr("stroke", theme.fg || "#333")
      .attr("stroke-width", style.stroke_width || 1)
      .attr("stroke-dasharray", style.dash || "4 2");
  }
}

function drawText(g, data, enc, scales, style, interact, theme) {
  if (!enc.x?.field && !enc.y?.field) return;
  const labelEnc = enc.label || enc.text;
  const fontSize = style.font_size || 11;

  const group = g.append("g").attr("class", "marks-text");

  const texts = group.selectAll("text")
    .data(data)
    .join("text")
    .attr("x", d => scales.x ? scales.x(getVal(d, enc.x)) : 0)
    .attr("y", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
    .attr("font-family", theme.font || "system-ui")
    .attr("font-size", fontSize)
    .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.fg || "#333"))
    .attr("text-anchor", "middle")
    .attr("dy", -6)
    .text(d => labelEnc?.field ? formatValue(d[labelEnc.field]) : "");

  if (interact.tooltip?.enabled) addTooltip(texts, data, enc, interact.tooltip, theme);

  if (style.smart_repel) {
    resolveLabelCollisions(texts);
  }
}

// Simple pairwise collision resolver: nudges overlapping <text> labels apart
// vertically. Not as sophisticated as ggrepel, but genuinely de-overlaps.
function resolveLabelCollisions(textSelection) {
  const nodes = textSelection.nodes();
  if (nodes.length < 2) return;

  const boxes = nodes.map(n => {
    let bbox;
    try { bbox = n.getBBox(); } catch (e) { bbox = { width: 20, height: fontHeightFallback(n) }; }
    return { node: n, x: +n.getAttribute("x"), y: +n.getAttribute("y"), w: bbox.width || 20, h: bbox.height || 12 };
  });

  const padding = 2;
  for (let iter = 0; iter < 50; iter++) {
    let moved = false;
    for (let i = 0; i < boxes.length; i++) {
      for (let j = i + 1; j < boxes.length; j++) {
        const a = boxes[i], b = boxes[j];
        const dx = Math.abs(a.x - b.x);
        const dy = Math.abs(a.y - b.y);
        if (dx < (a.w + b.w) / 2 && dy < (a.h + b.h) / 2 + padding) {
          const dir = a.y <= b.y ? -1 : 1;
          a.y += dir * 1.5;
          b.y -= dir * 1.5;
          moved = true;
        }
      }
    }
    if (!moved) break;
  }

  boxes.forEach(b => d3.select(b.node).attr("y", b.y));
}

function fontHeightFallback(node) {
  const fs = node.getAttribute("font-size");
  return fs ? +fs * 1.2 : 13;
}

function drawRibbon(g, data, enc, scales, style, interact, theme) {
  if (!enc.x?.field || !enc.y_min?.field || !enc.y_max?.field) return;

  const area = d3.area()
    .x(d => scales.x(getVal(d, enc.x)))
    .y0(d => scales.y(getVal(d, enc.y_min)))
    .y1(d => scales.y(getVal(d, enc.y_max)));

  if (style.interpolate === "monotone") area.curve(d3.curveMonotoneX);

  const path = g.append("path")
    .datum(data)
    .attr("class", "marks-ribbon")
    .attr("d", area)
    .attr("fill", theme.accent || "#4269d0")
    .attr("opacity", style.opacity ?? 0.3);

  if (interact.tooltip?.enabled) addTooltip(path, data, enc, interact.tooltip, theme);
}

function drawLink(g, data, enc, scales, style, interact, theme) {
  if (!enc.x?.field || !enc.y?.field || !enc.x2?.field || !enc.y2?.field) return;

  const links = g.append("g").attr("class", "marks-link")
    .selectAll("line")
    .data(data)
    .join("line")
    .attr("x1", d => scales.x(getVal(d, enc.x)))
    .attr("y1", d => scales.y(getVal(d, enc.y)))
    .attr("x2", d => scales.x(getVal(d, enc.x2)))
    .attr("y2", d => scales.y(getVal(d, enc.y2)))
    .attr("stroke", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
    .attr("stroke-width", style.stroke_width || 1)
    .attr("opacity", style.opacity ?? 0.5);

  if (interact.tooltip?.enabled) addTooltip(links, data, enc, interact.tooltip, theme);
}

// ---- Statistical marks ------------------------------------------------------
//
// Boxplot, violin and histogram data arrive already summarised by the R side
// (R/stats.R): one record per box, violin or bin, with the statistics in
// dot-prefixed fields and `.rows` listing the row indices it summarises.
// These functions only draw. Sina marks are row-level and use drawPoints().

function statFill(scales, enc, theme) {
  return d => (scales.color && enc.color?.field) ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0");
}

function fmtNum(v) {
  return (typeof v === "number" && isFinite(v)) ? String(+v.toPrecision(4)) : v;
}

function axisLabel(encoding) {
  return encoding ? (encoding.label || encoding.field) : null;
}

// "x: 4" and "color: 1" lines naming the group a summary record belongs to.
function groupLines(d, enc) {
  const lines = [];
  for (const aes of ["x", "color"]) {
    const e = enc[aes];
    if (!e?.field) continue;
    if (aes === "color" && (e.field === enc.x?.field || (e.label && e.label === enc.x?.label))) continue;
    // A computed mapping (e.g. factor(cyl)) has a generated field name but
    // keeps its expression as the label. The single group of a boxplot with
    // no x mapping has neither, and needs no line.
    const name = e.label || (e.field.startsWith(".") ? null : e.field);
    if (name) lines.push(`${name}: ${formatValue(d[e.field])}`);
  }
  return lines;
}

// Brush adapter for elements that each stand for many rows: hit when the
// element's box overlaps the brushed area, found under the pointer by its box.
function summaryBrush(selection) {
  const bbox = node => node.getBBox();
  return {
    rowLevel: false,
    nearest: (mx, my) => {
      let found = null;
      selection.each(function() {
        const b = bbox(this);
        if (mx >= b.x && mx <= b.x + b.width && my >= b.y && my <= b.y + b.height) found = this;
      });
      return found;
    },
    hit: (d, i, node, [[x0, y0], [x1, y1]]) => {
      const b = bbox(node);
      return b.x <= x1 && b.x + b.width >= x0 && b.y <= y1 && b.y + b.height >= y0;
    },
    opacity: hit => hit ? 1 : 0.15
  };
}

// Hover emphasis for summary elements: a heavier outline (in the theme's
// foreground colour, for elements drawn without one, like histogram bins) and
// a stronger fill while the pointer is over the element. The `effect` names
// used for points ("enlarge", "brighten", "outline") all map to this, since
// there is no radius to enlarge.
function addStatHover(selection, targetSelector, theme) {
  const targets = node => targetSelector ? d3.select(node).selectAll(targetSelector) : d3.select(node);
  selection
    .on("mouseover.hover", function() {
      targets(this).each(function() {
        if (this.__glyphHover) return;
        const saved = this.__glyphHover = {
          stroke: this.getAttribute("stroke"),
          sw: this.getAttribute("stroke-width"),
          fo: this.getAttribute("fill-opacity")
        };
        const el = d3.select(this);
        if (saved.stroke === null || saved.stroke === "none") el.attr("stroke", theme.fg || "#333");
        el.attr("stroke-width", +(saved.sw || 0) + 1.5);
        if (saved.fo !== null) el.attr("fill-opacity", Math.min(1, +saved.fo + 0.2));
      });
    })
    .on("mouseout.hover", function() {
      targets(this).each(function() {
        const saved = this.__glyphHover;
        if (!saved) return;
        d3.select(this)
          .attr("stroke", saved.stroke)
          .attr("stroke-width", saved.sw)
          .attr("fill-opacity", saved.fo);
        this.__glyphHover = null;
      });
    });
}

// `brush` defaults to testing each element's bounding box (see summaryBrush).
function addStatInteractions(selection, data, enc, interact, theme, markRegistry, baseOpacity, autoText, hoverTarget, brush) {
  registerMark(markRegistry, selection, baseOpacity, {
    rowsOf: d => d[".rows"] || [],
    brush: brush || summaryBrush(selection)
  });
  if (interact.tooltip?.enabled) addTooltip(selection, data, enc, interact.tooltip, theme, autoText);
  if (interact.hover?.enabled) addStatHover(selection, hoverTarget, theme);
  if (interact.click?.enabled) addClickSelect(selection, interact.click.action, baseOpacity, markRegistry);
}

function drawBoxplot(g, data, enc, scales, style, interact, theme, markRegistry) {
  const fg = theme.fg || "#333";
  const fill = statFill(scales, enc, theme);
  const slotWidth = groupSlotWidth(scales, enc, 40);
  const sw = style.stroke_width || 1;
  const y = v => scales.y ? scales.y(v) : 0;

  const boxes = g.append("g").attr("class", "marks-boxplot")
    .selectAll("g")
    .data(data)
    .join("g")
    .attr("class", "glyph-box")
    .attr("opacity", 1);

  boxes.each(function(d) {
    const box = d3.select(this);
    const { center, half } = groupGeometry(scales, enc, d, slotWidth);
    box.append("line").attr("class", "glyph-whisker")
      .attr("x1", center).attr("x2", center)
      .attr("y1", y(d[".ymax"])).attr("y2", y(d[".upper"]))
      .attr("stroke", fg).attr("stroke-width", sw);
    box.append("line").attr("class", "glyph-whisker")
      .attr("x1", center).attr("x2", center)
      .attr("y1", y(d[".lower"])).attr("y2", y(d[".ymin"]))
      .attr("stroke", fg).attr("stroke-width", sw);
    box.append("rect").attr("class", "glyph-box-rect")
      .attr("x", center - half).attr("width", 2 * half)
      .attr("y", y(d[".upper"]))
      .attr("height", Math.max(0, y(d[".lower"]) - y(d[".upper"])))
      .attr("fill", fill(d)).attr("fill-opacity", style.opacity ?? 0.7)
      .attr("stroke", fg).attr("stroke-width", sw);
    box.append("line").attr("class", "glyph-median")
      .attr("x1", center - half).attr("x2", center + half)
      .attr("y1", y(d[".middle"])).attr("y2", y(d[".middle"]))
      .attr("stroke", fg).attr("stroke-width", sw * 2);
    box.selectAll("circle.glyph-outlier")
      .data(d[".outliers"] || [])
      .join("circle")
      .attr("class", "glyph-outlier")
      .attr("cx", center).attr("cy", v => y(v)).attr("r", 2.5)
      .attr("fill", fill(d)).attr("stroke", fg).attr("stroke-width", 0.75);
  });

  const autoText = d => [
    ...groupLines(d, enc),
    `n: ${d[".n"]}`,
    `upper whisker: ${fmtNum(d[".ymax"])}`,
    `Q3: ${fmtNum(d[".upper"])}`,
    `median: ${fmtNum(d[".middle"])}`,
    `Q1: ${fmtNum(d[".lower"])}`,
    `lower whisker: ${fmtNum(d[".ymin"])}`,
    ...((d[".outliers"] || []).length ? [`outliers: ${d[".outliers"].map(fmtNum).join(", ")}`] : [])
  ].join("\n");

  addStatInteractions(boxes, data, enc, interact, theme, markRegistry, 1, autoText, ".glyph-box-rect");
}

function drawViolin(g, data, enc, scales, style, interact, theme, markRegistry) {
  const fg = theme.fg || "#333";
  const fill = statFill(scales, enc, theme);
  const slotWidth = groupSlotWidth(scales, enc, 40);
  const baseOpacity = style.opacity ?? 0.6;

  const shape = d => {
    const { center, half } = groupGeometry(scales, enc, d, slotWidth);
    const ys = d[".dens_y"] || [];
    const ws = d[".dens_w"] || [];
    const pts = ys.map((yv, i) => [yv, ws[i]]);
    return d3.area()
      .y(p => scales.y(p[0]))
      .x0(p => center - half * p[1])
      .x1(p => center + half * p[1])
      .curve(d3.curveMonotoneY)(pts);
  };

  const violins = g.append("g").attr("class", "marks-violin")
    .selectAll("path")
    .data(data)
    .join("path")
    .attr("class", "glyph-violin")
    .attr("d", shape)
    .attr("fill", fill)
    .attr("fill-opacity", baseOpacity)
    .attr("stroke", fg)
    .attr("stroke-width", style.stroke_width || 1)
    .attr("opacity", 1);

  const autoText = d => [
    ...groupLines(d, enc),
    `n: ${d[".n"]}`,
    `median: ${fmtNum(d[".middle"])}`,
    `range: ${fmtNum(d[".ymin"])} to ${fmtNum(d[".ymax"])}`
  ].join("\n");

  addStatInteractions(violins, data, enc, interact, theme, markRegistry, 1, autoText, null);
}

function drawHistogram(g, data, enc, scales, style, interact, theme, markRegistry) {
  const fill = statFill(scales, enc, theme);
  const baseOpacity = style.opacity ?? 0.85;
  const x = v => scales.x ? scales.x(v) : 0;
  const y = v => scales.y ? scales.y(v) : 0;

  // Bars start half a pixel inside each bin edge and leave a 1px gap, so
  // neighbouring bins stay distinct without moving off their edges.
  const bars = g.append("g").attr("class", "marks-histogram")
    .selectAll("rect")
    .data(data)
    .join("rect")
    .attr("class", "glyph-bin")
    .attr("x", d => x(d[".x0"]) + 0.5)
    .attr("width", d => Math.max(0, x(d[".x1"]) - x(d[".x0"]) - 1))
    .attr("y", d => y(d[".ymax"]))
    .attr("height", d => Math.max(0, y(d[".ymin"]) - y(d[".ymax"])))
    .attr("fill", fill)
    .attr("opacity", baseOpacity);

  const label = axisLabel(enc.x);
  const lowest = d3.min(data, d => d[".x0"]);
  const autoText = d => [
    // Bins are closed on the right; the lowest bin also includes its left edge.
    `${label}: ${d[".x0"] === lowest ? "[" : "("}${fmtNum(d[".x0"])}, ${fmtNum(d[".x1"])}]`,
    ...groupLines(d, Object.assign({}, enc, { x: null })),
    `count: ${d[".count"]}`
  ].join("\n");

  addStatInteractions(bars, data, enc, interact, theme, markRegistry, baseOpacity, autoText, null);
}

// ---- Polygons -----------------------------------------------------------------
//
// The R side (stat_polygon() in R/stats.R) sends one record per polygon, with
// its vertices in row order in `.x`/`.y` and the rows it draws in `.rows`.

// SVG path through `pts` ([x, y] pixel pairs), closed back to the first point.
// With a radius, each corner is replaced by a quadratic curve that starts and
// ends `radius` pixels along its two edges (at most half of either edge), with
// the vertex as its control point.
function polygonPath(pts, radius) {
  const n = pts.length;
  if (n === 0) return "";
  const fmt = p => `${p[0]},${p[1]}`;
  if (!radius) return "M" + pts.map(fmt).join("L") + "Z";
  let d = "";
  for (let i = 0; i < n; i++) {
    const v = pts[i], prev = pts[(i + n - 1) % n], next = pts[(i + 1) % n];
    const lp = Math.hypot(prev[0] - v[0], prev[1] - v[1]);
    const ln = Math.hypot(next[0] - v[0], next[1] - v[1]);
    const r = Math.min(radius, lp / 2, ln / 2);
    const a = lp ? [v[0] + (prev[0] - v[0]) * r / lp, v[1] + (prev[1] - v[1]) * r / lp] : v;
    const b = ln ? [v[0] + (next[0] - v[0]) * r / ln, v[1] + (next[1] - v[1]) * r / ln] : v;
    d += (i === 0 ? "M" : "L") + fmt(a) + "Q" + fmt(v) + " " + fmt(b);
  }
  return d + "Z";
}

// Even-odd ray casting: whether (x, y) is inside the polygon `pts`.
function pointInPolygon(x, y, pts) {
  let inside = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}

function segmentsIntersect(p1, p2, p3, p4) {
  const cross = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
  const d1 = cross(p3, p4, p1), d2 = cross(p3, p4, p2);
  const d3 = cross(p1, p2, p3), d4 = cross(p1, p2, p4);
  return ((d1 > 0) !== (d2 > 0)) && ((d3 > 0) !== (d4 > 0));
}

// Whether the polygon `pts` overlaps the rectangle [[x0, y0], [x1, y1]]: a
// vertex inside the rectangle, a rectangle corner inside the polygon, or an
// edge crossing one of the rectangle's sides. Unlike a bounding-box test, a
// brush in the notch of a concave polygon doesn't select it.
function polygonIntersectsRect(pts, [[x0, y0], [x1, y1]]) {
  if (pts.some(([x, y]) => x >= x0 && x <= x1 && y >= y0 && y <= y1)) return true;
  const corners = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]];
  if (corners.some(([x, y]) => pointInPolygon(x, y, pts))) return true;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[i], b = pts[(i + 1) % pts.length];
    for (let k = 0; k < 4; k++) {
      if (segmentsIntersect(a, b, corners[k], corners[(k + 1) % 4])) return true;
    }
  }
  return false;
}

function drawPolygon(g, data, enc, scales, style, interact, theme, markRegistry) {
  const fg = theme.fg || "#333";
  const bandOffset = scales.x && scales.x.bandwidth ? scales.x.bandwidth() / 2 : 0;
  const px = v => (scales.x ? scales.x(v) : 0) + bandOffset;
  const py = v => scales.y ? scales.y(v) : 0;
  const ptsOf = d => (d[".x"] || []).map((xv, i) => [px(xv), py(d[".y"][i])]);
  const fill = d => (scales.color && enc.color?.field)
    ? scales.color(getVal(d, enc.color))
    : (style.fill || theme.accent || "#4269d0");
  const strokeWidth = style.stroke_width ?? 1;

  const shapes = g.append("g").attr("class", "marks-polygon")
    .selectAll("path")
    .data(data)
    .join("path")
    .attr("class", "glyph-polygon")
    .attr("d", d => polygonPath(ptsOf(d), style.radius || 0))
    .attr("fill", fill)
    .attr("fill-opacity", style.opacity ?? 0.7)
    .attr("stroke", strokeWidth > 0 ? (style.stroke || fg) : "none")
    .attr("stroke-width", strokeWidth)
    .attr("stroke-linejoin", "round")
    .attr("opacity", 1);

  // Brush and hover use the polygon's own shape, not its bounding box.
  const brush = {
    rowLevel: false,
    nearest: (mx, my) => {
      let found = null;
      shapes.each(function(d) { if (pointInPolygon(mx, my, ptsOf(d))) found = this; });
      return found;
    },
    hit: (d, i, node, rect) => polygonIntersectsRect(ptsOf(d), rect),
    opacity: hit => hit ? 1 : 0.15
  };

  const autoText = d => [
    ...groupLines(d, { x: enc.group, color: enc.color }),
    `vertices: ${d[".n"]}`
  ].join("\n");

  addStatInteractions(shapes, data, enc, interact, theme, markRegistry, 1, autoText, null, brush);
}

// ---- Marginals ----------------------------------------------------------------

function computeBins(values, nBins) {
  const bin = d3.bin().thresholds(nBins || 10);
  return bin(values);
}

function kde(values, bandwidth, ticks) {
  function epanechnikov(bw) {
    return v => Math.abs(v /= bw) <= 1 ? 0.75 * (1 - v * v) / bw : 0;
  }
  const k = epanechnikov(bandwidth);
  return ticks.map(t => [t, d3.mean(values, v => k(t - v)) || 0]);
}

function drawMarginals(svg, scales, data, marginal, theme, fields, geom) {
  const { basePad, topPad, rightPad, innerW, innerH, W, H } = geom;
  const accent = theme.accent || "#4269d0";

  if (marginal.x && scales.x) {
    const values = fields.x ? data.map(d => +d[fields.x]).filter(v => !isNaN(v)) : [];
    const stripH = topPad - basePad - 4;
    const g = svg.append("g")
      .attr("class", "marginal-x")
      .attr("transform", `translate(${basePad}, ${basePad})`);

    if (values.length > 0 && stripH > 4) {
      drawMarginalStrip(g, values, marginal.x, scales.x, "x", stripH, accent, theme);
    }
  }

  if (marginal.y && scales.y) {
    const values = fields.y ? data.map(d => +d[fields.y]).filter(v => !isNaN(v)) : [];
    const stripW = rightPad - basePad - 4;
    const g = svg.append("g")
      .attr("class", "marginal-y")
      .attr("transform", `translate(${basePad + innerW + 4}, ${topPad})`);

    if (values.length > 0 && stripW > 4) {
      drawMarginalStrip(g, values, marginal.y, scales.y, "y", stripW, accent, theme);
    }
  }
}

function drawMarginalStrip(g, values, kind, posScale, orientation, thickness, color, theme) {
  const magScale = d3.scaleLinear().range([thickness, 0]);

  if (kind === "histogram") {
    const bins = computeBins(values, 12);
    magScale.domain([0, d3.max(bins, b => b.length) || 1]);

    bins.forEach(b => {
      if (b.x0 === undefined) return;
      const x0 = posScale(b.x0), x1 = posScale(b.x1);
      if (orientation === "x") {
        g.append("rect")
          .attr("x", Math.min(x0, x1) + 1)
          .attr("width", Math.max(0, Math.abs(x1 - x0) - 2))
          .attr("y", magScale(b.length))
          .attr("height", thickness - magScale(b.length))
          .attr("fill", color)
          .attr("opacity", 0.6);
      } else {
        g.append("rect")
          .attr("y", Math.min(x0, x1) + 1)
          .attr("height", Math.max(0, Math.abs(x1 - x0) - 2))
          .attr("x", 0)
          .attr("width", thickness - magScale(b.length))
          .attr("fill", color)
          .attr("opacity", 0.6);
      }
    });
  } else if (kind === "density") {
    const domain = posScale.domain();
    const bandwidth = (domain[1] - domain[0]) / 20 || 1;
    const ticks = posScale.ticks ? posScale.ticks(40) : d3.range(domain[0], domain[1], (domain[1] - domain[0]) / 40);
    const density = kde(values, bandwidth, ticks);
    magScale.domain([0, d3.max(density, d => d[1]) || 1]);

    if (orientation === "x") {
      const line = d3.line().x(d => posScale(d[0])).y(d => magScale(d[1]));
      g.append("path").datum(density).attr("d", line)
        .attr("fill", "none").attr("stroke", color).attr("stroke-width", 1.5);
    } else {
      const line = d3.line().y(d => posScale(d[0])).x(d => magScale(d[1]));
      g.append("path").datum(density).attr("d", line)
        .attr("fill", "none").attr("stroke", color).attr("stroke-width", 1.5);
    }
  } else if (kind === "boxplot") {
    const sorted = values.slice().sort(d3.ascending);
    const q1 = d3.quantile(sorted, 0.25);
    const median = d3.quantile(sorted, 0.5);
    const q3 = d3.quantile(sorted, 0.75);
    const mid = thickness / 2;

    if (orientation === "x") {
      g.append("line").attr("x1", posScale(sorted[0])).attr("x2", posScale(sorted[sorted.length - 1]))
        .attr("y1", mid).attr("y2", mid).attr("stroke", theme.fg || "#333");
      g.append("rect").attr("x", posScale(q1)).attr("width", Math.max(1, posScale(q3) - posScale(q1)))
        .attr("y", mid - 6).attr("height", 12).attr("fill", color).attr("opacity", 0.5);
      g.append("line").attr("x1", posScale(median)).attr("x2", posScale(median))
        .attr("y1", mid - 6).attr("y2", mid + 6).attr("stroke", theme.fg || "#333");
    } else {
      g.append("line").attr("y1", posScale(sorted[0])).attr("y2", posScale(sorted[sorted.length - 1]))
        .attr("x1", mid).attr("x2", mid).attr("stroke", theme.fg || "#333");
      g.append("rect").attr("y", posScale(q3)).attr("height", Math.max(1, posScale(q1) - posScale(q3)))
        .attr("x", mid - 6).attr("width", 12).attr("fill", color).attr("opacity", 0.5);
      g.append("line").attr("y1", posScale(median)).attr("y2", posScale(median))
        .attr("x1", mid - 6).attr("x2", mid + 6).attr("stroke", theme.fg || "#333");
    }
  }
}

// ---- Inset ----------------------------------------------------------------------

function resolveInsetRect(position, W, H) {
  const pad = 12;
  const iw = W * 0.32, ih = H * 0.32;

  if (typeof position === "object" && position !== null) {
    return {
      x: (position.x ?? 0.65) * W,
      y: (position.y ?? 0.05) * H,
      w: (position.width ?? 0.3) * W,
      h: (position.height ?? 0.3) * H
    };
  }

  switch (position) {
    case "top-left": return { x: pad, y: pad, w: iw, h: ih };
    case "bottom-right": return { x: W - iw - pad, y: H - ih - pad, w: iw, h: ih };
    case "bottom-left": return { x: pad, y: H - ih - pad, w: iw, h: ih };
    case "top-right":
    default: return { x: W - iw - pad, y: pad, w: iw, h: ih };
  }
}

function drawInset(svg, layout, W, H) {
  const rect = resolveInsetRect(layout.position, W, H);
  const nested = svg.append("svg")
    .attr("class", "glyph-inset")
    .attr("x", rect.x).attr("y", rect.y)
    .attr("width", rect.w).attr("height", rect.h)
    .attr("viewBox", `0 0 ${rect.w} ${rect.h}`)
    .style("overflow", "visible");

  nested.append("rect")
    .attr("width", rect.w).attr("height", rect.h)
    .attr("fill", (layout.inset.theme && layout.inset.theme.bg) || "#fff")
    .attr("stroke", "#ccc").attr("stroke-width", 1);

  renderSpecInto(null, layout.inset, {
    targetSvg: nested,
    width: rect.w,
    height: rect.h
  });
}

// ---- Legend (selection type = "legend") ------------------------------------------

// Clicking an entry hides or shows its rows. The rows still shown are the
// plot's selection (`report`); with every entry shown there is none.
function drawLegend(svg, colorScale, legendSel, markRegistry, W, topPad, theme, label, report) {
  const domain = colorScale.domain();
  const fg = theme.fg || "#333";
  const font = theme.font || "system-ui";
  const itemH = 16;
  const titleH = label ? 14 : 0;

  const g = svg.append("g")
    .attr("class", "glyph-legend")
    .attr("transform", `translate(${W - 90}, ${Math.max(8, topPad - 30)})`);

  if (label) {
    g.append("text")
      .attr("class", "legend-title")
      .attr("x", 0).attr("y", 9)
      .attr("font-family", font)
      .attr("font-size", 10)
      .attr("font-weight", 600)
      .attr("fill", fg)
      .text(label);
  }

  const active = new Set(domain);

  const items = g.selectAll("g.legend-item")
    .data(domain)
    .join("g")
    .attr("class", "legend-item")
    .attr("transform", (d, i) => `translate(0, ${titleH + i * itemH})`)
    .style("cursor", "pointer");

  items.append("rect")
    .attr("width", 10).attr("height", 10)
    .attr("fill", d => colorScale(d));

  items.append("text")
    .attr("x", 14).attr("y", 9)
    .attr("font-family", font)
    .attr("font-size", 10)
    .attr("fill", fg)
    .text(d => formatValue(d));

  items.on("click", function(event, d) {
    if (active.has(d)) active.delete(d); else active.add(d);
    d3.select(this).style("opacity", active.has(d) ? 1 : 0.35);

    // Filter marks based on the underlying datum's mapped color field. We
    // don't have direct access to `enc` here, so `legendKeyForDatum` matches
    // by checking which of the datum's own field values is in the color
    // scale's domain.
    markRegistry.forEach(entry => {
      entry.selection.attr("opacity", function(datum) {
        const key = legendKeyForDatum(datum, colorScale);
        if (key === undefined) return entry.baseOpacity;
        return active.has(key) ? entry.baseOpacity : Math.min(entry.baseOpacity, 0.08);
      });
    });

    if (active.size === domain.length) {
      report(null);
      return;
    }
    const rows = new Set();
    markRegistry.forEach(entry => {
      entry.selection.each(function(datum, i) {
        const key = legendKeyForDatum(datum, colorScale);
        if (key !== undefined && active.has(key)) plotRowsOfDatum(entry, datum, i).forEach(r => rows.add(r));
      });
    });
    report(rows);
  });
}

function legendKeyForDatum(datum, colorScale) {
  // colorScale.domain() holds the raw field values used when the scale was
  // built; find which domain entry, when passed through the scale, would be
  // consistent with how this datum was colored. Since drawPoints/drawBars
  // call scales.color(getVal(d, enc.color)), the raw field value IS the key
  // — but we don't have `enc` here, so approximate via domain membership by
  // checking every field on the datum against the scale's domain.
  // The domain entry itself is returned, as the legend keys its entries by
  // them; dates are matched by their time (valueKey()).
  const domain = colorScale.domain();
  const keys = domain.map(valueKey);
  for (const key in datum) {
    const i = keys.indexOf(valueKey(datum[key]));
    if (i >= 0) return domain[i];
  }
  return undefined;
}

// ---- Helpers ----------------------------------------------------------------

// A value as text, for tooltips and labels. A date shows as 2024-03-10, and
// a date-time with its time of day, as R prints them.
const formatDay = d3.utcFormat("%Y-%m-%d");
const formatMinute = d3.utcFormat("%Y-%m-%d %H:%M");
const formatSecond = d3.utcFormat("%Y-%m-%d %H:%M:%S");
function formatValue(v) {
  if (!(v instanceof Date)) return v;
  if (isNaN(v)) return "NA";
  if (v.getUTCSeconds() || v.getUTCMilliseconds()) return formatSecond(v);
  if (v.getUTCHours() || v.getUTCMinutes()) return formatMinute(v);
  return formatDay(v);
}

// Dates are different objects for equal values, so sets and lookups compare
// them by their time.
function valueKey(v) {
  return v instanceof Date ? +v : v;
}

function getVal(d, encoding) {
  if (!encoding) return 0;
  if (encoding.field) return d[encoding.field];
  return 0;
}

// d3.pointer() reads clientX/clientY straight off the event it's given, but
// a raw TouchEvent has neither — only the individual Touch objects in its
// touches/changedTouches do — so it resolves to NaN coordinates (and throws
// setting a non-finite SVGPoint) when passed one directly. Pass it the
// underlying Touch object instead when given a TouchEvent.
function pointerXY(event, node) {
  const touch = (event.changedTouches && event.changedTouches[0]) || (event.touches && event.touches[0]);
  return d3.pointer(touch || event, node);
}

// Finds the point nearest (mx, my) — in the same plotArea-local coordinate
// space as scales.x/scales.y — within `tolerance` pixels. Used to forward
// pointer events that land on a brush's overlay (which sits on top of the
// marks so a drag can start anywhere) back to the mark underneath.
//
// The points go into a d3.quadtree, built on the first lookup, so a lookup
// only looks at the points near the pointer instead of all of them. Zooming
// transforms the whole plot group, so positions in its own coordinates don't
// change and the tree stays valid; a redraw builds a new finder, and
// invalidate() makes the next lookup rebuild it after the points' data
// changes (keyframe animation). When several points are equally near, the
// first in drawing order wins, as before.
function pointFinder(points, px, py) {
  let tree = null, nodes = null, xs = null, ys = null;

  function build() {
    nodes = points.nodes();
    xs = new Float64Array(nodes.length);
    ys = new Float64Array(nodes.length);
    nodes.forEach((node, i) => { xs[i] = px(node.__data__); ys[i] = py(node.__data__); });
    tree = d3.quadtree(d3.range(nodes.length), i => xs[i], i => ys[i]);
  }

  return {
    nearest(mx, my, tolerance) {
      if (!tree) build();
      let best = -1, bestDist = tolerance;
      tree.visit((node, x0, y0, x1, y1) => {
        // Skip quadrants farther away than the best point so far.
        const dx = Math.max(x0 - mx, 0, mx - x1), dy = Math.max(y0 - my, 0, my - y1);
        if (Math.hypot(dx, dy) > bestDist) return true;
        if (!node.length) {
          do {
            const i = node.data;
            const dist = Math.hypot(xs[i] - mx, ys[i] - my);
            if (dist < bestDist || (dist === bestDist && best >= 0 && i < best)) { best = i; bestDist = dist; }
          } while ((node = node.next));
        }
        return false;
      });
      return best >= 0 ? nodes[best] : null;
    },
    invalidate() { tree = null; }
  };
}

// Calls `update` with the latest of the values passed to schedule(), at most
// once per animation frame, so pointer moves that arrive faster than the page
// can respond replace each other instead of queueing up. cancel() drops a
// pending update.
function perFrame(update) {
  let pending = null, frame = null;
  return {
    schedule(value) {
      pending = value;
      if (frame === null) {
        frame = requestAnimationFrame(() => {
          frame = null;
          const v = pending;
          pending = null;
          update(v);
        });
      }
    },
    cancel() {
      if (frame !== null) cancelAnimationFrame(frame);
      frame = null;
      pending = null;
    }
  };
}

// ---- Drag mode (zoom vs brush) ----------------------------------------------
//
// Zoom binds its drag to the <svg>; brush binds its drag to an overlay rect
// *inside* that <svg>. A mousedown on the overlay therefore reaches both, so
// with zoom and brush on the same mark a single drag used to pan and brush at
// once. Both behaviors now consult this shared per-plot state through their
// d3 `.filter()`, so a drag only ever does one of the two. Wheel, trackpad
// pinch and two-finger pinch always zoom regardless of the mode.
function createDragState(interact) {
  const brushEnabled = !!(interact && interact.brush && interact.brush.enabled);
  const zoomEnabled = !!(interact && interact.zoom && interact.zoom.enabled);
  return {
    brushEnabled,
    zoomEnabled,
    // Brushing is the default whenever it's available: it's the mode that
    // can't be reached any other way (wheel/pinch/double-tap all zoom).
    mode: brushEnabled ? "brush" : "pan",
    listeners: []
  };
}

function setDragMode(dragState, mode) {
  if (!dragState || dragState.mode === mode) return;
  dragState.mode = mode;
  dragState.listeners.forEach(fn => fn(mode));
}

function dragModeOf(dragState, fallback) {
  return dragState ? dragState.mode : fallback;
}

// ---- Tooltip ----------------------------------------------------------------

let glyphListenerCounter = 0;
const glyphDocumentListeners = [];

// Adds a listener on document for the event `types` on behalf of `node`,
// part of a plot. A redraw replaces the plot without telling anything, so
// first drop the listeners whose element has left the page; otherwise each
// redraw adds another listener that keeps the replaced plot in memory.
function onDocument(node, types, listener, options) {
  for (let i = glyphDocumentListeners.length - 1; i >= 0; i--) {
    const l = glyphDocumentListeners[i];
    if (!l.node.isConnected) {
      d3.select(document).on(l.typenames, null);
      glyphDocumentListeners.splice(i, 1);
    }
  }
  const ns = "glyph-" + (glyphListenerCounter++);
  const typenames = types.split(" ").map(t => `${t}.${ns}`).join(" ");
  d3.select(document).on(typenames, listener, options);
  glyphDocumentListeners.push({ node, typenames });
}

function onDocumentTap(node, listener) {
  onDocument(node, "click touchend", listener);
}

// The widget's tooltip: one per widget, shared by its marks and kept across
// redraws. Every resize redraws the whole plot (and fitting it to its
// container can take up to three draws), and each draw used to add another
// tooltip to the page, with a document-level listener holding on to the
// marks it replaced.
function widgetTooltip(selection) {
  const node = selection.node();
  const host = (node && node.closest && node.closest(".html-widget")) || document.body;
  let tip = host.__glyphTooltip;
  // A redraw removes the element the tooltip was showing for, so hide it.
  if (tip && tip.node().isConnected) return tip.style("opacity", 0);

  // Fixed to the window, above everything, from <body>. Inside a card it
  // would be clipped by the card's overflow, and from <body> with a lower
  // z-index it is drawn under any card that is its own layer: a Quarto
  // dashboard's card bodies (z-index 4, #43) and a bslib card in full-screen
  // mode (1070).
  tip = host.__glyphTooltip = d3.select("body").append("div")
    .attr("class", "glyph-tooltip")
    .style("position", "fixed")
    .style("left", "0px")
    .style("top", "0px")
    .style("z-index", 2147483647)
    .style("padding", "6px 10px")
    .style("border-radius", "4px")
    .style("font-size", "11px")
    .style("box-shadow", "0 2px 8px rgba(0,0,0,0.15)")
    .style("pointer-events", "none")
    // Its own compositing layer, so moving it doesn't make the browser
    // repaint the plot underneath. In WebKit that repaint takes longer the
    // more points there are: about half a second per move at 15,000 points.
    .style("will-change", "transform")
    .style("opacity", 0);

  // Dismiss on tapping/clicking anywhere except an element with a tooltip
  // (whose own handler shows it; see addTooltip).
  onDocumentTap(tip.node(), function(event) {
    if (event.target && event.target.__glyphTooltip) return;
    tip.style("opacity", 0);
  });
  // It stays put while the page or a card scrolls, so it would no longer be
  // next to its mark.
  onDocument(tip.node(), "scroll", () => tip.style("opacity", 0), { capture: true, passive: true });
  return tip;
}

// Shows `tip` with `html` next to the pointer at (clientX, clientY): to its
// right and a little above, or to its left or above it where that would
// leave the window.
function placeTooltip(tip, html, clientX, clientY) {
  const node = tip.node();
  // An element shown with the browser's Fullscreen API is the only thing
  // drawn, so the tooltip has to be inside it.
  const layer = document.fullscreenElement || document.body;
  if (node.parentNode !== layer) layer.appendChild(node);
  if (node.__html !== html) {
    tip.html(html);
    node.__html = html;
  }
  const gap = 12, margin = 4;
  const w = node.offsetWidth, h = node.offsetHeight;
  const W = document.documentElement.clientWidth, H = document.documentElement.clientHeight;
  let x = clientX + gap, y = clientY - gap;
  if (x + w > W - margin) x = clientX - gap - w;
  if (y + h > H - margin) y = clientY - gap - h;
  x = Math.max(margin, Math.min(x, W - margin - w));
  y = Math.max(margin, Math.min(y, H - margin - h));
  tip.style("opacity", 1)
    .style("transform", `translate(${Math.round(x)}px, ${Math.round(y)}px)`);
}

// `autoText`, when given, writes the text of an automatic (`tooltip = TRUE`)
// tooltip; statistical marks use it to show their summary statistics.
function addTooltip(selection, data, enc, tooltipConfig, theme, autoText) {
  const tooltip = widgetTooltip(selection);
  selection.each(function() { this.__glyphTooltip = true; });
  // Marks in one widget can have different themes (compose(), inset()), so
  // each sets its own colours when it shows the tooltip.
  const dark = theme.fg === "#e0e0e0";
  const colours = t => t
    .style("background", dark ? "#333" : "#fff")
    .style("color", dark ? "#fff" : "#333")
    .style("font-family", theme.font || "system-ui");
  function renderText(d) {
    let text = "";
    if (tooltipConfig.template === "auto" && autoText) {
      text = autoText(d);
    } else if (tooltipConfig.template === "auto") {
      // Auto-generate from encodings. A computed mapping's generated field
      // name (".g_point_1_x") means nothing to a reader, so show its
      // expression (the label) instead.
      for (const [key, val] of Object.entries(enc)) {
        if (val?.field) text += `${val.label || val.field}: ${formatValue(d[val.field])}\n`;
      }
    } else {
      // Template string. Field names may contain dots, so a template can
      // also show a statistical mark's values, e.g. "{.median}".
      text = tooltipConfig.template.replace(/\{([\w.]+)\}/g, (_, k) => (d[k] ?? null) === null ? k : formatValue(d[k]));
    }
    return text.trim().replace(/\n/g, "<br>");
  }

  function showAt(clientX, clientY, d) {
    placeTooltip(tooltip.call(colours), renderText(d), clientX, clientY);
  }

  function hide() {
    tooltip.style("opacity", 0);
  }

  selection
    .on("mouseover", function(event, d) { showAt(event.clientX, event.clientY, d); })
    .on("mousemove", function(event, d) { showAt(event.clientX, event.clientY, d); })
    .on("mouseout", hide)
    // Touch devices have no hover state, so show the tooltip on tap and
    // dismiss it on the next tap elsewhere (see widgetTooltip) instead.
    // Namespaced so this doesn't clobber a bare "click" handler from
    // addClickSelect() when both tooltip and click interactions are enabled
    // on the same mark. touchend's preventDefault suppresses the browser's follow-up
    // synthetic "click" so the tap isn't handled twice.
    .on("click.tooltip touchend.tooltip", function(event, d) {
      event.stopPropagation();
      if (event.type === "touchend") event.preventDefault();
      const point = event.changedTouches ? event.changedTouches[0] : event;
      showAt(point.clientX, point.clientY, d);
    });
}

// ---- Hover effects ----------------------------------------------------------

function addHoverEffect(selection, hoverConfig, style) {
  const effect = hoverConfig.effect;

  selection
    .on("mouseover.hover", function() {
      const el = d3.select(this);
      if (effect === "enlarge") el.transition().duration(150).attr("r", (style.size || 5) * 1.8);
      if (effect === "brighten") el.transition().duration(150).attr("opacity", 1);
      if (effect === "outline") el.attr("stroke", "#000").attr("stroke-width", 2);
    })
    .on("mouseout.hover", function() {
      const el = d3.select(this);
      if (effect === "enlarge") el.transition().duration(150).attr("r", style.size || 5);
      if (effect === "brighten") el.transition().duration(150).attr("opacity", style.opacity || 0.8);
      if (effect === "outline") el.attr("stroke", "#fff").attr("stroke-width", 1);
    });
}

// ---- Click selection / filter ------------------------------------------------

function addClickSelect(selection, action, baseOpacity, markRegistry) {
  let selectedIdx = null; // null = nothing filtered/selected

  selection.on("click", function(event, d) {
    const i = selection.nodes().indexOf(this);

    if (selectedIdx !== null && selectedIdx.has(i) && selectedIdx.size === 1) {
      // clicking the only-selected mark again resets
      selectedIdx = null;
    } else {
      selectedIdx = new Set([i]);
    }

    selection.attr("opacity", function(d2, i2) {
      if (!selectedIdx) return baseOpacity;
      if (action === "filter") {
        return selectedIdx.has(i2) ? baseOpacity : 0.05;
      }
      // "select" (default): highlight selected, dim the rest
      return selectedIdx.has(i2) ? Math.max(baseOpacity, 0.95) : Math.min(baseOpacity, 0.25);
    });

    // Linked panels work in rows, and a box or bin draws many rows.
    const entry = (markRegistry || []).find(e => e.selection === selection);
    if (entry && entry.emitSelection) {
      const rows = new Set();
      if (selectedIdx) {
        const nodes = selection.nodes();
        selectedIdx.forEach(j => rowsOfDatum(entry, nodes[j].__data__, j).forEach(r => rows.add(r)));
      }
      entry.emitSelection(rows);
    }
    if (entry && entry.report) {
      let plotRows = null;
      if (selectedIdx) {
        const nodes = selection.nodes();
        plotRows = new Set();
        selectedIdx.forEach(j => plotRowsOfDatum(entry, nodes[j].__data__, j).forEach(r => plotRows.add(r)));
      }
      entry.report(plotRows);
    }
  });
}

// ---- Brush ------------------------------------------------------------------

// Escape clears every brush selection on the page, except while typing in a
// text field. One listener for the page; brushes whose plot has been
// redrawn away are dropped.
const glyphBrushes = [];
let glyphEscapeListening = false;
function registerBrushForEscape(node, clear) {
  for (let i = glyphBrushes.length - 1; i >= 0; i--) {
    if (!glyphBrushes[i].node.isConnected) glyphBrushes.splice(i, 1);
  }
  glyphBrushes.push({ node, clear });
  if (glyphEscapeListening) return;
  glyphEscapeListening = true;
  document.addEventListener("keydown", function(event) {
    if (event.key !== "Escape" || event.defaultPrevented) return;
    const t = event.target;
    if (t && (t.isContentEditable || /^(input|textarea|select)$/i.test(t.tagName))) return;
    glyphBrushes.forEach(b => {
      if (b.node.isConnected && d3.brushSelection(b.node)) b.clear();
    });
  });
}

// `entries` are the registered marks that can be brushed (see registerMark):
// each has a `brush` adapter with
//   rowLevel  true when each element draws one row (points, sina)
//   nearest   (mx, my, tolerance) => the element under the pointer, or null
//   hit       (d, i, node, [[x0, y0], [x1, y1]]) => whether the brushed area
//             takes in the element
//   opacity   (selected) => the element's opacity while a brush is active
// When the plot has row-level marks, only they are hit-tested: brushing a few
// points over a boxplot selects those points' rows, not every row of each
// box underneath. Every brushable element is then highlighted when it draws
// any selected row, so the boxes containing the brushed points light up too.
// With only summary marks (boxes, violins, bins), the summary elements
// themselves are hit-tested and select all the rows they draw.
// Linked panels follow the brush as it moves (`emitSelection`); the plot's
// rows are reported (`report`) once, when the brush ends or is cleared.
function addBrush(g, entries, w, h, dragState, emitSelection, report) {
  const rowLevel = entries.filter(e => e.brush.rowLevel);
  const hitTested = rowLevel.length ? rowLevel : entries;

  // The element under the pointer, preferring row-level marks (a point over
  // a box) and, within each kind, the mark drawn last (topmost).
  function nearestElement(mx, my) {
    const order = [...rowLevel].reverse().concat(entries.filter(e => !e.brush.rowLevel).reverse());
    for (const entry of order) {
      const node = entry.brush.nearest(mx, my, 12);
      if (node) return node;
    }
    return null;
  }

  function clearSelection() {
    entries.forEach(entry => entry.selection.attr("opacity", entry.baseOpacity));
    emitSelection(new Set());
    report(null);
  }

  // Forwards a tap/click that landed on the brush overlay to the element
  // underneath it, so tooltips and click-select still respond. Called from
  // two places: the brush's own "end" (a no-drag tap in brush mode) and a
  // plain click listener (pan mode, where no brush gesture runs at all).
  function forwardTapToPoint(event, node) {
    const [mx, my] = pointerXY(event, g.node());
    const nearest = nearestElement(mx, my);
    if (!nearest) return false;
    nearest.dispatchEvent(new MouseEvent("click", { bubbles: true, cancelable: true }));
    return true;
  }

  const brush = d3.brush()
    .extent([[0, 0], [w, h]])
    // Only begin a brush when the drag is meant to brush. Without this the
    // same mousedown also starts a zoom pan (see createDragState). Two
    // fingers is always a pinch-zoom, never a brush.
    .filter(function(event) {
      const mode = dragModeOf(dragState, "brush");
      if (event.touches) return event.touches.length < 2 && mode === "brush";
      return !event.button && !event.ctrlKey && mode === "brush";
    })
    .on("brush end", function(event) {
      const selection = event.selection;
      showClearButton(!!selection);
      if (!selection) {
        clearSelection();

        // The brush's overlay covers the whole plot and sits on top of the
        // points (so a drag can start from anywhere), which also means it
        // swallows a plain tap/click that lands on a point before that
        // point's own tooltip/click listeners ever see it. d3.brush treats
        // a no-drag tap the same as a clear (selection null, same as
        // above) — forward it to the nearest point, if it landed close
        // enough to one, so tap-to-show-tooltip and click-select still
        // work with brushing enabled.
        if (event.sourceEvent) {
          const [mx, my] = pointerXY(event.sourceEvent, g.node());
          if (nearestElement(mx, my)) {
            // Without this, the browser's own touch-to-click synthesis
            // still fires shortly after, targeting the overlay (since it's
            // still what's topmost at that screen position); that bubbles
            // to document and immediately dismisses the tooltip we just
            // forwarded a click to via the "tap outside" listeners above.
            if (event.sourceEvent.cancelable) event.sourceEvent.preventDefault();
            forwardTapToPoint(event.sourceEvent, this);
          }
        }
        return;
      }
      const idxSet = new Set();
      const plotRows = new Set();
      hitTested.forEach(entry => {
        entry.selection.each(function(d, i) {
          if (entry.brush.hit(d, i, this, selection)) {
            rowsOfDatum(entry, d, i).forEach(r => idxSet.add(r));
            plotRowsOfDatum(entry, d, i).forEach(r => plotRows.add(r));
          }
        });
      });
      entries.forEach(entry => {
        entry.selection.attr("opacity", (d, i) =>
          entry.brush.opacity(rowsOfDatum(entry, d, i).some(r => idxSet.has(r))));
      });
      emitSelection(idxSet);
      if (event.type === "end") report(plotRows);
    });

  const brushG = g.append("g").attr("class", "brush").call(brush);

  // "Clear selection" in the plot's controls bar, shown only while there is a
  // selection. Clearing goes through the brush, so it restores every mark
  // and tells linked panels, as a click inside the plot does.
  const clearBrush = () => brush.move(brushG, null);
  let clearButton = null;
  function showClearButton(visible) {
    if (!clearButton) {
      if (!visible) return;
      const svg = g.node().ownerSVGElement;
      const host = svg && svg.parentNode;
      if (!(host instanceof HTMLElement)) return;
      const bar = controlsBar(host);
      clearButton = controlButton("glyph-clear-selection");
      clearButton.addEventListener("click", clearBrush);
      bar.insertBefore(clearButton, bar.querySelector(".glyph-zoom-reset"));
      setControlLabel(clearButton, "✕ Clear selection", "Clear the selection (Esc)");
    } else if ((clearButton.style.display !== "none") === visible) {
      return;
    }
    clearButton.style.display = visible ? "" : "none";
    fitControls(clearButton.parentNode);
  }
  registerBrushForEscape(brushG.node(), clearBrush);

  // In pan mode the brush filter rejects the gesture outright, so no "end"
  // ever fires and the tap-forwarding above never runs — but the overlay is
  // still on top of the marks and still swallows the tap. Forward it here
  // instead. stopPropagation keeps the original overlay-targeted event from
  // reaching the tooltip's document-level dismiss listener, which would
  // otherwise hide the tooltip we just opened.
  //
  // Touch needs its own path rather than riding on the click the browser
  // synthesizes from a tap: d3-zoom (unlike d3-brush) doesn't preventDefault
  // on touch, so the browser also emits a compatibility mouse sequence whose
  // trailing mouseout would immediately hide the tooltip again. Handling
  // touchend directly and preventing the default suppresses that sequence —
  // and with it the synthetic click, so the two paths can't both fire.
  let touchStartXY = null;
  let lastTouchAt = 0;
  brushG
    .on("touchstart.glyph-tap-forward", function(event) {
      lastTouchAt = Date.now();
      const t = (event.touches && event.touches.length === 1) ? event.touches[0] : null;
      touchStartXY = t ? [t.clientX, t.clientY] : null;
    })
    .on("touchend.glyph-tap-forward", function(event) {
      lastTouchAt = Date.now();
      if (dragModeOf(dragState, "brush") !== "pan") return;
      if (event.touches && event.touches.length) return;

      const t = event.changedTouches && event.changedTouches[0];
      const start = touchStartXY;
      touchStartXY = null;
      // Only a tap, not the end of a pan drag.
      if (!t || !start || Math.hypot(t.clientX - start[0], t.clientY - start[1]) > 10) return;

      if (forwardTapToPoint(event, this)) {
        if (event.cancelable) event.preventDefault();
        event.stopPropagation();
      }
    })
    .on("click.glyph-tap-forward", function(event) {
      if (dragModeOf(dragState, "brush") !== "pan") return;
      if (forwardTapToPoint(event, this)) event.stopPropagation();
    });

  // Mode-dependent cursor, so which thing a drag will do is visible before
  // the user commits to the gesture.
  if (dragState && dragState.zoomEnabled) {
    const overlay = brushG.select(".overlay");
    const syncCursor = (mode) => overlay.style("cursor", mode === "brush" ? "crosshair" : "grab");
    dragState.listeners.push(syncCursor);
    syncCursor(dragState.mode);
  }

  // The overlay swallows continuous mouse hover the same way it swallows a
  // tap (see above) — but hover has no discrete "end" event to hook into,
  // so forward mousemove/mouseleave directly instead. This only reads
  // event.buttons to skip forwarding while a button is held (an in-progress
  // or just-starting brush drag) — it never calls preventDefault or
  // stopPropagation, so brushing itself still starts from anywhere in the
  // plot, including on top of a point.
  //
  // Bound on the brush's whole <g> (which mousemove/mouseleave still reach
  // via normal DOM bubbling), not just its .overlay rect: once a selection
  // exists, d3.brush draws a `.selection` rect (and resize handles) *on
  // top of* the overlay, so a listener on .overlay alone would stop
  // getting hover events over the selected region, and using "mouseleave"
  // on just .overlay would misfire every time the pointer crossed from the
  // overlay onto one of those sibling elements.
  let hoveredNode = null;
  // A tap also produces a compatibility mouse sequence on most touch
  // browsers, ending in a mouseout that would hide the tooltip the tap just
  // opened. Ignore mouse hover for a moment after any touch.
  const isSyntheticFromTouch = () => Date.now() - lastTouchAt < 600;
  // Only the latest pointer position is handled, once per frame (see
  // perFrame): in a dense area every move reaches a different point and
  // moves its tooltip, and handling each move in turn fell behind the
  // pointer.
  const hover = perFrame(({ clientX, clientY }) => {
    const [mx, my] = d3.pointer({ clientX, clientY }, g.node());
    const nearest = nearestElement(mx, my);
    if (nearest !== hoveredNode) {
      if (hoveredNode) hoveredNode.dispatchEvent(new MouseEvent("mouseout", { bubbles: true }));
      hoveredNode = nearest;
      if (hoveredNode) {
        hoveredNode.dispatchEvent(new MouseEvent("mouseover", { bubbles: true, clientX, clientY }));
      }
    }
    if (hoveredNode) {
      hoveredNode.dispatchEvent(new MouseEvent("mousemove", { bubbles: true, clientX, clientY }));
    }
  });
  brushG
    .on("mousemove.glyph-hover-forward", function(event) {
      if (event.buttons || isSyntheticFromTouch()) return;
      hover.schedule({ clientX: event.clientX, clientY: event.clientY });
    })
    .on("mouseleave.glyph-hover-forward", function() {
      if (isSyntheticFromTouch()) return;
      hover.cancel();
      if (hoveredNode) {
        hoveredNode.dispatchEvent(new MouseEvent("mouseout", { bubbles: true }));
        hoveredNode = null;
      }
    });

  // d3.brush() already clears itself on a no-drag tap/click *inside* its own
  // overlay (the plot area) — but a tap anywhere else on the page (outside
  // the widget entirely) previously did nothing. Clear it there too, so a
  // touch user has an obvious way to dismiss a brush without having to land
  // precisely back inside the plot.
  onDocumentTap(brushG.node(), function(event) {
    const target = event.target;
    // Inside the brush's own group (overlay, selection rect, resize
    // handles) d3.brush already decides what a tap means — including
    // clearing on a no-drag tap — so don't double-handle those.
    if (brushG.node().contains(target)) return;
    // The plot's own controls (drag-mode toggle, reset zoom) sit next to
    // the <svg> rather than inside it, so they'd otherwise read as "tapped
    // away from the plot" and throw away the selection the user is
    // switching modes or resetting the view to look at.
    if (target && target.closest && target.closest(".glyph-controls")) return;
    if (d3.brushSelection(brushG.node())) brush.move(brushG, null);
  });
}

// ---- Zoom -------------------------------------------------------------------

function addZoom(svgNode, g, dragState) {
  const svgSel = d3.select(svgNode);

  // The plot group already carries the axis-margin translate. Compose the
  // zoom transform with it rather than replacing it — otherwise the whole
  // plot (marks, axes and the brush overlay alike) jumps by the padding
  // offset the moment the first zoom or pan happens.
  const baseTransform = g.attr("transform") || "";

  const zoom = d3.zoom()
    .scaleExtent([0.5, 20])
    // Wheel (including a trackpad pinch, which arrives as ctrl+wheel) and
    // double-click always zoom. A drag only pans when the drag mode says
    // so, so it can't pan and brush at the same time; two fingers is always
    // a pinch-zoom whatever the mode.
    .filter(function(event) {
      if (event.type === "wheel" || event.type === "dblclick") return !event.button;
      if (event.touches) {
        return event.touches.length >= 2 || dragModeOf(dragState, "pan") === "pan";
      }
      return !event.button && !event.ctrlKey && dragModeOf(dragState, "pan") === "pan";
    })
    // Applied straight away. Deferring it to the next frame, as perFrame()
    // does for hover, measured slower in Chromium, which already delivers
    // wheel events once per frame: one more full repaint of a large plot
    // before the zoom shows (#25).
    .on("zoom", function({ transform }) {
      g.attr("transform", `${baseTransform} ${transform}`);
    });

  svgSel.call(zoom);

  // Zooming in or out by double-click and resetting are animated, but each
  // frame of the animation repaints the whole plot; with many elements that
  // is slow enough that the animation only adds delay, so large plots jump
  // straight to the result.
  const animate = (sel) => g.node().getElementsByTagName("*").length < 3000
    ? sel.transition().duration(300) : sel;
  const resetZoom = () => animate(svgSel).call(zoom.transform, d3.zoomIdentity);

  // d3-zoom's own double-click handler always zooms IN, with no built-in way
  // back out. If already zoomed in, reset to identity instead of zooming in
  // further (mobile users who double-tap to zoom previously had no way out).
  let lastDoubleHandled = 0;
  function handleDoubleZoom(node, event) {
    // A double-tap can arrive by three routes — d3-zoom forwarding its own
    // touch detection to "dblclick.zoom", the browser synthesizing a real
    // dblclick after a tap pair, and the fallback detector below — so
    // collapse anything that arrives twice in quick succession into one.
    const now = Date.now();
    if (now - lastDoubleHandled < 400) return;
    lastDoubleHandled = now;

    const current = d3.zoomTransform(node);
    const sel = d3.select(node);
    if (current.k > 1.01) {
      animate(sel).call(zoom.transform, d3.zoomIdentity);
    } else {
      const center = pointerXY(event, node);
      animate(sel).call(zoom.scaleBy, 2, center);
    }
  }

  svgSel.on("dblclick.zoom", function(event) {
    if (event.preventDefault) event.preventDefault();
    handleDoubleZoom(this, event);
  });

  // d3-zoom only detects a touch double-tap inside the touchstart gesture it
  // admitted, so in brush mode (where the filter rejects a one-finger
  // touchstart) its detection never runs. Detect the double-tap here instead
  // and route it to the same handler, so double-tap zoom/reset works in both
  // drag modes. Movement between touchstart and touchend disqualifies the
  // gesture, so finishing a brush drag near a previous tap isn't read as one.
  let tapStartXY = null, lastTapAt = 0, lastTapXY = null;

  // Two-finger pinch, handled here rather than left to d3-zoom's own touch
  // support. When a brush is on the same plot, the one-finger gesture that
  // starts first is a brush, and d3-brush calls stopImmediatePropagation on
  // every later touchmove — so a second finger never reaches d3-zoom's
  // listeners at all. These run in the capture phase, before anything
  // downstream can intercept them, and stop the event so neither d3-zoom nor
  // the brush acts on the same fingers. The transform still goes through the
  // zoom behavior, so reset, double-tap and the wheel stay consistent.
  let pinch = null;
  const pinchDistance = (touches) =>
    Math.hypot(touches[0].clientX - touches[1].clientX, touches[0].clientY - touches[1].clientY);
  const pinchMidpoint = (touches, node) => {
    const a = d3.pointer(touches[0], node);
    const b = d3.pointer(touches[1], node);
    return [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  };

  svgNode.addEventListener("touchstart", function(event) {
    if (!event.touches || event.touches.length < 2) return;
    event.stopImmediatePropagation();
    // A pinch is never a tap or a double-tap.
    tapStartXY = null;
    lastTapXY = null;
    const transform = d3.zoomTransform(svgNode);
    pinch = {
      distance: pinchDistance(event.touches),
      transform,
      // Anchor in untransformed content space, so the point between the
      // fingers stays put as they move and spread.
      anchor: transform.invert(pinchMidpoint(event.touches, svgNode))
    };
  }, true);

  svgNode.addEventListener("touchmove", function(event) {
    if (!pinch || !event.touches || event.touches.length < 2) return;
    if (event.cancelable) event.preventDefault();
    event.stopImmediatePropagation();

    const ratio = pinch.distance > 0 ? pinchDistance(event.touches) / pinch.distance : 1;
    const k = Math.max(0.5, Math.min(20, pinch.transform.k * ratio));
    const mid = pinchMidpoint(event.touches, svgNode);
    svgSel.call(
      zoom.transform,
      d3.zoomIdentity.translate(mid[0] - pinch.anchor[0] * k, mid[1] - pinch.anchor[1] * k).scale(k)
    );
  }, true);

  svgNode.addEventListener("touchend", function(event) {
    if (!pinch) return;
    if (event.touches && event.touches.length >= 2) return;
    event.stopImmediatePropagation();
    pinch = null;
    lastTapXY = null;
  }, true);

  svgSel
    .on("touchstart.glyph-dbltap", function(event) {
      const t = (event.touches && event.touches.length === 1) ? event.touches[0] : null;
      tapStartXY = t ? [t.clientX, t.clientY] : null;
    })
    .on("touchend.glyph-dbltap", function(event) {
      if (event.touches && event.touches.length > 0) return;
      const touch = event.changedTouches && event.changedTouches[0];
      if (!touch || !tapStartXY) { lastTapXY = null; return; }

      const xy = [touch.clientX, touch.clientY];
      const moved = Math.hypot(xy[0] - tapStartXY[0], xy[1] - tapStartXY[1]);
      tapStartXY = null;
      if (moved > 10) { lastTapXY = null; return; }

      const now = Date.now();
      const isDouble = lastTapXY && (now - lastTapAt) < 500 &&
        Math.hypot(xy[0] - lastTapXY[0], xy[1] - lastTapXY[1]) < 20;
      if (isDouble) {
        lastTapXY = null;
        handleDoubleZoom(this, event);
      } else {
        lastTapAt = now;
        lastTapXY = xy;
      }
    });

  addZoomControls(svgNode, zoom, svgSel, dragState, resetZoom);
}

// ---- Controls bar -----------------------------------------------------------
//
// Small always-visible controls in the plot's top-right corner, shared by
// zoom (drag mode, reset) and the brush (clear selection). Created on first
// use, so a plot with neither has none.
const CONTROL_BUTTON_CSS = "font-size:11px;line-height:1.2;padding:2px 8px;cursor:pointer;" +
  "background:rgba(255,255,255,0.9);border:1px solid #ccc;border-radius:3px;color:#333;";

function controlsBar(hostEl) {
  let bar = [...hostEl.children].find(c => c.classList.contains("glyph-controls"));
  if (bar) return bar;
  if (getComputedStyle(hostEl).position === "static") hostEl.style.position = "relative";
  bar = document.createElement("div");
  bar.className = "glyph-controls";
  bar.style.cssText = "position:absolute;top:4px;right:4px;z-index:2;display:flex;gap:4px;";
  hostEl.appendChild(bar);
  return bar;
}

function controlButton(className) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = className;
  button.style.cssText = CONTROL_BUTTON_CSS;
  return button;
}

// A button's label in full, and as just its symbol for when the bar doesn't
// fit; the full label stays in its tooltip and aria-label.
function setControlLabel(button, label, title) {
  button.dataset.label = label;
  button.dataset.short = label.split(" ")[0];
  button.title = title;
  button.setAttribute("aria-label", title);
  const bar = button.parentNode;
  button.textContent = bar && bar.dataset.compact ? button.dataset.short : label;
}

// Shows full labels if they fit the plot's width, and symbols only if not
// (small facet panels, a narrow Viewer pane).
function fitControls(bar) {
  const host = bar && bar.parentNode;
  if (!host || !host.clientWidth) return;
  const buttons = [...bar.querySelectorAll("button")];
  delete bar.dataset.compact;
  buttons.forEach(b => { if (b.dataset.label) b.textContent = b.dataset.label; });
  if (bar.offsetWidth > host.clientWidth - 8) {
    bar.dataset.compact = "true";
    buttons.forEach(b => { if (b.dataset.short) b.textContent = b.dataset.short; });
  }
}

// A reset for a zoomed/panned plot (the only way back out on a touch device,
// which has no scroll wheel to zoom back out with) and — only when a drag is
// ambiguous because both zoom and brush are enabled — a toggle for what a
// drag does.
function addZoomControls(svgNode, zoom, svgSel, dragState, resetZoom) {
  const hostEl = svgNode.parentNode;
  if (!hostEl || !(hostEl instanceof HTMLElement)) return;
  const bar = controlsBar(hostEl);

  if (dragState && dragState.brushEnabled && dragState.zoomEnabled) {
    const toggle = controlButton("glyph-drag-mode");
    const sync = (mode) => {
      setControlLabel(toggle, mode === "brush" ? "▨ Drag: select" : "✋ Drag: pan",
        mode === "brush"
          ? "Dragging selects points. Click to switch to panning."
          : "Dragging pans the plot. Click to switch to selecting.");
      toggle.setAttribute("aria-pressed", mode === "brush" ? "true" : "false");
    };
    dragState.listeners.push(sync);
    toggle.addEventListener("click", () => {
      setDragMode(dragState, dragState.mode === "brush" ? "pan" : "brush");
    });
    bar.insertBefore(toggle, bar.firstChild);
    sync(dragState.mode);
  }

  const reset = controlButton("glyph-zoom-reset");
  reset.addEventListener("click", resetZoom);
  bar.appendChild(reset);
  setControlLabel(reset, "⟲ Reset zoom", "Reset zoom");
  fitControls(bar);
}

// ---- Nearest point (for line charts) ----------------------------------------

function addNearestInteraction(g, data, enc, scales, interact, theme, w, h) {
  if (!enc.x?.field || !enc.y?.field) return;

  const dot = g.append("circle")
    .attr("r", 5)
    .attr("fill", theme.accent || "#4269d0")
    .attr("stroke", "#fff")
    .attr("stroke-width", 2)
    .style("opacity", 0);

  const bisect = d3.bisector(d => getVal(d, enc.x)).center;

  const overlay = g.append("rect")
    .attr("class", "overlay")
    .attr("width", w)
    .attr("height", h)
    .attr("fill", "none")
    .attr("pointer-events", "all");

  // At most one update per frame, for the latest pointer position.
  const move = perFrame(({ clientX, clientY }) => {
    const [mx] = d3.pointer({ clientX, clientY }, overlay.node());
    const x0 = scales.x.invert(mx);
    const i = bisect(data, x0);
    const d = data[i];
    if (!d) return;

    dot.attr("cx", scales.x(getVal(d, enc.x)))
      .attr("cy", scales.y(getVal(d, enc.y)))
      .style("opacity", 1);
  });

  overlay
    .on("mousemove", function(event) {
      move.schedule({ clientX: event.clientX, clientY: event.clientY });
    })
    .on("mouseout", function() {
      move.cancel();
      dot.style("opacity", 0);
    });
}

// ---- Animation --------------------------------------------------------------

function applyAnimation(g, animConfig, spec, scales, data, theme) {
  const duration = animConfig.duration || 500;
  const stagger = animConfig.stagger || 0;
  const easing = animConfig.easing === "bounce" ? d3.easeBounce
    : animConfig.easing === "elastic" ? d3.easeElastic
    : d3.easeCubicInOut;

  if (animConfig.transition === "slide") {
    // Stash each bar's real height/y on the DOM node itself before zeroing
    // them out, then animate back to those stored values. (The previous
    // version read `this.__data__?.__h`, but `__data__` is just D3's bound
    // datum — nothing ever set `__h`/`__y` on it, and `getAttribute("height")`
    // was already 0 by the time the transition's target function ran, so
    // bars animated to zero height. See GitHub issue #2.)
    g.selectAll("rect")
      .each(function() {
        this.__glyphH = +this.getAttribute("height");
        this.__glyphY = +this.getAttribute("y");
      })
      .attr("height", 0)
      .attr("y", function() { return this.__glyphGrowsDown ? this.__glyphY : this.__glyphY + this.__glyphH; })
      .transition()
      .duration(duration)
      .delay((d, i) => i * stagger)
      .ease(easing)
      .attr("height", function() { return this.__glyphH; })
      .attr("y", function() { return this.__glyphY; });
  }

  if (animConfig.transition === "fade") {
    g.selectAll("circle, rect, path.marks-line, path.marks-area")
      .style("opacity", 0)
      .transition()
      .duration(duration)
      .delay((d, i) => i * stagger)
      .ease(easing)
      .style("opacity", null); // restore original
  }

  if (animConfig.transition === "morph" && animConfig.by) {
    applyMorphAnimation(g, scales, spec, animConfig, data, theme, duration, easing);
  }
}

// Keyframe ("morph") animation: cycles the plot through subsets of `data`
// grouped by `animConfig.by`, with a play/pause control. Marks are re-joined
// by within-frame index (not a stable cross-frame entity id, since the spec
// has no such id) so the chart visibly transitions between states.
function applyMorphAnimation(g, scales, spec, animConfig, data, theme, duration, easing) {
  const pointMark = (spec.marks || []).find(m => m.type === "point");
  if (!pointMark || !data || data.length === 0) return;

  const enc = pointMark.encoding || {};
  const style = pointMark.style || {};
  const byField = animConfig.by;

  const groups = d3.groups(data, d => d[byField]).sort((a, b) => d3.ascending(a[0], b[0]));
  if (groups.length < 2) {
    console.warn(`glyph: animate(by = "${byField}", transition = "morph") has nothing to cycle through — ` +
      `"${byField}" has ${groups.length} unique value(s) in the data. Skipping morph animation.`);
    return;
  }

  let frame = 0;
  let playing = true;
  let timer = null;

  const markLayer = g.select(".marks-point");
  if (markLayer.empty()) return;

  const frameLabel = g.append("text")
    .attr("class", "morph-frame-label")
    .attr("x", 4).attr("y", -12)
    .attr("font-size", 11)
    .attr("font-family", theme.font || "system-ui")
    .attr("fill", theme.fg || "#333");

  function renderFrame() {
    const [key, subset] = groups[frame];
    const circles = markLayer.selectAll("circle").data(subset, (d, i) => i);

    circles.exit()
      .transition().duration(duration / 2)
      .attr("r", 0)
      .remove();

    circles.enter()
      .append("circle")
      .attr("r", 0)
      .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
      .attr("stroke", "#fff")
      .attr("stroke-width", 1)
      .attr("cx", d => xPos(scales, enc, d))
      .attr("cy", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
      .merge(circles)
      .transition().duration(duration).ease(easing)
      .attr("cx", d => xPos(scales, enc, d))
      .attr("cy", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
      .attr("r", d => scales.size ? scales.size(getVal(d, enc.size)) : (style.size || 5))
      .attr("opacity", style.opacity || 0.8);

    frameLabel.text(`${byField} = ${formatValue(key)}`);
    if (markLayer.node().__glyphFinder) markLayer.node().__glyphFinder.invalidate();
  }

  renderFrame();

  function tick() {
    if (!playing) return;
    frame = (frame + 1) % groups.length;
    renderFrame();
    timer = setTimeout(tick, duration + 400);
  }

  if (animConfig.loop !== false) {
    timer = setTimeout(tick, duration + 400);
  }

  const svgNode = g.node().closest("svg");
  const hostEl = svgNode ? svgNode.parentNode : null;
  if (hostEl) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "glyph-morph-control";
    btn.textContent = "⏸ Pause";
    btn.style.cssText = "display:block;margin:2px 0 4px 0;font-size:11px;padding:2px 8px;cursor:pointer;";
    btn.addEventListener("click", () => {
      playing = !playing;
      btn.textContent = playing ? "⏸ Pause" : "▶ Play";
      if (playing) {
        timer = setTimeout(tick, duration + 400);
      } else if (timer) {
        clearTimeout(timer);
      }
    });
    hostEl.insertBefore(btn, svgNode);
  }
}
