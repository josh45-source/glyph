// glyph.js — D3.js rendering engine for the glyph R package
// This is the htmlwidgets binding that compiles glyph specs into interactive SVG

console.log("glyph widget loaded");

HTMLWidgets.widget({
  name: "glyph",
  type: "output",

  factory: function(el, width, height) {
    // Import D3 from CDN (bundled in production)
    let spec = null;
    let svg = null;

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
        const theme = spec.theme || {};
        const W = spec.width || width;
        const H = spec.height || height;
        const pad = theme.padding || 40;

        // Clear previous render
        el.innerHTML = "";
        el.style.background = theme.bg || "#fff";

        // Create SVG
        svg = d3.select(el)
          .append("svg")
          .attr("width", W)
          .attr("height", H)
          .attr("viewBox", `0 0 ${W} ${H}`);

        const plotArea = svg.append("g")
          .attr("class", "glyph-plot")
          .attr("transform", `translate(${pad}, ${pad})`);

        const innerW = W - pad * 2;
        const innerH = H - pad * 2;
        const data = spec.data?.values || [];

        // --- Build scales ---
        const scales = {};
        for (const mark of (spec.marks || [])) {
          const enc = mark.encoding || {};

          if (enc.x?.field) {
            scales.x = scales.x || buildScale(
              enc.x, data, [0, innerW], spec.scales?.x
            );
          }
          if (enc.y?.field) {
            scales.y = scales.y || buildScale(
              enc.y, data, [innerH, 0], spec.scales?.y
            );
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
        for (const mark of (spec.marks || [])) {
          drawMark(plotArea, mark, data, scales, innerW, innerH, theme, spec);
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

        // --- Apply entrance animations ---
        if (spec.animate) {
          applyAnimation(plotArea, spec.animate);
        }
    }
  }
});

// ---- Scale builder ----------------------------------------------------------

function buildScale(encoding, data, range, scaleOpts) {
  const field = encoding.field;
  const type = encoding.type;
  const opts = scaleOpts || {};

  if (type === "quantitative") {
    let domain = opts.domain || d3.extent(data, d => +d[field]);
    if (opts.zero) domain = [Math.min(0, domain[0]), Math.max(0, domain[1])];
    if (opts.nice !== false) {
      return d3.scaleLinear().domain(domain).range(range).nice();
    }
    return d3.scaleLinear().domain(domain).range(range);
  }

  if (type === "temporal") {
    const domain = d3.extent(data, d => new Date(d[field]));
    return d3.scaleTime().domain(domain).range(range);
  }

  if (type === "nominal" || type === "ordinal") {
    const domain = [...new Set(data.map(d => d[field]))];
    return d3.scaleBand().domain(domain).range(range).padding(0.1);
  }

  // Fallback
  return d3.scaleLinear()
    .domain(d3.extent(data, d => +d[field]))
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

function drawMark(g, mark, data, scales, w, h, theme, spec) {
  const enc = mark.encoding || {};
  const style = mark.style || {};
  const interact = spec.interact || {};

  switch (mark.type) {
    case "point":
      drawPoints(g, data, enc, scales, style, interact, theme);
      break;
    case "bar":
      drawBars(g, data, enc, scales, style, w, h, interact, theme);
      break;
    case "line":
      drawLine(g, data, enc, scales, style, interact, theme);
      break;
    case "area":
      drawArea(g, data, enc, scales, style, h, interact, theme);
      break;
    case "rule":
      drawRule(g, enc, scales, style, w, h, theme);
      break;
  }
}

function drawPoints(g, data, enc, scales, style, interact, theme) {
  const points = g.append("g").attr("class", "marks-point")
    .selectAll("circle")
    .data(data)
    .join("circle")
    .attr("cx", d => scales.x ? scales.x(getVal(d, enc.x)) : 0)
    .attr("cy", d => scales.y ? scales.y(getVal(d, enc.y)) : 0)
    .attr("r", d => scales.size ? scales.size(getVal(d, enc.size)) : (style.size || 5))
    .attr("fill", d => scales.color ? scales.color(getVal(d, enc.color)) : (theme.accent || "#4269d0"))
    .attr("opacity", style.opacity || 0.8)
    .attr("stroke", "#fff")
    .attr("stroke-width", 1);

  // Interactivity
  if (interact.tooltip?.enabled) {
    addTooltip(points, data, enc, interact.tooltip, theme);
  }
  if (interact.hover?.enabled) {
    addHoverEffect(points, interact.hover, style);
  }
  if (interact.brush?.enabled) {
    addBrush(g, points, scales, enc, interact.brush);
  }
  if (interact.zoom?.enabled) {
    addZoom(g.node().parentNode, g, scales, enc, points, "point");
  }
}

function drawBars(g, data, enc, scales, style, w, h, interact, theme) {
  const isVertical = style.orient !== "horizontal";
  const bandwidth = scales.x?.bandwidth ? scales.x.bandwidth() : w / data.length * 0.8;

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

  if (interact.tooltip?.enabled) addTooltip(bars, data, enc, interact.tooltip, theme);
  if (interact.hover?.enabled) addHoverEffect(bars, interact.hover, style);
}

function drawLine(g, data, enc, scales, style, interact, theme) {
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
    addNearestInteraction(g, data, enc, scales, interact, theme);
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

// ---- Brush ------------------------------------------------------------------

function addBrush(g, points, scales, enc, brushConfig) {
  const brush = d3.brush()
    .extent([[0, 0], [+g.node().parentNode.getAttribute("width"), +g.node().parentNode.getAttribute("height")]])
    .on("brush end", function({ selection }) {
      if (!selection) {
        points.attr("opacity", 0.8);
        return;
      }
      const [[x0, y0], [x1, y1]] = selection;
      points.attr("opacity", d => {
        const cx = scales.x(getVal(d, enc.x));
        const cy = scales.y(getVal(d, enc.y));
        return (cx >= x0 && cx <= x1 && cy >= y0 && cy <= y1) ? 1 : 0.1;
      });
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

function addNearestInteraction(g, data, enc, scales, interact, theme) {
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
    .attr("width", g.node().parentNode.getAttribute("width"))
    .attr("height", g.node().parentNode.getAttribute("height"))
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

function applyAnimation(g, animConfig) {
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

  if (animConfig.transition === "morph") {
    // For keyframe animations — requires `by` field
    // (Full implementation would cycle through data subsets)
  }
}
