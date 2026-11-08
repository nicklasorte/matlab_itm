// Builds the working paper (.docx) from the figures and CSV tables that
// make_wp_figures_rev1.m, compare_trer16_rev1.m,
// diffraction_decomposition_rev1.m, and make_wp_summary_figures_rev1.m write. Every number in a table, and the numbers
// in the text marked with ${...}, come from those CSV files, so the paper
// and the MATLAB output can't drift apart.
//
//   node build_wp_docx_rev2.js [figures_dir] [output.docx]
//
// Requires the docx npm package.

const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, ImageRun, Table, TableRow, TableCell, Header, Footer,
  AlignmentType, HeadingLevel, WidthType, BorderStyle, ShadingType, PageNumber, LevelFormat,
  FootnoteReferenceRun, TableOfContents, PageBreak,
} = require("docx");

const FIG = process.argv[2] || path.join(__dirname, "figures");
const OUT = process.argv[3] || path.join(__dirname, "itm_p2001_p452_comparison_working_paper_rev2.docx");
const MARK = "DRAFT//PRE-DECISIONAL";
const SHA = {
  itm: "03feac58ae3db28c2ae66226ae73109e61172a98",
  p2001: "286e68cbac94d616261f9cb514e94ec8f5464881",
  p452: "75e39de3a3177c95d40a38a1c0a2659a0ee8b28a",
};

// ---------- data ----------
function csv(name) {
  const t = fs.readFileSync(path.join(FIG, name), "utf8").trim().split(/\r?\n/);
  const split = (l) => {                  // quote-aware: writetable quotes fields with commas
    const out = []; let cur = ""; let q = false;
    for (const ch of l) {
      if (ch === '"') q = !q;
      else if (ch === "," && !q) { out.push(cur); cur = ""; }
      else cur += ch;
    }
    out.push(cur);
    return out;
  };
  const h = split(t[0]);
  return t.slice(1).map((l) => {
    const v = split(l);
    const o = {};
    h.forEach((k, i) => { const x = Number(v[i]); o[k] = v[i] === "" || isNaN(x) ? v[i] : x; });
    return o;
  });
}
const cls = csv("table_real_terrain_by_class.csv");
const byp = csv("table_real_terrain_by_percentage.csv");
const ke = csv("table_knife_edge.csv");
const res = csv("table_terrain_resolution.csv");
const arch = csv("table_archetypes.csv");
const thr = csv("table_distance_to_threshold.csv");
const flags = csv("table_itm_horizon_flags.csv")[0];
const elev = csv("table_elevation.csv");
const opt = (name) => (fs.existsSync(path.join(FIG, name)) ? csv(name) : []);
const trer = opt("table_trer16_by_path.csv");
const trerS = opt("table_trer16_summary.csv");
const dterms = opt("table_diffraction_terms.csv");
const dabl = opt("table_diffraction_ablation.csv");
const radial = fs.existsSync(path.join(FIG, "table_radial_distance_to_threshold.csv"))
  ? csv("table_radial_distance_to_threshold.csv") : [];
const F = [2700, 4900, 7250];
const r1 = (x) => (typeof x === "number" ? (Math.round(x * 10) / 10).toFixed(1) : x);
const r0 = (x) => (typeof x === "number" ? String(Math.round(x)) : x);
const r2 = (x) => (typeof x === "number" ? (Math.round(x * 100) / 100).toFixed(2) : x);
const get = (rows, f, c) => rows.find((r) => r.freq_mhz === f && r.itm_class === c);
const A = (name, f) => arch.find((r) => r.path === name && r.freq_mhz === f);
const nLinks = flags.links;
const nDif = get(cls, 2700, "Diffraction").links;

// ---------- formatting helpers ----------
const FONT = "Arial";
const footnotes = {};
let fnId = 0;
function fn(text, url) {
  fnId += 1;
  const kids = [new TextRun({ text: text + (url ? " " : ""), size: 16, font: FONT })];
  if (url) kids.push(new TextRun({ text: url, size: 16, font: FONT, color: "1F4E79" }));
  footnotes[fnId] = { children: [new Paragraph({ children: kids })] };
  return new FootnoteReferenceRun(fnId);
}
const itmUrl = (a, b) => `https://github.com/nicklasorte/matlab_itm/blob/${SHA.itm}/private/itm_p2p_core.m#L${a}-L${b}`;
const p452Url = (a, b) => `https://github.com/nicklasorte/matlab_itu_p452/blob/${SHA.p452}/p452_p2p_rev1.m#L${a}-L${b}`;
const p2001Url = (file, a, b) => `https://github.com/nicklasorte/itu_p2001/blob/${SHA.p2001}/${file}#L${a}-L${b}`;

function runs(parts) {
  // parts: strings, {i: "italic"}, {b: "bold"}, {sub: ""}, or footnote runs
  return parts.map((p) => {
    if (typeof p === "string") return new TextRun({ text: p, font: FONT });
    if (p instanceof FootnoteReferenceRun) return p;
    if (p.i) return new TextRun({ text: p.i, italics: true, font: FONT });
    if (p.b) return new TextRun({ text: p.b, bold: true, font: FONT });
    if (p.code) return new TextRun({ text: p.code, font: "Courier New", size: 20 });
    return p;
  });
}
const P = (...parts) => new Paragraph({ children: runs(parts), spacing: { after: 120, line: 276 } });
const H1 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text: t, font: FONT })] });
const H2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text: t, font: FONT })] });
const B = (...parts) => new Paragraph({ numbering: { reference: "bullets", level: 0 }, children: runs(parts), spacing: { after: 60 } });
let listNo = 0;                                 // each numbered list restarts at 1
const startList = () => { listNo += 1; };
const N = (...parts) => new Paragraph({ numbering: { reference: "numbers", level: 0, instance: listNo }, children: runs(parts), spacing: { after: 60 } });

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}
let figN = 0;
function figure(file, caption) {
  figN += 1;
  const full = path.join(FIG, file);
  const out = [];
  if (fs.existsSync(full)) {
    const s = pngSize(full);
    const w = 624; // 6.5 in at 96 dpi
    out.push(new Paragraph({ alignment: AlignmentType.CENTER, keepNext: true,
      children: [new ImageRun({ type: "png", data: fs.readFileSync(full), transformation: { width: w, height: Math.round(w * s.h / s.w) } })] }));
  } else {
    out.push(P(`[Figure file ${file} not found]`));
  }
  out.push(new Paragraph({ spacing: { after: 200 }, children: [
    new TextRun({ text: `Figure ${figN}. `, bold: true, font: FONT, size: 18 }),
    new TextRun({ text: caption, font: FONT, size: 18 })] }));
  return out;
}
let tabN = 0;
const border = { style: BorderStyle.SINGLE, size: 4, color: "999999" };
const borders = { top: border, bottom: border, left: border, right: border };
function table(caption, header, rows, widths) {
  tabN += 1;
  const total = widths.reduce((a, b) => a + b, 0);
  const cell = (t, i, head) => new TableCell({
    borders, width: { size: widths[i], type: WidthType.DXA },
    shading: head ? { fill: "D9E2F3", type: ShadingType.CLEAR, color: "auto" } : undefined,
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    children: [new Paragraph({ children: [new TextRun({ text: String(t), bold: !!head, font: FONT, size: 18 })] })],
  });
  return [
    new Paragraph({ keepNext: true, spacing: { before: 120, after: 80 }, children: [
      new TextRun({ text: `Table ${tabN}. `, bold: true, font: FONT, size: 18 }),
      new TextRun({ text: caption, font: FONT, size: 18 })] }),
    new Table({ width: { size: total, type: WidthType.DXA }, columnWidths: widths,
      rows: [new TableRow({ tableHeader: true, children: header.map((h, i) => cell(h, i, true)) }),
        ...rows.map((r) => new TableRow({ children: r.map((t, i) => cell(t, i, false)) }))] }),
    new Paragraph({ spacing: { after: 160 }, children: [] }),
  ];
}


