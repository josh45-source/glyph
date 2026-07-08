// glyph.js — D3.js rendering engine for the glyph R package
// This is the htmlwidgets binding that compiles glyph specs into interactive SVG

console.log("glyph widget loaded");

HTMLWidgets.widget({
  name: "glyph",
  type: "output",

  factory: function(el, width, height) {
    let spec = null;

    return {
      renderValue: function(x) {
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

    function doRender(x) {
      spec = x.spec;
      el.innerHTML = "";

      if (spec.type === "layout") {
        el.style.background = "transparent";
        renderLayout(el, spec, spec.width || width || 600, spec.height || height || 400);
        return;
      }

      if (spec.facets && (spec.facets.cols || spec.facets.rows)) {
        el.style.background = "transparent";
        renderFacets(el, spec, spec.width || width || 600, spec.height || height || 400);
        return;
      }

      const theme = spec.theme || {};
      el.style.background = theme.bg || "#fff";
      renderSpecInto(el, spec, {
        width: spec.width || width || 600,
        height: spec.height || height || 400,
        standalone: true
      });
    }
  }
});

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
    svg = d3.select(container).append("svg")
      .attr("width", W)
      .attr("height", H)
      .attr("viewBox", `0 0 ${W} ${H}`);
  }

  if (!opts.standalone) {
    svg.append("rect")
      .attr("class", "glyph-bg")
      .attr("width", W).attr("height", H)
      .attr("fill", theme.bg || "#fff");
  }

  const plotArea = svg.append("g")
    .attr("class", "glyph-plot")
    .attr("transform", `translate(${basePad}, ${topPad})`);

  const innerW = W - basePad - rightPad;
  const innerH = H - topPad - basePad;
  const data = opts.data || spec.data?.values || [];

  // --- Build scales ---
  const scales = {};
  const forced = opts.forceDomain || {};
  for (const mark of (spec.marks || [])) {
    const enc = mark.encoding || {};

    if (enc.x?.field) {
      scales.x = scales.x || buildScale(enc.x, data, [0, innerW], spec.scales?.x, forced.x);
    }
    if (enc.y?.field) {
      scales.y = scales.y || buildScale(enc.y, data, [innerH, 0], spec.scales?.y, forced.y);
    }
    if (enc.x2?.field && !scales.x) {
      scales.x = buildScale(enc.x2, data, [0, innerW], spec.scales?.x, forced.x);
    }
    if (enc.y2?.field && !scales.y) {
      scales.y = buildScale(enc.y2, data, [innerH, 0], spec.scales?.y, forced.y);
    }
    // Ribbon marks map y_min/y_max instead of a plain y; build the y-scale
    // from the combined extent of both fields.
    if (!scales.y && enc.y_min?.field && enc.y_max?.field) {
      const domain = forced.y || [
        d3.min(data, d => Math.min(+d[enc.y_min.field], +d[enc.y_max.field])),
        d3.max(data, d => Math.max(+d[enc.y_min.field], +d[enc.y_max.field]))
      ];
      scales.y = buildScale(enc.y_max, data, [innerH, 0], spec.scales?.y, domain);
    }
    if (enc.color?.field) {
      const unique = [...new Set(data.map(d => d[enc.color.field]))];
      scales.color = d3.scaleOrdinal(d3.schemeTableau10).domain(unique);
    }
    if (enc.size?.field) {
      const ext = d3.extent(data, d => +d[enc.size.field]);
      scales.size = d3.scaleLinear().domain(ext).range([3, 20]);
    }
  }

  // --- Draw grid ---
  if (theme.grid !== false) {
    drawGrid(plotArea, scales, innerW, innerH, theme);
  }

  // --- Draw axes ---
  drawAxes(plotArea, scales, innerW, innerH, theme, spec.scales);

  // --- Draw marks ---
  const markRegistry = [];
  for (const mark of (spec.marks || [])) {
    drawMark(plotArea, mark, data, scales, innerW, innerH, theme, spec, markRegistry);
  }

  // --- Legend (for selection(type = "legend")) ---
  const selections = spec.interact?.selections || {};
  const legendSel = Object.values(selections).find(s => s.type === "legend");
  if (legendSel && scales.color) {
    drawLegend(svg, scales.color, legendSel, markRegistry, W, basePad, theme);
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

  // --- Crossfilter plumbing ---
  let externalListener = null;
  const emitSelection = (idxSet) => { if (externalListener) externalListener(idxSet); };

  function applyExternalSelection(idxSet) {
    markRegistry.forEach(entry => {
      entry.selection.attr("opacity", function(d, i) {
        if (!idxSet || idxSet.size === 0) return entry.baseOpacity;
        return idxSet.has(i) ? Math.max(entry.baseOpacity, 0.9) : Math.min(entry.baseOpacity, 0.15);
      });
    });
  }

  function onSelectionChange(fn) { externalListener = fn; }

  // wire up emitSelection into interactive marks (brush / click) drawn above
  markRegistry.forEach(entry => { entry.emitSelection = emitSelection; });

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

  if (wantX) {
    let ext = [Infinity, -Infinity];
    panels.forEach(p => {
      const field = getPanelField(p, "x");
      const values = p.data?.values || [];
      if (!field || values.length === 0) return;
      const e = d3.extent(values, d => +d[field]);
      if (e[0] < ext[0]) ext[0] = e[0];
      if (e[1] > ext[1]) ext[1] = e[1];
    });
    if (isFinite(ext[0]) && isFinite(ext[1])) out.x = ext;
  }
  if (wantY) {
    let ext = [Infinity, -Infinity];
    panels.forEach(p => {
      const field = getPanelField(p, "y");
      const values = p.data?.values || [];
      if (!field || values.length === 0) return;
      const e = d3.extent(values, d => +d[field]);
      if (e[0] < ext[0]) ext[0] = e[0];
      if (e[1] > ext[1]) ext[1] = e[1];
    });
    if (isFinite(ext[0]) && isFinite(ext[1])) out.y = ext;
  }
  return out;
}

function renderLayout(container, layoutSpec, fallbackW, fallbackH) {
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
      renderLayout(cell.node(), panelSpec, colWidths[c], rowHeights[r]);
      result = null;
    } else {
      result = renderSpecInto(cell.node(), panelSpec, {
        width: colWidths[c],
        height: rowHeights[r],
        forceDomain: forceDomain
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

function renderFacets(container, spec, fallbackW, fallbackH) {
  const facets = spec.facets;
  const data = spec.data?.values || [];
  const colsField = facets.cols;
  const rowsField = facets.rows;

  let cellSpecs = []; // { label, data, row, col }
  let rows, cols;

  if (colsField && rowsField) {
    const colVals = [...new Set(data.map(d => d[colsField]))].sort();
    const rowVals = [...new Set(data.map(d => d[rowsField]))].sort();
    rowVals.forEach((rv, ri) => {
      colVals.forEach((cv, ci) => {
        const subset = data.filter(d => d[rowsField] === rv && d[colsField] === cv);
        cellSpecs.push({ label: `${rowsField}=${rv}, ${colsField}=${cv}`, data: subset, row: ri, col: ci });
      });
    });
    rows = rowVals.length;
    cols = colVals.length;
  } else {
    const field = colsField || rowsField;
    const vals = [...new Set(data.map(d => d[field]))].sort();
    cols = facets.wrap || Math.ceil(Math.sqrt(vals.length));
    vals.forEach((v, i) => {
      const subset = data.filter(d => d[field] === v);
      cellSpecs.push({ label: `${field} = ${v}`, data: subset, row: Math.floor(i / cols), col: i % cols });
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

  // Build a synthetic per-facet spec (same marks/scales/theme, filtered data)
  const facetSpecs = cellSpecs.map(cs => Object.assign({}, spec, {
    data: { values: cs.data },
    facets: null,
    layout: null
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
      forceDomain: forceDomain
    });
  });
}

// ---- Scale builder ----------------------------------------------------------

function buildScale(encoding, data, range, scaleOpts, forcedDomain) {
  const field = encoding.field;
  const type = encoding.type;
  const opts = scaleOpts || {};

  if (type === "quantitative") {
    let domain = forcedDomain || opts.domain || d3.extent(data, d => +d[field]);
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
    const domain = forcedDomain || d3.extent(data, d => new Date(d[field]));
    return d3.scaleTime().domain(domain).range(range);
  }

  if (type === "nominal" || type === "ordinal") {
    const domain = [...new Set(data.map(d => d[field]))];
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
    const xAxis = scales.x.bandwidth
      ? d3.axisBottom(scales.x)
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
    const yAxis = d3.axisLeft(scales.y).ticks(6);
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
  }
}

function registerMark(markRegistry, selection, baseOpacity) {
  if (markRegistry) markRegistry.push({ selection, baseOpacity });
}

function drawPoints(g, data, enc, scales, style, w, h, interact, theme, markRegistry) {
  const baseOpacity = style.opacity || 0.8;
  const points = g.append("g").attr("class", "marks-point")
    .selectAll("circle")
    .data(data)
    .join("circle")
    .attr("cx", d => scales.x ? scales.x(getVal(d, enc.x)) : 0)
    .attr("cy", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
    .attr("r", d => scales.size ? scales.size(getVal(d, enc.size)) : (style.size || 5))
    .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
    .attr("opacity", baseOpacity)
    .attr("stroke", "#fff")
    .attr("stroke-width", 1);

  registerMark(markRegistry, points, baseOpacity);

  // Interactivity
  if (interact.tooltip?.enabled) {
    addTooltip(points, data, enc, interact.tooltip, theme);
  }
  if (interact.hover?.enabled) {
    addHoverEffect(points, interact.hover, style);
  }
  if (interact.brush?.enabled) {
    addBrush(g, points, scales, enc, interact.brush, markRegistry, w, h);
  }
  if (interact.zoom?.enabled) {
    addZoom(g.node().parentNode, g, scales, enc, points, "point");
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

  const bars = g.append("g").attr("class", "marks-bar")
    .selectAll("rect")
    .data(data)
    .join("rect")
    .attr("x", d => {
      const val = scales.x ? scales.x(getVal(d, enc.x)) : 0;
      return scales.x?.bandwidth ? val : val - bandwidth / 2;
    })
    .attr("y", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
    .attr("width", bandwidth)
    .attr("height", d => scales.y ? h - scales.y(getVal(d, enc.y)) : 0)
    .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
    .attr("rx", style.corner_radius || 0);

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
  const area = d3.area()
    .x(d => scales.x(getVal(d, enc.x)))
    .y0(h)
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
    .text(d => labelEnc?.field ? d[labelEnc.field] : "");

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

function drawLegend(svg, colorScale, legendSel, markRegistry, W, topPad, theme) {
  const domain = colorScale.domain();
  const fg = theme.fg || "#333";
  const font = theme.font || "system-ui";
  const itemH = 16;

  const g = svg.append("g")
    .attr("class", "glyph-legend")
    .attr("transform", `translate(${W - 90}, ${Math.max(8, topPad - 30)})`);

  const active = new Set(domain);

  const items = g.selectAll("g.legend-item")
    .data(domain)
    .join("g")
    .attr("class", "legend-item")
    .attr("transform", (d, i) => `translate(0, ${i * itemH})`)
    .style("cursor", "pointer");

  items.append("rect")
    .attr("width", 10).attr("height", 10)
    .attr("fill", d => colorScale(d));

  items.append("text")
    .attr("x", 14).attr("y", 9)
    .attr("font-family", font)
    .attr("font-size", 10)
    .attr("fill", fg)
    .text(d => d);

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
  });
}

function legendKeyForDatum(datum, colorScale) {
  // colorScale.domain() holds the raw field values used when the scale was
  // built; find which domain entry, when passed through the scale, would be
  // consistent with how this datum was colored. Since drawPoints/drawBars
  // call scales.color(getVal(d, enc.color)), the raw field value IS the key
  // — but we don't have `enc` here, so approximate via domain membership by
  // checking every field on the datum against the scale's domain.
  const domain = colorScale.domain();
  for (const key in datum) {
    if (domain.includes(datum[key])) return datum[key];
  }
  return undefined;
}

// ---- Helpers ----------------------------------------------------------------

function getVal(d, encoding) {
  if (!encoding) return 0;
  if (encoding.field) return d[encoding.field];
  return 0;
}

// ---- Tooltip ----------------------------------------------------------------

function addTooltip(selection, data, enc, tooltipConfig, theme) {
  const tooltip = d3.select("body").append("div")
    .style("position", "absolute")
    .style("background", theme.fg === "#e0e0e0" ? "#333" : "#fff")
    .style("color", theme.fg === "#e0e0e0" ? "#fff" : "#333")
    .style("padding", "6px 10px")
    .style("border-radius", "4px")
    .style("font-size", "11px")
    .style("font-family", theme.font || "system-ui")
    .style("box-shadow", "0 2px 8px rgba(0,0,0,0.15)")
    .style("pointer-events", "none")
    .style("opacity", 0);

  selection
    .on("mouseover", function(event, d) {
      let text = "";
      if (tooltipConfig.template === "auto") {
        // Auto-generate from encodings
        for (const [key, val] of Object.entries(enc)) {
          if (val?.field) text += `${val.field}: ${d[val.field]}\n`;
        }
      } else {
        // Template string
        text = tooltipConfig.template.replace(/\{(\w+)\}/g, (_, k) => d[k] ?? k);
      }

      tooltip.html(text.trim().replace(/\n/g, "<br>"))
        .style("opacity", 1)
        .style("left", (event.pageX + 12) + "px")
        .style("top", (event.pageY - 12) + "px");
    })
    .on("mousemove", function(event) {
      tooltip.style("left", (event.pageX + 12) + "px")
        .style("top", (event.pageY - 12) + "px");
    })
    .on("mouseout", function() {
      tooltip.style("opacity", 0);
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

    const entry = (markRegistry || []).find(e => e.selection === selection);
    if (entry && entry.emitSelection) entry.emitSelection(selectedIdx || new Set());
  });
}

// ---- Brush ------------------------------------------------------------------

function addBrush(g, points, scales, enc, brushConfig, markRegistry, w, h) {
  const baseOpacity = +points.attr("opacity") || 0.8;
  const brush = d3.brush()
    .extent([[0, 0], [w, h]])
    .on("brush end", function({ selection }) {
      if (!selection) {
        points.attr("opacity", baseOpacity);
        const entry = (markRegistry || []).find(e => e.selection === points);
        if (entry && entry.emitSelection) entry.emitSelection(new Set());
        return;
      }
      const [[x0, y0], [x1, y1]] = selection;
      const idxSet = new Set();
      points.attr("opacity", function(d, i) {
        const cx = scales.x(getVal(d, enc.x));
        const cy = scales.y(getVal(d, enc.y));
        const hit = (cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1);
        if (hit) idxSet.add(i);
        return hit ? 1 : 0.1;
      });

      const entry = (markRegistry || []).find(e => e.selection === points);
      if (entry && entry.emitSelection) entry.emitSelection(idxSet);
    });

  g.append("g").attr("class", "brush").call(brush);
}

// ---- Zoom -------------------------------------------------------------------

function addZoom(svgNode, g, scales, enc, marks, markType) {
  const zoom = d3.zoom()
    .scaleExtent([0.5, 20])
    .on("zoom", function({ transform }) {
      g.attr("transform", transform);
    });

  d3.select(svgNode).call(zoom);
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

  g.append("rect")
    .attr("class", "overlay")
    .attr("width", w)
    .attr("height", h)
    .attr("fill", "none")
    .attr("pointer-events", "all")
    .on("mousemove", function(event) {
      const [mx] = d3.pointer(event);
      const x0 = scales.x.invert(mx);
      const i = bisect(data, x0);
      const d = data[i];
      if (!d) return;

      dot.attr("cx", scales.x(getVal(d, enc.x)))
        .attr("cy", scales.y(getVal(d, enc.y)))
        .style("opacity", 1);
    })
    .on("mouseout", function() {
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
    g.selectAll("rect")
      .attr("height", 0)
      .attr("y", function() {
        return +this.getAttribute("y") + +this.getAttribute("height");
      })
      .transition()
      .duration(duration)
      .delay((d, i) => i * stagger)
      .ease(easing)
      .attr("height", function() { return this.__data__?.__h || this.getAttribute("height"); })
      .attr("y", function() { return this.__data__?.__y || this.getAttribute("y"); });
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
      .attr("cx", d => scales.x ? scales.x(getVal(d, enc.x)) : 0)
      .attr("cy", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
      .merge(circles)
      .transition().duration(duration).ease(easing)
      .attr("cx", d => scales.x ? scales.x(getVal(d, enc.x)) : 0)
      .attr("cy", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
      .attr("r", d => scales.size ? scales.size(getVal(d, enc.size)) : (style.size || 5))
      .attr("opacity", style.opacity || 0.8);

    frameLabel.text(`${byField} = ${key}`);
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