// ---------- figure numbering by key, in order of appearance ----------
const ORDER = ["fig01", "fig02", "fig19", "fig09", "fig10", "fig03", "fig07", "fig14", "fig15",
  "fig05", "fig18", "fig04", "fig06", "fig17", "fig16", "fig12", "fig20", "fig13", "fig08", "fig11"];
const FN = (k) => `Figure ${ORDER.indexOf(k) + 1}`;
function fig(key, file, caption) {
  figN = ORDER.indexOf(key);                    // figure() adds 1
  return figure(file, caption);
}

// ---------- numbers used in the text ----------
const PEND = "[pending]";
const d27 = get(cls, 2700, "Diffraction"), d49 = get(cls, 4900, "Diffraction"), d72 = get(cls, 7250, "Diffraction");
const t27 = get(cls, 2700, "Troposcatter");
const l27 = get(cls, 2700, "LOS"), l72 = get(cls, 7250, "LOS");
const maxP2001P452 = Math.max(...cls.map((r) => Math.abs(r.p2001_minus_p452_med_db)));
const dbl = A("Double-horizon diffraction", 2700);
const los = A("Line of sight", 2700);
const tro = A("Troposcatter", 2700);
const sea = A("Over-sea coastal", 2700);
const fsl = (f, d) => 32.45 + 20 * Math.log10(f) + 20 * Math.log10(d);
const seaFsl = fsl(2700, sea.length_km);
const resI = res.find((r) => r.model === "ITM"), resP = res.find((r) => r.model === "P.2001");
const resKeys = Object.keys(resI).filter((k) => k !== "model");
const byp27 = (p) => byp.find((r) => r.freq_mhz === 2700 && r.time_pct === p);
const ke27 = ke.find((r) => r.freq_mhz === 2700), ke72 = ke.find((r) => r.freq_mhz === 7250);
const eP = elev.find((r) => r.model === "P.2001"), eQ = elev.find((r) => r.model === "P.452");

// Measured paths
const nTrer = trer.length || 41;
const nListed = trer.length ? trer.filter((r) => r.heights_assumed === 0).length : 34;
const sm = (g, m, p, k) => {
  const r = trerS.find((x) => x.group === g && x.model === m && x.percent === p);
  return r ? r[k] : NaN;
};
const S1 = (g, m, p, k) => (isNaN(sm(g, m, p, k)) ? PEND : r1(sm(g, m, p, k)));
const S0 = (g, m, p, k) => (isNaN(sm(g, m, p, k)) ? PEND : r0(sm(g, m, p, k)));
const ALL = "All, listed heights";
const G27 = "2.3-2.8 GHz", G4 = "3.4-4.1 GHz", G9 = "9.1-9.4 GHz", G1 = "1.0-1.7 GHz", GCA = "California over sea, heights assumed";
const tp = (p) => trer.find((r) => String(r.path) === String(p));
const err = (p, m) => { const r = tp(p); return r ? r[m + "_50"] - r.meas_50 : NaN; };
const E = (p, m) => (isNaN(err(p, m)) ? PEND : r1(err(p, m)));
const EA = (p, m) => (isNaN(err(p, m)) ? PEND : r1(Math.abs(err(p, m))));
const DH = (p) => (tp(p) ? r0(tp(p).itm_delta_h_m) : PEND);

// Diffraction decomposition
const dsel = (f) => dterms.filter((r) => r.freq_mhz === f);
const med = (a) => { const b = a.filter((x) => typeof x === "number" && isFinite(x)).sort((x, y) => x - y); if (!b.length) return NaN; const m = Math.floor(b.length / 2); return b.length % 2 ? b[m] : (b[m - 1] + b[m]) / 2; };
const DM = (f, fnc) => { const v = med(dsel(f).map(fnc)); return isNaN(v) ? PEND : v; };
const ab = (f, c) => { const r = dabl.find((x) => x.freq_mhz === f && x.case === c); return r ? r.median_gap_db : NaN; };
const AB = (f, c) => (isNaN(ab(f, c)) ? PEND : r1(ab(f, c)));
const fracLosRegion = (f) => { const s = dsel(f); return s.length ? s.filter((r) => r.itm_region === 1).length + " of " + s.length : PEND; };
const R1 = (x) => (typeof x === "number" ? r1(x) : x);
const R2 = (x) => (typeof x === "number" ? r2(x) : x);

// ---------- document ----------
const TITLE = "ITM, ITU-R P.2001, and ITU-R P.452 from 1 GHz to 10 GHz: How the Models Compare";
const body = [];
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1200, after: 240 },
  children: [new TextRun({ text: TITLE, bold: true, size: 40, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "Working paper, revision 2 (draft)", size: 26, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "November 2026", size: 24, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
  children: [new TextRun({ text: "Preliminary calculations to show where deeper analysis is needed. Not for decisions.", italics: true, size: 22, font: FONT })] }));
body.push(new TableOfContents("Contents", { hyperlink: true, headingStyleRange: "1-2" }));
body.push(new Paragraph({ children: [new PageBreak()] }));

// ===== Summary
body.push(H1("Summary"));
body.push(P({ b: "Question. " }, "Terrestrial interference and coverage analyses from 1 GHz to 10 GHz use one of three common propagation models: the Irregular Terrain Model (ITM, Longley-Rice) version 1.4, Recommendation ITU-R P.2001-6, or Recommendation ITU-R P.452-18. This paper asks how the three models compare across that range, mechanism by mechanism, and which of them public U.S. measurements support."));
body.push(P({ b: "Method. " }, "Every model received the same 30 m terrain profile in each calculation, so the differences are model differences. The paper runs a few targeted calculations at 2.7 GHz, 4.9 GHz, and 7.25 GHz, splits ITM's diffraction loss into its terms, and compares all three models with " + nTrer + " measured U.S. paths from 1 GHz to 10 GHz published by the Institute for Telecommunication Sciences (ITS)."));
body.push(P("The preliminary findings are the following:"));
body.push(B({ b: "Line of sight: the models agree. " }, `On ${l27.links} real-terrain line-of-sight links, the ITU models differ from ITM by a median of ${r2(l27.p2001_minus_itm_med_db)} dB at 2.7 GHz and ${r2(l72.p2001_minus_itm_med_db)} dB at 7.25 GHz, at 50% of time.`));
body.push(B({ b: "Diffraction over rough terrain: ITM predicts far more loss, and the gap grows with frequency. " }, `On real-terrain diffraction links, P.2001 is below ITM by a median of ${r1(-d27.p2001_minus_itm_med_db)} dB at 2.7 GHz, ${r1(-d49.p2001_minus_itm_med_db)} dB at 4.9 GHz, and ${r1(-d72.p2001_minus_itm_med_db)} dB at 7.25 GHz.`));
body.push(B({ b: "Most of that gap comes from three ITM ingredients. " }, `ITM adds two knife-edge losses, one at each horizon, where delta-Bullington uses one equivalent edge; it adds a clutter term of up to 15 dB; and it extends a diffraction line computed beyond the horizons back to the path. Removing all three cuts the median gap at 2.7 GHz from ${AB(2700, "ITM as is")} dB to ${AB(2700, "4 all three")} dB.`));
body.push(B({ b: "Measurements don't yet pick a winner. " }, `On ${nListed} measured U.S. paths with listed antenna heights, mostly long troposcatter and line-of-sight paths, the mean error in the median is ${S1(ALL, "ITM v1.4", 50, "mean_error_db")} dB for ITM, ${S1(ALL, "P.452-18", 50, "mean_error_db")} dB for P.452, and ${S1(ALL, "P.2001-6", 50, "mean_error_db")} dB for P.2001, with RMS errors of ${S1(ALL, "ITM v1.4", 50, "rms_error_db")} dB, ${S1(ALL, "P.452-18", 50, "rms_error_db")} dB, and ${S1(ALL, "P.2001-6", 50, "rms_error_db")} dB. The two rough-terrain beyond-horizon paths split: in Colorado at 9.2 GHz ITM predicts ${EA("321", "itm")} dB too much loss while the ITU models are within ${r1(Math.max(Math.abs(err("321", "p452")), Math.abs(err("321", "p2001"))))} dB, and in Arizona at 2.3 GHz ITM is within ${EA("1712", "itm")} dB while the ITU models predict about ${r0(Math.abs(err("1712", "p2001")))} dB too little.`));
body.push(B({ b: "P.2001 and P.452 agree at 50%. " }, `Their median difference is at most ${r2(maxP2001P452)} dB in every mechanism class and at every frequency; they share the delta-Bullington method.`));
body.push(B({ b: "The tails differ by mechanism. " }, `Below about 10% of time the ITU models add ducting, which ITM does not model; at 1% of time on a ${r0(sea.length_km)} km over-sea path P.2001 predicts ${r1(sea.itm_1 - sea.p2001_1)} dB less loss than ITM. Above 99% P.2001 adds clear-air and rain fading.`));
body.push(B({ b: "The public data have a gap. " }, "No public U.S. path-loss measurements of the needed kind exist between 4.1 GHz and 9.1 GHz."));

// ===== The question
body.push(H1("The question"));
body.push(P("Analyses of terrestrial interference and coverage turn a protection criterion into a separation distance, an exclusion zone, or a coordination zone, and the propagation model sets that distance. Analysts often treat ITM, P.2001, and P.452 as interchangeable. The models come from different traditions, though, and the paths that usually decide a separation distance are beyond line of sight: diffraction over terrain sets the median loss, and ducting and troposcatter set the loss at the small time percentages that interference criteria use. Those are the mechanisms where the models are most likely to differ."));
body.push(P("This paper answers three questions for frequencies from 1 GHz to 10 GHz:"));
startList();
body.push(N("How much do ITM, P.2001, and P.452 differ, and in which propagation mechanisms?"));
body.push(N("Why do they differ, equation by equation?"));
body.push(N("What do public U.S. measurements say about which model to trust?"));
body.push(P("The detailed calculations use three frequencies spread across the range: 2.7 GHz, 4.9 GHz, and 7.25 GHz. A frequency sweep from 100 MHz to 10 GHz on archetype paths fills in between them, and the measured paths span 1,040 MHz to 9,365 MHz."));

// ===== Outline
body.push(H1("How this paper is organized"));
body.push(P("The paper is a working draft and grows by section. The sections and their status are the following:"));
startList();
body.push(N({ b: "The three models and how their equations differ" }, " (complete). Each model's method for each mechanism, with code references."));
body.push(N({ b: "Results at 50% of time" }, " (complete, preliminary). Smooth earth, a knife edge, real terrain, resolution, frequency, and elevation angles."));
body.push(N({ b: "Why ITM's diffraction loss is higher" }, " (new in revision 2). ITM's diffraction terms, one at a time."));
body.push(N({ b: "Results over the time distribution" }, " (complete, preliminary). Tails, spread, and the dominant mechanism."));
body.push(N({ b: "Comparison with measured U.S. paths" }, " (new in revision 2). Public ITS measurements from 1 GHz to 10 GHz."));
body.push(N({ b: "What the differences mean in distance" }, " (complete, preliminary)."));
body.push(N({ b: "What the comparison means for analyses" }, " (new in revision 2, preliminary)."));
body.push(N({ b: "Where to look deeper" }, " (updated). The open questions in priority order."));
body.push(P("Planned for later revisions: western-U.S. terrain samples, aggregate interference over many emitters, P.452 with clutter, and new measurements between 4.1 GHz and 9.1 GHz if a campaign is funded."));

// ===== Models
body.push(H1("The three models"));
body.push(P("The models come from different traditions and answer slightly different questions:"));
body.push(B({ b: "ITM v1.4" }, " (NTIA/ITS, 2019) is semi-empirical. Longley and Rice developed it in the 1960s from measured attenuation; it fits straight lines and curves and predicts a distribution of loss over time, locations, and situations.", fn("A. G. Longley and P. L. Rice, Prediction of Tropospheric Radio Transmission Loss over Irregular Terrain: A Computer Method-1968, ESSA Technical Report ERL 79-ITS 67, 1968."), " This paper uses matlab_itm, a line-by-line port of the NTIA C++ that matches it to 4 × 10⁻¹³ dB.", fn("NTIA/ITS, Irregular Terrain Model (ITM), version 1.4, C++ source.", "https://github.com/NTIA/itm")));
body.push(B({ b: "P.452-18" }, " (ITU-R, 2023) predicts interference between stations on the surface of the earth for 0.001% to 50% of time. This paper uses matlab_itu_p452, built from the ITU-R reference code."));
body.push(B({ b: "P.2001-6" }, " (ITU-R, 2025) is a wide-range method for the whole year, 0% to 100% of time, that combines four sub-models including fading. This paper uses itu_p2001, built from the ITU-R reference code; it reproduces all 4,430 ITU validation cases."));

// ===== Inputs and method
body.push(H1("Inputs and method"));
body.push(H2("Terrain, climate, and statistics"));
body.push(P("Each calculation builds one terrain profile along the WGS84 geodesic at about 30 m spacing, from USGS 3DEP 1 arc-second data with Copernicus GLO-30 where 3DEP has no data, and passes it to all three models. Each model applies its own earth curvature: ITM from the surface refractivity Nₛ,", fn("ITM effective earth curvature:", itmUrl(193, 197)), " P.452 and P.2001 from the refractivity lapse rate ΔN on their ITU maps.", fn("P.452 median effective earth radius:", p452Url(126, 126))));
body.push(P("ITM's radio climate and N₀ come from the ITU-R P.617 and P.452 maps at the path midpoint, as in the WInnForum reference model.", fn("Wireless Innovation Forum, Requirements for Commercial Operation in the U.S. 3550-3700 MHz Citizens Broadband Radio Service Band, WINNF-TS-0112."), " ITM uses ground permittivity 25, conductivity 0.02 S/m, variability mode 13 (broadcast point-to-point, so location variability is removed), and 50% confidence. All three models report the loss not exceeded for a percentage of time; P.452 stops at 50%."));
body.push(H2("Calculations"));
body.push(P("Eleven small calculations each isolate one mechanism or test one explanation. MATLAB scripts in the matlab_itm repository run them and draw every figure:"));
body.push(B({ b: "Smooth earth" }, " over flat land and sea, 1 km to 200 km."));
body.push(B({ b: "A single knife edge" }, " on a 20 km path with 100 m antennas, against ITU-R P.526 J(v)."));
body.push(B({ b: "Real terrain" }, `: ${nLinks} random links of 10 km to 150 km in three mid-Atlantic regions (coastal plain, piedmont, Appalachian).`));
body.push(B({ b: "Terrain resolution" }, ", frequency (100 MHz to 10 GHz), and receiver height sweeps."));
body.push(B({ b: "The full time distribution" }, " on five archetype paths."));
body.push(B({ b: "Distance to a loss threshold" }, " on smooth earth and along four real-terrain radials."));
body.push(B({ b: "ITM climate and N₀ sensitivity." }));
body.push(B({ b: "Diffraction decomposition" }, ": ITM's diffraction terms on every real-terrain diffraction link, removed one at a time."));
body.push(B({ b: "Measured paths" }, `: all three models against ${nTrer} measured U.S. paths.`));
body.push(P("Links are classified by ITM's propagation mode in the ITM 1.2.2 codes that SEADLib returns: line of sight (0), diffraction (5 and 9), and troposcatter (6 and 10)."));

// ===== Equations
body.push(H1("How the equations differ by mechanism"));
body.push(P("Table 1 sets the methods side by side. The sections after it explain the differences that matter for the results."));
body.push(...table("Methods by mechanism.",
  ["Element", "ITM v1.4", "P.452-18", "P.2001-6"],
  [["Line of sight", "Two-ray model with a complex ground reflection coefficient, blended with an extrapolated diffraction line", "Free space plus gases plus a multipath and focusing term, 2.6(1 − e^(−0.1(dlt+dlr)))·log(p/50)", "Sub-model 1: free space, diffraction, clear-air fading, rain fading, and gases"],
   ["Diffraction", "Weighted blend of a double knife edge at the two horizons and smooth-earth diffraction, plus a clutter term; computed at two distances beyond the horizons and extended to the path as a straight line", "Delta-Bullington: Bullington on the profile, minus Bullington on a smooth profile, plus spherical-earth diffraction", "Delta-Bullington with median and p-dependent effective earth radii"],
   ["Troposcatter", "Rice et al. frequency-gain function H₀ and attenuation function F(θd); a straight line beyond dₓ", "190 + L_f + 20 log d + 0.573θ − 0.15N₀ + L_c + A_g − 10.1(−log(p/50))^0.7", "Parameters by climate zone at the common volume; at least free space"],
   ["Anomalous propagation", "None; small-percentage enhancement comes only from variability curves by climate", "Ducting and layer reflection, L_ba", "Ducting and layer reflection, and sporadic-E"],
   ["Absorption and fading", "None", "Gaseous absorption; no rain", "Gases, clear-air multipath fading, and rain fading"],
   ["Combination", "One regime selected by distance, then variability added", "Power sum of the blended terms with troposcatter", "Power sum of four sub-models"]],
  [1500, 2620, 2620, 2620]));
body.push(H2("Diffraction"));
body.push(P("ITM summarizes the terrain by its two horizons and an interdecile terrain irregularity Δh. Its diffraction loss is A_d = w·A_se + (1 − w)·A_k + A_fo: a smooth-earth term A_se, a double knife edge A_k, and a clutter term A_fo of up to 15 dB, with a weight w = 25.1/(25.1 + √q) that falls as Δh·f grows.", fn("ITM diffraction blend and weight:", itmUrl(469, 483)), " ITM computes A_d at two distances d₃ and d₄ beyond the sum of the horizon distances and extends the line through them to the path.", fn("ITM diffraction line, d₃ and d₄:", itmUrl(387, 392)), " The delta-Bullington method of P.452 and P.2001 instead finds the single most obstructing edge on the actual profile, subtracts the same construction on a smoothed profile, and adds a spherical-earth term.", fn("P.452 delta-Bullington:", p452Url(474, 481))));
body.push(H2("Troposcatter"));
body.push(P("ITM's troposcatter term uses the Rice frequency-gain function and the scattering angle from the two horizon angles.", fn("ITM troposcatter:", itmUrl(566, 608)), fn("P. L. Rice, A. G. Longley, K. A. Norton, and A. P. Barsis, Transmission Loss Predictions for Tropospheric Communication Circuits, NBS Technical Note 101, revised 1967."), " P.452 uses a closed form with an explicit time-percentage term,", fn("P.452 troposcatter, eq. (45):", p452Url(206, 209)), " and P.2001 chooses its parameters by climate zone and limits the result to at least free-space loss.", fn("P.2001 troposcatter:", p2001Url("p2001_profile_rev1.m", 325, 330))));
body.push(H2("Anomalous propagation, fading, and combination"));
body.push(P("P.452 and P.2001 model ducting and layer reflection as a separate mechanism that becomes the lowest loss at small time percentages,", fn("P.452 ducting, eq. (47):", p452Url(192, 193)), " and P.452 lowers line-of-sight loss below free space for p < 50% through its focusing term.", fn("P.452 line of sight:", p452Url(170, 174)), " ITM has no ducting; its small-percentage loss comes from variability curves.", fn("ITM time variability:", itmUrl(756, 756)), " P.2001 adds clear-air and rain fading at large percentages.", fn("P.2001 sub-model 1:", p2001Url("p2001_profile_rev1.m", 297, 306)), " ITM selects one regime by distance;", fn("ITM regime selection:", itmUrl(400, 463)), " the ITU models add every mechanism as powers.", fn("P.2001 combination:", p2001Url("p2001_profile_rev1.m", 392, 400)), fn("P.452 combination, eq. (64):", p452Url(212, 212))));

// ===== Results at 50%
body.push(H1("Results at 50% of time"));
body.push(H2("Smooth earth"));
body.push(P(`On flat land the three models track each other through line of sight and smooth-earth diffraction (${FN("fig01")}). ITM changes to troposcatter at about 70 km for 30 m and 10 m antennas, and beyond that its loss rises more slowly: at 200 km it is 1 dB to 5 dB below the ITU models. On smooth earth the models agree within about 7 dB out to 60 km, so the large real-terrain differences below don't come from smooth-earth physics.`));
body.push(...fig("fig01", "fig01_smooth_earth_land_50pct.png", "Basic transmission loss minus free-space loss on flat land, 50% of time, 30 m and 10 m antennas. Triangles mark ITM's regime changes."));
body.push(H2("Single knife edge"));
body.push(P(`With 100 m antennas on a 20 km path, so that the smooth-earth term is small, all three models track the shape of the ITU-R P.526 knife-edge function J(v) but add loss beyond it (${FN("fig02")}).`, fn("Recommendation ITU-R P.526-15, Propagation by diffraction, 2019."), ` Their mean absolute difference from J(v) for v ≥ 0 is ${r1(ke27.itm_mae_db)} dB for ITM and ${r1(ke27.p2001_mae_db)} dB for P.2001 at 2.7 GHz, and ${r1(ke72.itm_mae_db)} dB and ${r1(ke72.p2001_mae_db)} dB at 7.25 GHz (${FN("fig19")}). ITM's difference grows with frequency; the ITU models' difference doesn't. This is a coarse check, not a validation: a single raised profile point is not a physical ridge.`));
body.push(...fig("fig02", "fig02_knife_edge.png", "Excess loss over free space for one knife-edge obstacle at the middle of a 20 km path with 100 m antennas, against the P.526 function J(v)."));
body.push(...fig("fig19", "fig19_knife_edge_error.png", "Mean absolute difference from J(v) for v ≥ 0, by model and frequency."));
body.push(H2("Real terrain by mechanism"));
body.push(P(`On ${nLinks} real-terrain links the ITU models agree with ITM on line-of-sight links and fall far below it on diffraction and troposcatter links (${FN("fig09")}). The median P.2001 minus ITM difference on diffraction links is ${r1(d27.p2001_minus_itm_med_db)} dB at 2.7 GHz, ${r1(d49.p2001_minus_itm_med_db)} dB at 4.9 GHz, and ${r1(d72.p2001_minus_itm_med_db)} dB at 7.25 GHz; the largest single-link difference is ${r0(d72.p2001_minus_itm_maxabs_db)} dB. P.2001 and P.452 agree with each other within ${r2(maxP2001P452)} dB at the median in every class.`));
body.push(...fig("fig09", "fig09_real_terrain_cdf_by_mechanism.png", "Distribution over links of the difference from ITM at 50% of time, by ITM's mechanism class. Top: P.2001 minus ITM. Bottom: P.452 minus ITM."));
body.push(P(`The gap tracks ITM's terrain irregularity Δh (${FN("fig10")}). Line-of-sight links average Δh = ${r0(l27.itm_delta_h_mean_m)} m and sit near zero; diffraction links average ${r0(d27.itm_delta_h_mean_m)} m, most of them in the Appalachian region.`));
body.push(...fig("fig10", "fig10_gap_vs_delta_h.png", "P.2001 minus ITM at 50% of time against ITM's terrain irregularity Δh, by ITM mechanism class."));
body.push(H2("Terrain resolution"));
body.push(P(`Terrain resolution does not explain the gap (${FN("fig03")}). Resampling the diffraction links at 2.7 GHz from 30 m to 90 m changed the median loss by ${r2(resI[resKeys[0]])} dB for ITM and ${r2(resP[resKeys[0]])} dB for P.2001. Smoothing over 1 km lowered every model's loss by 3 dB to 4 dB and left the gap almost unchanged.`));
body.push(...fig("fig03", "fig03_terrain_resolution.png", "Left: median change in loss when the 30 m profile is resampled at 90 m or smoothed over 1 km. Right: the P.2001 minus ITM gap at each resolution."));
body.push(H2("Frequency and antenna height"));
body.push(P(`Across 100 MHz to 10 GHz, the line-of-sight archetype stays within a few dB in every model, while ITM's excess loss on the diffraction archetypes grows faster with frequency than the ITU models' (${FN("fig07")}). The trend is smooth with frequency, so results at the three calculation frequencies carry over to the frequencies between them.`));
body.push(...fig("fig07", "fig07_frequency_height_sweeps.png", "Top: loss minus free space against frequency at 50% of time; dotted lines mark 2.7 GHz, 4.9 GHz, and 7.25 GHz. Bottom: loss against receiver height at 2.7 GHz."));
body.push(H2("Elevation angles and a steep-horizon case"));
body.push(P(`The models compute nearly the same elevation angles at each terminal: P.2001 differs from ITM by a mean of ${r2(eP.mean_abs_diff_deg_tx_rx_1)}° at the transmitter and P.452 by ${r2(eQ.mean_abs_diff_deg_tx_rx_1)}°. The loss differences don't come from horizon geometry; they come from what each model does with it.`));
body.push(P(`The deepest diffraction archetype, a ${r0(dbl.length_km)} km Appalachian path, shows how far ITM can depart. ITM predicts ${r1(dbl.itm_50)} dB at 2.7 GHz and 50% of time; P.2001 predicts ${r1(dbl.p2001_50)} dB. The receiver sits below a 395 mrad (22.6°) horizon 0.63 km away, beyond ITM's small-angle approximations, which ITM flags; ${flags.links_with_horizon_angle_over_200_mrad} of ${nLinks} sample links carried that flag. MathWorks' Longley-Rice returns 287.30 dB on the same profile, which rules out a porting error.`, fn("MathWorks, propagationModel (Antenna Toolbox) documentation, Longley-Rice model.", "https://www.mathworks.com/help/antenna/ref/propagationmodel.html")));

// ===== Diffraction deep dive
body.push(H1("Why ITM's diffraction loss is higher"));
body.push(P("The diffraction gap is the largest difference in this paper and the one most likely to change an analysis result, so this section takes ITM's diffraction loss apart. The calculation recomputes ITM's terms with ITM's own equations on every real-terrain diffraction link, checks that they reproduce ITM's reference attenuation to 10⁻⁹ dB, and compares them with the delta-Bullington terms of P.452 on the same profile."));
body.push(H2("The terms"));
body.push(P(`${FN("fig14")} shows the terms. Three features stand out:`));
body.push(B({ b: "Two edges instead of one. " }, `ITM's knife-edge term A_k adds a Fresnel loss at each horizon, and each edge sees the full bending angle θ = d/aₑ − θ_los. Delta-Bullington builds one equivalent edge. On double-horizon paths, ITM's A_k at d₃ is typically well above P.452's Bullington loss on the same profile (left panel).`));
body.push(B({ b: "Little weight on smooth earth. " }, `The weight w falls as Δh·f grows. On these links the median w at 2.7 GHz is ${R2(DM(2700, (r) => r.w_d3))}, so the knife-edge term carries most of the loss (center panel). At 7.25 GHz the median w is ${R2(DM(7250, (r) => r.w_d3))}.`));
body.push(B({ b: "A clutter term. " }, `A_fo adds a median ${R1(DM(2700, (r) => r.A_fo))} dB at 2.7 GHz and ${R1(DM(7250, (r) => r.A_fo))} dB at 7.25 GHz. Delta-Bullington has no counterpart; P.452 treats clutter separately, through its ground-cover heights.`));
body.push(P(`ITM evaluates these terms at d₃ and d₄, both beyond the horizon distances, and extends the line through them toward the path. On ${fracLosRegion(2700)} diffraction links at 2.7 GHz the path is shorter than ITM's smooth-earth horizon distance d_sML, so ITM doesn't use the line at the path directly: it interpolates between its two-ray line-of-sight loss and the line's value at d_sML. That interpolation lowers ITM's loss below its value at d₃, which is the negative light-gray bar in the right panel. Even so, the knife-edge and clutter terms carried into the interpolation keep ITM's loss far above delta-Bullington's.`));
body.push(...fig("fig14", "fig14_diffraction_terms.png", "ITM's diffraction terms on the real-terrain diffraction links. Left: ITM's double knife edge A_k at d₃ against P.452's Bullington loss on the actual profile. Center: ITM's smooth-earth weight w against Δh. Right: median terms by frequency, ITM (left bar) and P.452 (right bar)."));
body.push(H2("Removing one ingredient at a time"));
body.push(P(`${FN("fig15")} removes ITM's ingredients one at a time and reports the median gap between ITM's reference attenuation and P.452's diffraction loss. At 2.7 GHz the median gap is ${AB(2700, "ITM as is")} dB as ITM stands. Using one edge instead of two leaves ${AB(2700, "1 single edge")} dB; removing the clutter term leaves ${AB(2700, "2 no clutter term")} dB; evaluating A_d at the path instead of through the d₃-d₄ line leaves ${AB(2700, "3 evaluated at the path")} dB; and all three together leave ${AB(2700, "4 all three")} dB. At 7.25 GHz the corresponding values are ${AB(7250, "ITM as is")} dB, ${AB(7250, "1 single edge")} dB, ${AB(7250, "2 no clutter term")} dB, ${AB(7250, "3 evaluated at the path")} dB, and ${AB(7250, "4 all three")} dB.`));
body.push(...fig("fig15", "fig15_diffraction_ablation.png", "Median of ITM's reference attenuation minus P.452's diffraction loss, as ITM stands and with one ingredient removed at a time."));
body.push(P(`The double knife edge is the largest single ingredient: it accounts for about ${typeof ab(2700, "ITM as is") === "number" ? r0(ab(2700, "ITM as is") - ab(2700, "1 single edge")) : PEND} dB of the ${AB(2700, "ITM as is")} dB median gap at 2.7 GHz and about ${typeof ab(7250, "ITM as is") === "number" ? r0(ab(7250, "ITM as is") - ab(7250, "1 single edge")) : PEND} dB of ${AB(7250, "ITM as is")} dB at 7.25 GHz. The clutter term accounts for about 12 dB to 15 dB. With all three removed, ITM falls below delta-Bullington by a few dB, so the three ingredients more than explain the gap.`));
body.push(P("These changes are diagnostic, not proposed fixes: ITM's terms were fitted to measurements as a set, and removing one changes how the others fit. The point is to locate where the models part ways, so that measurements can test those specific terms."));

// ===== Distribution
body.push(H1("Results over the time distribution"));
body.push(P(`${FN("fig05")} shows the loss over the time distribution on five archetype paths at 2.7 GHz, with ITM's 10% to 90% confidence band, and ${FN("fig18")} summarizes the values at 50% and 1% of time and the spread. Three patterns stand out:`));
body.push(B({ b: "Low tail. " }, `On the troposcatter and over-sea paths the ITU models fall steeply below about 10% of time, where ducting takes over. At 1% of time on the ${r0(sea.length_km)} km over-sea path, P.2001 predicts ${r1(sea.p2001_1)} dB, ${r1(seaFsl - sea.p2001_1)} dB below free-space loss; ITM predicts ${r1(sea.itm_1)} dB.`));
body.push(B({ b: "Spread. " }, `ITM's spread from 1% to 99% is ${r1(los.itm_spread_1_99)} dB on the line-of-sight path and ${r1(tro.itm_spread_1_99)} dB on the troposcatter path; P.2001's spreads are ${r1(los.p2001_spread_1_99)} dB and ${r1(tro.p2001_spread_1_99)} dB.`));
body.push(B({ b: "High tail. " }, "On the line-of-sight path P.2001 rises steeply above 99% of time from clear-air and rain fading; ITM's curve stays nearly flat."));
body.push(...fig("fig05", "fig05_full_distribution_archetypes.png", "Basic transmission loss against time percentage on five archetype paths at 2.7 GHz. The shaded band is ITM's 10% to 90% confidence range. The last panel shows each curve minus its 50% value."));
body.push(...fig("fig18", "fig18_archetype_summary.png", "Archetype paths at 2.7 GHz: loss at 50% and 1% of time, and the spread from 1% to 99%."));
body.push(H2("Which mechanism dominates"));
body.push(P(`${FN("fig04")} maps the dominant P.2001 and P.452 sub-model over distance and time percentage on smooth earth, with ITM's regime as a strip at the top, and ${FN("fig06")} shows the dominant P.2001 sub-model along the distribution for each archetype path.`));
body.push(...fig("fig04", "fig04_mechanism_maps.png", "Dominant mechanism of P.2001 and P.452 over distance and time percentage, flat land and flat sea, 2.7 GHz. The top strip shows ITM's regime."));
body.push(...fig("fig06", "fig06_p2001_dominant_mechanism_by_percentage.png", "Dominant P.2001 sub-model against time percentage for each archetype path and calculation frequency."));
body.push(H2("Across all real-terrain links"));
body.push(P(`Over all ${nLinks} links at 2.7 GHz, the median P.2001 minus ITM difference is ${r1(byp27(0.01).p2001_minus_itm_med_db)} dB at 0.01% of time, ${r1(byp27(1).p2001_minus_itm_med_db)} dB at 1%, ${r1(byp27(50).p2001_minus_itm_med_db)} dB at 50%, and ${r1(byp27(99.9).p2001_minus_itm_med_db)} dB at 99.9% (${FN("fig17")}).`));
body.push(...fig("fig17", "fig17_median_gap_vs_time.png", "Median difference from ITM over all real-terrain links against time percentage. P.452 is defined only up to 50%."));

// ===== Measured
body.push(H1("Comparison with measured U.S. paths"));
body.push(H2("The data"));
body.push(P("The only public U.S. path-loss measurements found that give everything a point-to-point model needs (site coordinates, antenna heights, frequency, and a long-term loss distribution) are the ITS compilation by Longley, Reasoner, and Fuller in OT/TRER 16.", fn("A. G. Longley, R. K. Reasoner, and V. L. Fuller, Measured and Predicted Long-Term Distributions of Tropospheric Transmission Loss, OT/TRER 16, Office of Telecommunications, July 1971.", "https://its.ntia.gov/publications/download/OT-TRER-16.pdf"), " Its Table 1 lists site coordinates and its Table 2 lists path parameters and the measured basic transmission loss not exceeded for 1%, 10%, 50%, 90%, and 99% of the hourly medians."));
body.push(P(`This paper uses every U.S. path from 1 GHz to 10 GHz in that report that has site coordinates: ${nTrer} paths from 1,040 MHz to 9,361 MHz, measured from 1952 to 1964 (${FN("fig16")}). The values were read from the page images, not from the report's OCR text, which has errors. On ${nListed} paths, the great-circle distance between the listed coordinates matches the listed path length within 0.2%, which checks the coordinates. The other seven, over the sea between Santa Barbara or Point Mugu and Point Loma, California, give coordinates only to the arcminute, give only the median, and list no antenna heights; this paper assumes 10 m and reports them separately. The curated table is data/trer16_us_paths.csv in the matlab_itm repository.`));
body.push(...fig("fig16", "fig16_trer16_path_map.png", "The measured U.S. paths from OT/TRER 16, colored by frequency group."));
body.push(P("The data have three limits:"));
body.push(B({ b: "Frequency gaps. " }, "From 2 GHz to 5 GHz there are 2,820 MHz paths from Moorestown, New Jersey, to Aberdeen, Maryland (118 km) and Sterling, Virginia (248 km); a 2,800 MHz path from Rochester to Ithaca, New York (107 km); a 2,345 MHz path in southern Arizona (168 km); and 4,110 MHz paths from Pharsalia, New York, to Crawfords Hill, New Jersey (275 km). Nothing lies between 4.1 GHz and 9.1 GHz."));
body.push(B({ b: "Path types. " }, "Most paths are long, beyond-horizon links from 80 km to 635 km with low receiving antennas, in Colorado, Kansas, and the Northeast. They test diffraction and troposcatter more than short-range clutter."));
body.push(B({ b: "Age and record length. " }, "The measurements are 60 to 70 years old, and some records are only a few hundred hours long, so the 1% and 99% values carry more uncertainty than the median."));
body.push(P("Other public sources were checked and don't meet the need: recent ITS troposcatter work at 3.475 GHz in Colorado reports results but not a public dataset;", fn("A. C. Hicks, J. McLean, and J. D. Ewan, Preliminary Mid-Band Troposcatter Measurement Results Using Different High-Gain Receiver Antennas, USNC-URSI National Radio Science Meeting, Boulder, Colorado, January 2024.", "https://its.ntia.gov/publications/details?pub=4483"), fn("A. C. Hicks, J. D. Ewan, W. Kozma Jr., and M. G. Cotton, Measuring Tropospheric Propagation in the 21st Century, Proc. IEEE International Symposium on EMC, SI & PI, Spokane, Washington, August 2022, pp. 198-203.", "https://its.ntia.gov/publications/details?pub=3285"), " NIST measurements at 4.9 GHz and 7 GHz are short urban links dominated by clutter;", fn("D. W. Matolak, K. A. Remley, C. Gentile, C. L. Holloway, Q. Wu, and Q. Zhang, Ground-Based Urban Channel Characteristics for Two Public Safety Frequency Bands, NIST.", "https://www.nist.gov/system/files/documents/itl/antd/Ground-Based-Urban-Channel-Characteristics-for-Two-Public-Safety-Frequency-Bands.pdf"), fn("T. T. Nguyen, N. Yoza Mitsuishi, and R. Caromi, Deep Learning for Path Loss Prediction at 7 GHz in Urban Environment, IEEE Access, 2023, doi:10.1109/ACCESS.2023.3264230."), " NTIA Report TR-22-561 is at 37 GHz;", fn("NTIA Report TR-22-561, Outdoor Propagation Measurements.", "https://www.its.ntia.gov/publications/download/TR-22-561.pdf"), " and the ITU-R Study Group 3 databank is not U.S.-specific.", fn("ITU-R Study Group 3 databanks (DBSG3).", "https://www.itu.int/oth/R0A04/en")));
body.push(H2("Results"));
body.push(P(`${FN("fig12")} shows each model's error in the median, path by path; a positive error means the model predicts more loss than was measured. Over the ${nListed} paths with listed heights, the mean error at 50% of time is ${S1(ALL, "ITM v1.4", 50, "mean_error_db")} dB for ITM, ${S1(ALL, "P.452-18", 50, "mean_error_db")} dB for P.452, and ${S1(ALL, "P.2001-6", 50, "mean_error_db")} dB for P.2001, and the RMS error is ${S1(ALL, "ITM v1.4", 50, "rms_error_db")} dB, ${S1(ALL, "P.452-18", 50, "rms_error_db")} dB, and ${S1(ALL, "P.2001-6", 50, "rms_error_db")} dB. For reference, the 1967 NBS Technical Note 101 method, an ancestor of ITM, has an RMS error of ${S1(ALL, "TN 101 (1967)", 50, "rms_error_db")} dB on the same paths, from the predictions printed in the report. On this set, which is mostly troposcatter and line of sight over gentle terrain, the three models perform about equally well at the median.`));
body.push(P(`On the paths from 2.3 GHz to 2.8 GHz, the mean errors at 50% are ${S1(G27, "ITM v1.4", 50, "mean_error_db")} dB (ITM), ${S1(G27, "P.452-18", 50, "mean_error_db")} dB (P.452), and ${S1(G27, "P.2001-6", 50, "mean_error_db")} dB (P.2001). On the 3.4 GHz to 4.1 GHz paths they are ${S1(G4, "ITM v1.4", 50, "mean_error_db")} dB, ${S1(G4, "P.452-18", 50, "mean_error_db")} dB, and ${S1(G4, "P.2001-6", 50, "mean_error_db")} dB, and on the 9.1 GHz to 9.4 GHz paths ${S1(G9, "ITM v1.4", 50, "mean_error_db")} dB, ${S1(G9, "P.452-18", 50, "mean_error_db")} dB, and ${S1(G9, "P.2001-6", 50, "mean_error_db")} dB. On the seven California over-sea paths with assumed heights, the mean errors are ${S1(GCA, "ITM v1.4", 50, "mean_error_db")} dB, ${S1(GCA, "P.452-18", 50, "mean_error_db")} dB, and ${S1(GCA, "P.2001-6", 50, "mean_error_db")} dB.`));
body.push(...fig("fig12", "fig12_trer16_median_error.png", "Predicted minus measured median basic transmission loss on each measured path, sorted by frequency and distance. Paths to the right of the dashed line have assumed antenna heights."));
body.push(P(`The paths with the largest model differences are the rough-terrain ones (${FN("fig20")}). On the Beulah to Table Mesa, Colorado, path (9,200 MHz, 224 km, Δh = ${DH("321")} m), ITM's median error is ${E("321", "itm")} dB, while P.452 and P.2001 are within ${E("321", "p452")} dB and ${E("321", "p2001")} dB; this is the diffraction gap of the mid-Atlantic sample, and the measurement sides with the ITU models. On the Eloy to Blacktail Canyon, Arizona, path (2,345 MHz, 168 km, Δh = ${DH("1712")} m) the result reverses: ITM's error is ${E("1712", "itm")} dB, and P.452 and P.2001 predict ${E("1712", "p452")} dB and ${E("1712", "p2001")} dB too little loss. The reverse path at 1,705 MHz gives the same split. Two paths can't settle the question, but they show that neither model is right everywhere on rough terrain, which is why more rough-terrain measurements are the first priority.`));
body.push(...fig("fig20", "fig20_trer16_error_vs_delta_h.png", "Predicted minus measured median against ITM's terrain irregularity Δh on the paths with listed antenna heights. Filled markers are beyond line of sight."));
body.push(P(`${FN("fig13")} compares the whole distribution on six paths from 2.3 GHz to 4.1 GHz. At 1% of time over the ${nListed} paths, the mean errors are ${S1(ALL, "ITM v1.4", 1, "mean_error_db")} dB for ITM, ${S1(ALL, "P.452-18", 1, "mean_error_db")} dB for P.452, and ${S1(ALL, "P.2001-6", 1, "mean_error_db")} dB for P.2001; at 99% they are ${S1(ALL, "ITM v1.4", 99, "mean_error_db")} dB for ITM and ${S1(ALL, "P.2001-6", 99, "mean_error_db")} dB for P.2001. The full table by path is table_trer16_by_path.csv, and the error summary by group and percentage is table_trer16_summary.csv.`));
body.push(...fig("fig13", "fig13_trer16_distributions.png", "Measured and predicted distributions of basic transmission loss on six measured paths from 2.3 GHz to 4.1 GHz."));
body.push(P("These comparisons test the models against 1950s and 1960s measurements on mostly long paths in two regions. They can show whether a model is biased on such paths; they can't settle which model is right for the short, rough-terrain paths in the mid-Atlantic sample or for frequencies from 4.1 GHz to 9.1 GHz, where no data exist."));

// ===== Distance
body.push(H1("What the differences mean in distance"));
body.push(P(`On smooth earth the differences barely move a separation distance: for thresholds from 150 dB to 180 dB, the three models reach the threshold within a few kilometers of each other (${FN("fig08")}), because the steep diffraction slope beyond the radio horizon makes distance insensitive to a few dB.`));
body.push(...fig("fig08", "fig08_distance_to_threshold_smooth_earth.png", "Distance at which the 50% loss first reaches each threshold on flat land."));
body.push(P(`Over real terrain the picture changes (${FN("fig11")}). Along four radials from a piedmont site, ITM's higher diffraction loss lets it reach a threshold at shorter distances where terrain blocks the path, so ITM gives smaller protection distances there. The radial distances are in table_radial_distance_to_threshold.csv.`));
body.push(...fig("fig11", "fig11_radial_loss_vs_distance.png", "Loss along four radials from 38.90° N, 77.45° W at 2.7 GHz and 50% of time, with free-space loss for reference."));

// ===== Implications
body.push(H1("What the comparison means for analyses"));
body.push(P("These points are preliminary and follow from the calculations above:"));
body.push(B({ b: "Line of sight: the choice of model matters little. " }, "At the median the three models agree within a fraction of a dB on line-of-sight links from 2.7 GHz to 7.25 GHz."));
body.push(B({ b: "Diffraction over rough terrain: the choice matters most, and more at higher frequencies. " }, `The median gap between ITM and the ITU models grows from about ${r0(-d27.p2001_minus_itm_med_db)} dB at 2.7 GHz to about ${r0(-d49.p2001_minus_itm_med_db)} dB at 4.9 GHz and ${r0(-d72.p2001_minus_itm_med_db)} dB at 7.25 GHz. An analysis that uses ITM on rough terrain computes smaller separation distances at the median than one that uses P.452 or P.2001.`));
body.push(B({ b: "Small time percentages: the choice matters through ducting. " }, "The ITU models' ducting term gives much less loss than ITM at 1% of time and below, so an analysis that uses them computes larger separation distances at those percentages, especially over water and on long paths."));
body.push(B({ b: "Measurements near 2.3 GHz to 2.8 GHz favor caution in both directions. " }, `On five measured paths, all three models predict less loss than was measured, by a mean of ${S1(G27, "ITM v1.4", 50, "mean_error_db").replace("-", "")} dB to ${S1(G27, "P.452-18", 50, "mean_error_db").replace("-", "")} dB at the median, and at 1% of time the ITU models predict about ${S1(G27, "P.2001-6", 1, "mean_error_db").replace("-", "")} dB too little loss on average, on three paths. If that holds up, analyses with the ITU models overstate interference at small time percentages near these frequencies.`));
body.push(P("The differences are large enough to change an analysis outcome, so the model choice should be stated, justified, and tested for sensitivity."));

// ===== Look deeper
body.push(H1("Where to look deeper"));
body.push(P("These calculations point to the following questions, in priority order:"));
startList();
body.push(N({ b: "Which diffraction prediction is right over rough terrain from 1 GHz to 10 GHz? " }, "The gap is 30 dB to 48 dB at the median on diffraction links and grows with frequency. The decomposition points to three testable ITM ingredients: the double knife edge, the clutter term, and the extended diffraction line. Measurements on rough-terrain diffraction paths across the range would test them directly."));
body.push(N({ b: "Should NTIA measure between 4.1 GHz and 9.1 GHz? " }, "No public U.S. data exist there. A short campaign on a few diffraction and troposcatter paths, such as ITS's Table Mountain capability already supports at 3.475 GHz, would anchor the comparison across the upper half of the range."));
body.push(N({ b: "Do aggregate-interference results depend on ducting? " }, "The ITU models predict about 20 dB less loss than ITM at 0.01% to 1% of time on the real-terrain sample, from a mechanism ITM lacks."));
body.push(N({ b: "How should analyses treat ITM on steep horizons? " }, `ITM flagged horizon angles above 200 mrad on ${flags.links_with_horizon_angle_over_200_mrad} of ${nLinks} links. Analyses that use ITM should decide whether to exclude, cap, or replace such links, and record the flag.`));
body.push(N({ b: "Do availability results depend on fading? " }, "P.2001's high tail includes rain and clear-air fading that ITM and P.452 omit."));
body.push(N({ b: "How large are the regional effects? " }, "The real-terrain sample covers three mid-Atlantic regions. Western terrain may change the size of the gap."));
body.push(N({ b: "How much does ground cover change P.452? " }, "P.452-18 can take a ground-cover profile, which can move its loss by several dB."));

// ===== Limitations
body.push(H1("Limitations"));
body.push(B(`The real-terrain sample is small: ${nLinks} links in three mid-Atlantic regions and five archetype paths.`));
body.push(B("The measured paths are old, mostly long, and absent between 4.1 GHz and 9.1 GHz. Seven of them have assumed antenna heights."));
body.push(B("Each model ran with defaults this paper chose (ITM ground constants, variability mode 13, 50% confidence, no P.452 clutter). Other choices change the results."));
body.push(B("The knife-edge test uses a single raised profile point; treat it as a coarse check."));
body.push(B("All results are basic transmission loss with isotropic antennas. Clutter, building entry loss, and antenna patterns are not included."));

// ===== References
body.push(new Paragraph({ children: [new PageBreak()] }));
body.push(H1("References"));
const REFS = [
  "A. G. Longley and P. L. Rice, Prediction of Tropospheric Radio Transmission Loss over Irregular Terrain: A Computer Method-1968, ESSA Technical Report ERL 79-ITS 67, 1968.",
  "P. L. Rice, A. G. Longley, K. A. Norton, and A. P. Barsis, Transmission Loss Predictions for Tropospheric Communication Circuits, NBS Technical Note 101, revised 1967.",
  "A. G. Longley, R. K. Reasoner, and V. L. Fuller, Measured and Predicted Long-Term Distributions of Tropospheric Transmission Loss, OT/TRER 16, Office of Telecommunications, July 1971. https://its.ntia.gov/publications/download/OT-TRER-16.pdf",
  "NTIA Institute for Telecommunication Sciences, Irregular Terrain Model (ITM), version 1.4, C++ source. https://github.com/NTIA/itm",
  "Recommendation ITU-R P.2001-6, A general purpose wide-range terrestrial propagation model in the frequency range 30 MHz to 50 GHz.",
  "Recommendation ITU-R P.452-18, Prediction procedure for the evaluation of interference between stations on the surface of the Earth at frequencies above about 0.1 GHz.",
  "Recommendation ITU-R P.526-15, Propagation by diffraction.",
  "Recommendation ITU-R P.617, Propagation prediction techniques and data required for the design of trans-horizon radio-relay systems.",
  "Wireless Innovation Forum, Requirements for Commercial Operation in the U.S. 3550-3700 MHz Citizens Broadband Radio Service Band, WINNF-TS-0112.",
  "A. C. Hicks, J. D. Ewan, W. Kozma Jr., and M. G. Cotton, Measuring Tropospheric Propagation in the 21st Century, Proc. 2022 IEEE International Symposium on Electromagnetic Compatibility, Signal & Power Integrity, Spokane, Washington, August 2022, pp. 198-203. https://its.ntia.gov/publications/details?pub=3285",
  "A. C. Hicks, J. McLean, and J. D. Ewan, Preliminary Mid-Band Troposcatter Measurement Results Using Different High-Gain Receiver Antennas, 2024 USNC-URSI National Radio Science Meeting, Boulder, Colorado, January 2024, pp. 225-226. https://its.ntia.gov/publications/details?pub=4483",
  "D. W. Matolak, K. A. Remley, C. Gentile, C. L. Holloway, Q. Wu, and Q. Zhang, Ground-Based Urban Channel Characteristics for Two Public Safety Frequency Bands, NIST. https://www.nist.gov/system/files/documents/itl/antd/Ground-Based-Urban-Channel-Characteristics-for-Two-Public-Safety-Frequency-Bands.pdf",
  "T. T. Nguyen, N. Yoza Mitsuishi, and R. Caromi, Deep Learning for Path Loss Prediction at 7 GHz in Urban Environment, IEEE Access, 2023. doi:10.1109/ACCESS.2023.3264230",
  "NTIA Report TR-22-561, Outdoor Propagation Measurements. https://www.its.ntia.gov/publications/download/TR-22-561.pdf",
  "ITU-R Study Group 3 databanks (DBSG3). https://www.itu.int/oth/R0A04/en",
  "MathWorks, propagationModel, Antenna Toolbox documentation. https://www.mathworks.com/help/antenna/ref/propagationmodel.html",
  "U.S. Geological Survey, 3D Elevation Program (3DEP), 1 arc-second digital elevation models.",
];
startList();
REFS.forEach((r) => body.push(N(r)));

// ===== Appendix
body.push(H1("Appendix: reproducing the figures"));
body.push(P("Every figure comes from MATLAB code in the matlab_itm repository, folder docs/model_comparison. To reproduce them, do the following:"));
startList();
body.push(N("Clone matlab_itm, itu_p2001, and matlab_itu_p452 into one folder."));
body.push(N("In MATLAB R2025b with Mapping Toolbox, add docs/model_comparison to the path and run, in order: make_wp_figures_rev1, make_wp_summary_figures_rev1, compare_trer16_rev1, and diffraction_decomposition_rev1."));
body.push(N("Run node build_wp_docx_rev2.js in docs/model_comparison to rebuild this document from the figures and CSV tables."));
body.push(P("The model code cited in the footnotes is pinned to these commits:"));
body.push(B({ b: "matlab_itm: " }, SHA.itm));
body.push(B({ b: "itu_p2001: " }, SHA.p2001));
body.push(B({ b: "matlab_itu_p452: " }, SHA.p452));
body.push(P("The measured-path data are data/trer16_us_paths.csv, read from OT/TRER 16 (data/sources/OT-TRER-16.pdf, public domain)."));

// ---------- assemble ----------
const markRun = () => new TextRun({ text: MARK, bold: true, font: FONT, size: 18 });
const doc = new Document({
  creator: "NTIA working paper draft",
  title: TITLE,
  styles: {
    default: { document: { run: { font: FONT, size: 22 } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 30, bold: true, font: FONT, color: "1F3864" }, paragraph: { spacing: { before: 320, after: 140 }, keepNext: true, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 25, bold: true, font: FONT, color: "2F5496" }, paragraph: { spacing: { before: 220, after: 100 }, keepNext: true, outlineLevel: 1 } },
    ],
  },
  numbering: { config: [
    { reference: "bullets", levels: [{ level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
    { reference: "numbers", levels: [{ level: 0, format: LevelFormat.DECIMAL, text: "%1.", alignment: AlignmentType.LEFT, style: { paragraph: { indent: { left: 720, hanging: 360 } } } }] },
  ] },
  footnotes,
  sections: [{
    properties: { page: { size: { width: 12240, height: 15840 }, margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 } } },
    headers: { default: new Header({ children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [markRun()] })] }) },
    footers: { default: new Footer({ children: [
      new Paragraph({ alignment: AlignmentType.CENTER, children: [markRun()] }),
      new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ children: ["Page ", PageNumber.CURRENT], font: FONT, size: 18 })] })] }) },
    children: body,
  }],
});
Packer.toBuffer(doc).then((b) => { fs.writeFileSync(OUT, b); console.log("Wrote " + OUT); });
