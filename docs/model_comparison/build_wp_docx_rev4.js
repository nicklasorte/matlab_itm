// Builds the 3 GHz working paper (revision 4, .docx) from the figures and CSV
// tables that run_3ghz_rev1 (MATLAB), compare_dbsg3_rev1, and the Python
// scripts make_wp_figures_3ghz.py and make_wp_body_figures_rev1.py write. Every number in a table, and the numbers
// in the text marked with ${...}, come from those CSV files, so the paper
// and the MATLAB output can't drift apart.
//
//   node build_wp_docx_rev4.js [figures_dir] [output.docx]
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
const OUT = process.argv[3] || path.join(__dirname, "itm_p2001_p452_comparison_working_paper_rev4.docx");
const MARK = "DRAFT//PRE-DECISIONAL";
const SHA = {
  itm: "03feac58ae3db28c2ae66226ae73109e61172a98",
  p2001: "286e68cbac94d616261f9cb514e94ec8f5464881",
  p452: "75e39de3a3177c95d40a38a1c0a2659a0ee8b28a",
  itm2: "5081c685bf29aaa08e3a98e6d73c764ab9753eae",
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
const NU = JSON.parse(fs.readFileSync(path.join(FIG, "numbers_3ghz.json"), "utf8"));
const r1 = (x) => (typeof x === "number" ? (Math.round(x * 10) / 10).toFixed(1) : x);
const r0 = (x) => (typeof x === "number" ? String(Math.round(x)) : x);
const r2 = (x) => (typeof x === "number" ? (Math.round(x * 100) / 100).toFixed(2) : x);
const get = (rows, f, c) => rows.find((r) => r.freq_mhz === f && r.itm_class === c);
const A = (name, f) => arch.find((r) => r.path === name && r.freq_mhz === f);
const nLinks = flags.links;
const nDif = cls.find((r) => r.itm_class === "Diffraction").links;

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
const p452Core = (a, b) => `https://github.com/nicklasorte/matlab_itu_p452/blob/d578e5aa9c942d8cc0cd4cc4b3d15b5649c828eb/private/p452_core.m#L${a}-L${b}`;
const itm2Url = (a, b) => `https://github.com/nicklasorte/matlab_itm/blob/${SHA.itm2}/private/itm_p2p_core.m#L${a}-L${b}`;
const REC = "https://www.itu.int/rec/R-REC-P.2001-6-202509-I/en";
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
    const w = Math.min(624, Math.round(s.w / 220 * 96)); // native size at 220 dpi, at most 6.5 in
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
// Inline markdown: **bold** and `code`
function mdRuns(text, bold = false, size = 18) {
  return text.split(/(\*\*[^*]+\*\*|`[^`]+`)/).filter(Boolean).map((t) => {
    if (t.startsWith("**")) return new TextRun({ text: t.slice(2, -2), bold: true, font: FONT, size });
    if (t.startsWith("`")) return new TextRun({ text: t.slice(1, -1), font: "Courier New", size: size - 1 });
    return new TextRun({ text: t, bold, font: FONT, size });
  });
}
// Renders ALGORITHM_COMPARISON_PLAN.md (the tracked copy of the plan) into the body
function planSection(file) {
  const out = [];
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const widths = { 8: [450, 1000, 1800, 1800, 700, 1200, 1500, 910], 6: [450, 1400, 1800, 2350, 2350, 1010], 4: [1500, 1600, 3000, 3260] };
  let i = 0, para = [], inList = false;
  const flush = () => { if (para.length) { out.push(new Paragraph({ children: mdRuns(para.join(" "), false, 20), spacing: { after: 120, line: 276 } })); para = []; } };
  while (i < lines.length) {
    const L = lines[i];
    if (L.startsWith("# ")) { i += 1; continue; }                       // the markdown title; the paper has its own
    if (L.startsWith("## ")) { flush(); out.push(H2(L.slice(3).replace(/^\d+\.\s*/, ""))); i += 1; continue; }
    if (L.startsWith("|")) {
      flush();
      const rows = [];
      while (i < lines.length && lines[i].startsWith("|")) { rows.push(lines[i].slice(1, -1).split("|").map((c) => c.trim())); i += 1; }
      const header = rows[0], body = rows.slice(2);
      const w = widths[header.length];
      const cap = header.length === 8 ? "The equation ledger: one row per step of the loss calculation." :
        header.length === 6 ? "Experiments that isolate one equation at a time." : "Figure plan for the equation-by-equation comparison.";
      out.push(...table(cap, header, body, w, header.length === 8 ? 15 : 16));
      continue;
    }
    if (/^- /.test(L)) { flush(); const item = [L.slice(2)]; i += 1; while (i < lines.length && /^  \S/.test(lines[i])) { item.push(lines[i].trim()); i += 1; }
      out.push(new Paragraph({ numbering: { reference: "bullets", level: 0 }, children: mdRuns(item.join(" "), false, 20), spacing: { after: 60 } })); continue; }
    if (/^\d+\. /.test(L)) { flush(); if (!inList) { startList(); inList = true; } const item = [L.replace(/^\d+\. /, "")]; i += 1; while (i < lines.length && /^   \S/.test(lines[i])) { item.push(lines[i].trim()); i += 1; }
      out.push(new Paragraph({ numbering: { reference: "numbers", level: 0, instance: listNo }, children: mdRuns(item.join(" "), false, 20), spacing: { after: 60 } })); continue; }
    if (L.trim() === "") { flush(); inList = false; i += 1; continue; }
    para.push(L.trim()); i += 1;
  }
  flush();
  return out;
}
let tabN = 0;
const border = { style: BorderStyle.SINGLE, size: 4, color: "999999" };
const borders = { top: border, bottom: border, left: border, right: border };
function table(caption, header, rows, widths, size = 18) {
  tabN += 1;
  const total = widths.reduce((a, b) => a + b, 0);
  const cell = (t, i, head) => new TableCell({
    borders, width: { size: widths[i], type: WidthType.DXA },
    shading: head ? { fill: "D9E2F3", type: ShadingType.CLEAR, color: "auto" } : undefined,
    margins: { top: 60, bottom: 60, left: 100, right: 100 },
    children: [new Paragraph({ children: mdRuns(String(t), !!head, size) })],
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
const ORDER = ["s38", "s39", "s41", "s40", "s42", "s43", "s44", "s45", "s46", "s47", "s48", "s49", "s50", "s51", "s01", "s02", "s04", "s05", "s06", "s07", "s03", "s08", "s09", "s16", "s13", "s10", "s11", "s12", "s14", "s35",
  "s21", "s15", "s17", "s18", "s19", "s20", "fig25", "fig30", "s23", "s24", "s25", "s31", "s33", "s34", "s37", "s26", "s27", "s28", "s22", "s29", "s30", "s32", "s36"];
const FN = (k) => `Figure ${ORDER.indexOf(k) + 1}`;
function fig(key, file, caption) {
  figN = ORDER.indexOf(key);                    // figure() adds 1
  return figure(file, caption);
}

// ---------- numbers ----------
const PEND = "[pending]";
const n1 = (k) => (typeof NU[k] === "number" ? r1(NU[k]) : PEND);
const n0 = (k) => (typeof NU[k] === "number" ? r0(NU[k]) : PEND);
const g = (c) => n0(`gap_${c}`);
const A0 = (k, i) => (Array.isArray(NU[k]) ? r0(NU[k][i]) : PEND);
const A1 = (k, i) => (Array.isArray(NU[k]) ? r1(NU[k][i]) : PEND);
const Z0 = (x) => (Math.abs(x) < 0.5 ? "0" : r0(x));
const dbQ = opt("table_dbsg3_quality_survey.csv");
const dbS = opt("table_dbsg3_summary_survey.csv"), dbC = opt("table_dbsg3_terrain_comparison.csv");
const DBv = (gr, m, p, k) => { const r = dbS.find((x) => x.group === gr && x.model === m && x.percent === p); return r ? r[k] : NaN; };
const DB = (gr, m, p, k) => (isNaN(DBv(gr, m, p, k)) ? PEND : r1(DBv(gr, m, p, k)));
const DBn = (gr) => (isNaN(DBv(gr, "ITM v1.4", 50, "n")) ? PEND : String(DBv(gr, "ITM v1.4", 50, "n")));
const QN = (q, reason) => { const r = q.find((x) => x.reason === reason); return r ? String(r.datasets) : PEND; };
const TC = (m, k) => { const r = dbC.find((x) => x.model === m); return r ? r1(r[k]) : PEND; };
const TCn = () => (dbC.length ? String(dbC[0].n) : PEND);
const M3 = (gr, p, k) => `${DB(gr, "ITM v1.4", p, k)} dB for ITM, ${DB(gr, "P.452-18", p, k)} dB for P.452, and ${DB(gr, "P.2001-6", p, k)} dB for P.2001`;

// ---------- document ----------
const TITLE = "ITM, ITU-R P.2001, and ITU-R P.452 at 3 GHz: How the Models Compare";
const body = [];
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1200, after: 240 },
  children: [new TextRun({ text: TITLE, bold: true, size: 40, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "Working paper, revision 4 (draft)", size: 26, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "November 2026", size: 24, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
  children: [new TextRun({ text: "Preliminary calculations to show where deeper analysis is needed. Not for decisions.", italics: true, size: 22, font: FONT })] }));
body.push(new TableOfContents("Contents", { hyperlink: true, headingStyleRange: "1-2" }));
body.push(new Paragraph({ children: [new PageBreak()] }));

// ===== Summary
body.push(H1("Summary"));
body.push(P({ b: "Question. " }, "Terrestrial interference and coverage analyses use one of three common propagation models: the Irregular Terrain Model (ITM) version 1.4, Recommendation ITU-R P.2001-6, or Recommendation ITU-R P.452-18. This paper compares them at one frequency, 3 GHz, to show where they differ, why, and what public measurements say."));
body.push(P({ b: "Findings at 3 GHz, 50% of time:" }));
body.push(B({ b: "Line of sight: the models agree. " }, `On ${n0("n_Line of sight")} real-terrain line-of-sight links, ITM and P.2001 differ by a median of ${n1("gap_Line of sight")} dB.`));
body.push(B({ b: "Beyond the horizon: ITM predicts much more loss. " }, `The median gap is ${g("Diffraction")} dB on ${n0("n_Diffraction")} diffraction links and ${g("Troposcatter")} dB on ${n0("n_Troposcatter")} troposcatter links. P.2001 and P.452 agree within ${r2(NU.p2001_p452_maxmed)} dB at the median in every class.`));
body.push(B({ b: "The cause is ITM's diffraction method, not its knife-edge formula. " }, `ITM adds a knife-edge loss at each of the two horizons, adds a clutter term, and gives a small weight to a smooth-earth loss that can be very large. Removing all three cuts the median gap from ${n0("ab_ITM as is")} dB to ${n0("ab_4 all three")} dB.`));
body.push(B({ b: "The split is a jump inside a window. " }, `A link is either close (median ${n0("w_ge")} dB) or far apart (median ${n0("w_lt")} dB), depending on ITM's smooth-earth weight. The large gaps fall on rough-terrain paths from about 15 km to 150 km; on longer troposcatter paths the models agree again.`));
body.push(B({ b: "The gap is robust to ITM's settings, uncertain in size. " }, `No ITM setting tested closes it: on the diffraction links the median gap stays between ${A0("sens_gap_range", 0)} dB and ${A0("sens_gap_range", 1)} dB across ground constants, confidence, radio climate, N₀, and polarization. Its 95% bootstrap interval is ${A0("u_Diffraction_links", 1)} dB to ${A0("u_Diffraction_links", 2)} dB, because the 27 links fall into two groups.`));
body.push(B({ b: "Separation distance: the ITU models give larger exclusion areas. " }, `For a single transmitter 30 m high around a receiver 10 m high, at a required loss of 160 dB, P.2001 and P.452 exclude ${n0("grid_dc_p2001_160_area")} km² around Washington, DC, against ${n0("grid_dc_itm_160_area")} km² for ITM, and ${n0("grid_la_p2001_160_area")} km² against ${n0("grid_la_itm_160_area")} km² around Los Angeles.`));
body.push(B({ b: "Clutter at the receiver matters as much as the model. " }, `Adding Recommendation ITU-R P.2108 clutter loss (${n0("gclut_loss")} dB at the median) at the receiver cuts the 160 dB exclusion area around DC to ${A0("gclut_dc_itm_rx_p50_160", 0)} km² for ITM and ${A0("gclut_dc_p2001_rx_p50_160", 0)} km² for P.2001; the models differ again at larger required losses.`));
body.push(B({ b: "Ducting: the ITU models add it, ITM doesn't. " }, `On a ${n0("sea_len")} km over-sea path at 1% of time, ITM predicts ${n0("sea_itm_1")} dB and P.2001 ${n0("sea_p2001_1")} dB.`));
body.push(B({ b: "The models are built differently. " }, `ITM picks one mechanism by distance and adds a fixed variability curve; P.2001 computes every mechanism with its own statistics and combines them. Over smooth earth they agree within ${n1("alg_s50_maxabs")} dB at the median from 3 km to 700 km; they part where ITM extends its diffraction line from beyond the horizons (rough terrain) and where P.2001 adds ducting.`));
body.push(B({ b: "On synthetic ridges P.2001 is near the classical references and ITM isn't. " }, `For two equal 280 m ridges, Epstein-Peterson and Deygout give ${A0("fam2_eq280", 2)} dB and ${A0("fam2_eq280", 3)} dB above free space, P.2001 ${A0("fam2_eq280", 1)} dB, and ITM ${A0("fam2_eq280", 0)} dB; on synthetic rough terrain the gap follows roughness and reaches ${A0("fam21_dh1000", 1)} dB at 1,000 m.`));
body.push(B({ b: "Most of the diffraction gap is ITM's horizon-based terms. " }, `On the real diffraction links, ${A0("term_gap_edges", 0)} dB of a mean ${A0("term_gap_total", 0)} dB gap comes from ITM's knife edge at each horizon and ${A0("term_gap_smooth", 0)} dB from its smooth-earth term; the two models' smooth-earth formulas themselves agree within ${A1("term_se_horizontal", 1)} dB.`));
body.push(B({ b: "Western terrain widens the gap. " }, `On ${n0("west_n")} links drawn the same way in Colorado, Nevada, and southern California, where the median terrain irregularity is ${n0("west_dh_med")} m against ${n0("east_dh_med")} m in the east, ITM predicts a median of ${n0("west_gap_med")} dB more loss than P.2001, and ${n0("west_gt20")} of the ${n0("west_n")} links differ by more than 20 dB.`));
body.push(B({ b: "Rough-terrain measurements near 3 GHz fall between the models. " }, `On ITS spot measurements in the Colorado mountains beyond 15 km, ITM predicts a median of ${A0("its3_r2far_itm", 1)} dB too much loss and P.2001 ${A0("its3_r2far_p2001", 1).replace("-", "")} dB too little, counting paths where the signal was too weak to measure. On open Colorado sites overall, ITM is within ${n1("its3_colorado_open_itm").replace("-", "")} dB at the median and P.2001 predicts ${n1("its3_colorado_open_p2001").replace("-", "")} dB too little loss.`));
body.push(B({ b: "Measurements from 30 MHz to 10 GHz: all three are close at the median. " }, `On ${DBn("All")} measured datasets, the mean error in the median is ${M3("All", 50, "mean_error_db")}. Few measured paths fall in the window where the models split, and they point both ways: from 1 GHz to 10 GHz ITM predicts too much loss there and P.2001 is close, while below 1 GHz ITM is close and P.2001 predicts too little.`));

// ===== The question
body.push(H1("The question"));
body.push(P("Analyses of terrestrial interference and coverage turn a protection criterion into a separation distance, an exclusion zone, or a coordination zone, and the propagation model sets that distance. Analysts often treat ITM, P.2001, and P.452 as interchangeable, but the paths that usually decide a separation distance are beyond line of sight, where diffraction, troposcatter, and ducting set the loss. This paper asks three questions:"));
startList();
body.push(N("How much do the models differ at 3 GHz, and in which propagation mechanisms?"));
body.push(N("Why do they differ, equation by equation?"));
body.push(N("What do public measurements say about which model to trust?"));
body.push(P("All calculations use 3 GHz. One sweep from 100 MHz to 10 GHz shows how the gap changes with frequency, and the measurements span 30 MHz to 10 GHz because few datasets sit near 3 GHz alone."));

// ===== Models
body.push(H1("The three models"));
body.push(B({ b: "ITM v1.4" }, " (NTIA/ITS, 2019) is semi-empirical. Longley and Rice developed it in the 1960s from measured attenuation; it predicts a distribution of loss over time, locations, and situations.", fn("A. G. Longley and P. L. Rice, Prediction of Tropospheric Radio Transmission Loss over Irregular Terrain: A Computer Method-1968, ESSA Technical Report ERL 79-ITS 67, 1968."), " This paper uses matlab_itm, a line-by-line port of the NTIA C++ that matches it to 4 × 10⁻¹³ dB.", fn("NTIA/ITS, Irregular Terrain Model (ITM), version 1.4, C++ source.", "https://github.com/NTIA/itm")));
body.push(B({ b: "P.452-18" }, " (ITU-R, 2023) predicts interference between stations on the surface of the earth for 0.001% to 50% of time. This paper uses matlab_itu_p452, built from the ITU-R reference code."));
body.push(B({ b: "P.2001-6" }, " (ITU-R, 2025) covers 0% to 100% of time by combining four sub-models, including fading. This paper uses itu_p2001, which reproduces all 4,430 ITU validation cases."));
body.push(...table("Methods by mechanism.",
  ["Element", "ITM v1.4", "P.452-18", "P.2001-6"],
  [["Line of sight", "Two-ray model with ground reflection, blended with an extrapolated diffraction line", "Free space plus gases plus a multipath and focusing term", "Free space, diffraction, clear-air fading, rain fading, and gases"],
   ["Diffraction", "Weighted blend of a double knife edge at the two horizons and smooth-earth diffraction, plus a clutter term, extended to the path as a straight line", "Delta-Bullington: one equivalent knife edge on the profile, corrected by a smooth-earth term", "Delta-Bullington with median and time-dependent effective earth radii"],
   ["Troposcatter", "Rice et al. frequency-gain function and scattering angle", "Closed form with an explicit time-percentage term", "Parameters by climate zone; at least free space"],
   ["Ducting", "None; small-percentage loss comes from variability curves", "Ducting and layer reflection", "Ducting and layer reflection, and sporadic-E"],
   ["Combination", "One regime selected by distance, then variability added", "Power sum of the blended terms with troposcatter", "Power sum of four sub-models"]],
  [1500, 2620, 2620, 2620]));

// ===== Algorithm comparison: ITM and P.2001
body.push(H1("How ITM and P.2001 compute each mechanism"));
body.push(P("This section compares the algorithms of ITM and P.2001 one propagation mechanism at a time, in the manner of the ITS comparison of ITM and TIREM.", fn("ITS, A Comparison of the Algorithms Used in the ITM and TIREM Propagation Models (draft).", "https://github.com/nicklasorte/matlab_tirem/blob/main/A%20Comparison%20of%20the%20Algorithms%20Used%20in%20the%20ITM%20and%20TIREM%20Propagation%20Models.pdf"), " For each mechanism it gives what ITM does, what P.2001 does, and what the difference does to the loss. The ITM description follows matlab_itm, a port of the NTIA C++ code for version 1.4; the P.2001 description follows Recommendation ITU-R P.2001-6 (09/2025) and itu_p2001, a port of the ITU-R reference code.", fn("Recommendation ITU-R P.2001-6, A general purpose wide-range terrestrial propagation model in the frequency range 30 MHz to 50 GHz, 09/2025.", REC), " P.452 shares most of P.2001's diffraction and ducting methods, so most of what follows applies to it too. The figures come from algorithm_comparison_rev1, which runs both models on the same profiles at 3 GHz with a 30 m transmitting antenna and a 10 m receiving antenna, and reads ITM's internal construction from a diagnostic output added for this paper (info.lines)."));

body.push(H2("Two architectures"));
body.push(P(`The models are built differently (${FN("s38")}). ITM computes one reference attenuation, A_ref, the loss above free space at the median. It decides by distance which region the path is in (line of sight, diffraction, or troposcatter) and evaluates only that region's method, then adds a variability term for the time percentage.`, fn("ITM region selection and reference attenuation:", itm2Url(367, 484)), " P.2001 doesn't choose. It computes four end-to-end mechanisms in parallel, each with its own statistics over time: sub-model 1 (line of sight and diffraction, with clear-air fading and rain), sub-model 2 (ducting and layer reflection), sub-model 3 (troposcatter), and sub-model 4 (sporadic-E). Three more mechanisms (gaseous absorption, rain, and multipath or focusing) add loss to those paths rather than carrying a signal themselves.", fn("P.2001-6, sec. 4 and Attachment J.", REC)));
body.push(P("P.2001 combines the sub-models according to how their causes are correlated. Sub-models 1 and 2 are largely correlated, so their powers add at the same time percentage: L_bm12 = −10 log(10^(−0.1 L_bm1) + 10^(−0.1 L_bm2)). Troposcatter and sporadic-E are largely uncorrelated with them; the Recommendation says a correct combination needs the full distributions and a Monte Carlo method, and gives a simpler blend for a single time percentage: L_b = −5 log(10^(−0.2 L_bm12) + 10^(−0.2 L_bm3) + 10^(−0.2 L_bm4)).", fn("P.2001 combination, sec. 5.1 and 5.2, eqs. 58 and 59; itu_p2001:", p2001Url("p2001_profile_rev1.m", 392, 400)), " The lowest loss dominates, two equal losses combine to 1.5 dB below either, and a mechanism 10 dB weaker than the strongest changes the result by less than 0.5 dB. This paper, like most uses, uses the single-percentage blend."));
body.push(...fig("s38", "s38_architecture.png", "How each model builds its answer: ITM selects one region and adds a variability curve; P.2001 computes four sub-models, each with its own time statistics, and combines them."));

body.push(H2("Earth curvature and refraction"));
body.push(P("ITM takes a surface refractivity N_s, scales it to the path's mean elevation (N_s = N_0 exp(−h_s/9,460 m)), and sets the effective earth curvature γ_e = γ_a(1 − 0.04665 exp(N_s/179.3)), with γ_a the true curvature. That curvature is fixed: it is the same for every time percentage.", fn("ITM refractivity and curvature:", itm2Url(191, 208)), ` P.2001 reads the median refractivity gradient in the lowest 1 km, N_d1km50 (negative; P.452's ΔN with the sign reversed), from an ITU-R map at the path's midpoint and sets the median effective radius a_e50 = 157 a/(157 + N_d1km50). For other time percentages it moves the gradient along map-derived slopes and recomputes the radius, so its diffraction loss is recomputed at each time percentage on a differently curved earth.`, fn("P.2001-6, sec. 3.4.1 and 3.5, eqs. 9-13; itu_p2001:", p2001Url("p2001_profile_rev1.m", 201, 236)), ` On the smooth test path in central Kansas the median radii nearly match: ${n0("alg_ae_itm")} km for ITM and ${n0("alg_ae_p2001_50")} km for P.2001 (N_d1km50 = ${n1("alg_dn50")} N-units per km). At 1% of time P.2001's radius grows to ${n0("alg_ae_p2001_1")} km, so the horizon moves out and the diffraction loss falls; ITM's earth stays the same and its variability term does that job instead.`));

body.push(H2("Terrain analysis and effective heights"));
body.push(P("ITM reduces the profile to a few numbers: each terminal's horizon distance and elevation angle, the terrain irregularity Δh (the interdecile range of heights about a straight-line fit, starting the smaller of 15 antenna heights and a tenth of the horizon distance in from each end, corrected for the length of that span), and an effective height for each antenna: its height above ground plus any amount by which its ground stands above a least-squares fit to the terrain near it, so never less than the antenna's own height. Everything after that uses those numbers, not the profile.", fn("ITM profile analysis:", itm2Url(210, 330)), " P.2001 also fits a smooth surface to find effective heights (one pair for diffraction and another for ducting) and a roughness parameter, but its diffraction method returns to the full profile to find the obstacle that matters.", fn("P.2001-6, sec. 3.7 and 3.8.", REC), " The consequence shows up in diffraction: on rough terrain ITM's numbers (short horizons, large Δh) drive its loss, while P.2001's loss depends on the one obstacle with the largest diffraction parameter."));

body.push(H2("Line of sight"));
body.push(P("ITM's line-of-sight method is a two-ray model: a direct ray plus a ground-reflected ray with a complex reflection coefficient for the ground constants and polarization, reduced for terrain roughness, blended with the extrapolated diffraction line by a weight that falls as Δh rises.", fn("ITM line-of-sight loss:", itm2Url(562, 581)), " It evaluates that loss at only two distances, d_0 = 0.04 f h_e1 h_e2 (limited to half the horizon distance) and a second point between d_0 and the horizon, then fits a smooth curve A_o + k_1 d + k_2 ln d through them and the diffraction line's value at the smooth-earth horizon.", fn("ITM line-of-sight fit:", itm2Url(412, 453)), " P.2001 has no ground reflection. Its sub-model 1 is L_bm1 = L_bfs + L_d + A_1 plus gaseous absorption: free space, the full diffraction loss of Attachment A at every distance (near zero until terrain enters the first Fresnel zone), and a fade A_1 that combines clear-air multipath and focusing with rain and sets the fades and enhancements over time.", fn("P.2001-6, sec. 4.1, eqs. 46 and 47, and Attachments A, B, and C.", REC)));
body.push(P(`At the median both models therefore stay at free space over smooth earth (${FN("s41")}): within ${n1("alg_los_itm_max")} dB for ITM and ${n1("alg_los_p2001_max")} dB for P.2001 out to 20 km, where a two-ray calculation swings from ${A0("alg_los_tworay", 0)} dB to +${A0("alg_los_tworay", 1)} dB with the interference lobes. Neither predicts the lobes: ITM's two-ray values only shape its fitted curve, and P.2001 leaves multipath to its statistics. The models leave free space as the earth enters the first Fresnel zone, P.2001 at ${n1("alg_los_p2001_from")} km and ITM at ${n0("alg_los_itm_from")} km on this path.`));
body.push(...fig("s41", "s41_line_of_sight.png", "Loss above free space at 3 GHz and 50% of time over smooth earth within line of sight (30 m and 10 m antennas), with a two-ray reference for the same ground."));

body.push(H2("Diffraction"));
body.push(P("ITM computes diffraction at two distances beyond the horizons, not at the path: d_3 = max(d_sML, d_L + 5 X) and d_4 = d_3 + 10 X, where d_sML is the smooth-earth horizon distance, d_L the sum of the actual horizon distances, and X = (a_e²/f)^(1/3) is about 2.8 km at 3 GHz. At each it computes A_d = w A_se + (1 − w) A_k + A_fo: a smooth-earth loss (Vogler's three-radius method) weighted by w, a knife edge at each horizon, and a clutter term of up to 15 dB. It then draws a straight line through the two values and reads the loss at the path's distance from that line.", fn("ITM diffraction line:", itm2Url(392, 398)), fn("ITM diffraction loss and its terms:", itm2Url(486, 540)), " The diffraction section of this paper breaks these terms down."));
body.push(P("P.2001 computes diffraction at the path's own distance with the delta-Bullington method: L_d = L_dba + max(L_dsph − L_dbs, 0). L_dba is the loss over the actual profile, found from the single Bullington point where the lines from the two terminals to their steepest obstacles cross; L_dsph is the first-term spherical-earth loss; and L_dbs is the Bullington loss over a smooth profile, which keeps the spherical-earth loss from being counted twice.", fn("P.2001-6, Attachment A, eq. (A.1); itu_p2001:", p2001Url("private/dl_p.m", 56, 56)), " P.2001 adds its own empirical term to the knife-edge loss J(ν): L_dba = J(ν) + (1 − exp(−J(ν)/6))(10 + 0.02 d), up to 10 dB plus 0.02 dB per km once the edge is well into shadow, a counterpart to ITM's clutter term.", fn("P.2001-6, eq. (A.23); itu_p2001:", p2001Url("private/dl_bull_actual.m", 63, 64))));
body.push(P(`${FN("s40")} shows ITM's construction on two paths. On 120 km of smooth earth, d_3 and d_4 are ${A1("alg_an1_d3", 0)} km and ${A1("alg_an1_d4", 0)} km, the path is past the distance where ITM switches to troposcatter (${n1("alg_an1_dx")} km), and ITM's ${n1("alg_an1_itm")} dB above free space is close to P.2001's ${n1("alg_an1_p2001")} dB. The ${NU.alg_an2_name || "rough western link"} shows what happens on rough terrain (ITM raises no warning on it). The actual horizons total only ${n1("alg_an2_dml")} km, but ITM decides the region from the smooth-earth horizon of its effective heights, ${n1("alg_an2_dsml")} km, so it treats the path as line of sight. Its line-of-sight values at d_0 and d_1 are themselves almost entirely the diffraction line extended back, because the weight on the two-ray term, 1/(1 + f Δh/d_sML), is tiny when Δh is nearly 1 km. ITM's result, ${n0("alg_an2_itm")} dB above free space, is read from a curve that ends at its diffraction value of ${A0("alg_an2_d3", 1)} dB at ${A0("alg_an2_d3", 0)} km, well beyond the path; P.2001's delta-Bullington loss at the path is ${n0("alg_an2_p2001")} dB. The experiments later in this section test how much of the gap that construction explains.`));
body.push(...fig("s40", "s40_itm_anatomy.png", "ITM's construction at 3 GHz and 50% of time on two paths: the diffraction line through its values at d₃ and d₄, the scatter line, and each model's result at the path's distance (diamonds)."));

body.push(H2("Troposcatter"));
body.push(P("ITM's troposcatter loss is the Rice et al. method of NBS Technical Note 101: A_s = F(θd) + 10 log(k H θ⁴) − 0.1(N_s − 301) exp(−θd/40 km) + H_0, with θ the scattering angle, F an attenuation function of θd, and H_0 a frequency-gain function of the effective heights.", fn("ITM troposcatter loss:", itm2Url(583, 626)), ` As with diffraction it evaluates this at two fixed distances, d_L + 200 km and d_L + 400 km, takes the slope, and joins the scatter line to the diffraction line at the crossover distance d_x.`, fn("ITM troposcatter line and crossover:", itm2Url(456, 482)), " P.2001's sub-model 3 reads a climate zone (one of six, or sea) at the common volume from an ITU-R map, and computes L_bs = M + L_freq + L_dist + L_coup − Y_p from that zone's meteorological parameter, the frequency, the scattering angle and distance, the antenna coupling, and a time-percentage term; it never lets troposcatter fall below free space, and it adds gaseous absorption and rain on the two legs to the common volume.", fn("P.2001-6, sec. 4.3 and Attachment E; itu_p2001:", p2001Url("private/tl_troposcatter.m", 241, 251))));
body.push(P(`Over smooth earth the two troposcatter methods agree closely (${FN("s39")}, left): from 50 km to 400 km at 50% of time ITM minus P.2001 stays between ${A1("alg_s50_gap_50_400", 0)} dB and ${A1("alg_s50_gap_50_400", 1)} dB, and both hand over from diffraction to troposcatter at about ${n0("alg_s50_tropo_from")} km. Across the whole sweep from 3 km to 700 km the models never differ by more than ${n1("alg_s50_maxabs")} dB at the median.`));

body.push(H2("Ducting and layer reflection"));
body.push(P("ITM has no ducting mechanism. Its low-percentage losses come from its variability curves, which are fitted to measured distributions and so include ducting only as an average effect.", " P.2001's sub-model 2, shared with P.452, is L_ba = A_ac + A_ad + A_at: a coupling loss into the duct (site shielding by the terminals' horizons and over-sea corrections), a loss proportional to the angular distance, and a time-dependent loss that depends on a ducting percentage β taken from an ITU-R map and adjusted for the path's terrain and land fraction.", fn("P.2001-6, Attachment D, eq. (D.25); itu_p2001:", p2001Url("private/tl_anomalous_reflection.m", 184, 264)), ` On the smooth path ducting takes over from ${n0("alg_s1_anom_from")} km at 1% of time (${FN("s39")}, right); at 120 km P.2001 predicts ${A1("alg_120_p2001", 1)} dB against ITM's ${A1("alg_120_itm", 1)} dB, a difference of ${n0("alg_s1_gap120")} dB. The ducting section of this paper looks at this on real paths.`));
body.push(...fig("s39", "s39_smooth_mechanisms.png", "Loss above free space over smooth earth at 3 GHz (30 m and 10 m antennas, central Kansas), at 50% and 1% of time: ITM's single result, P.2001's sub-models (thin gray), and P.2001's combined result."));

body.push(H2("Sporadic-E, gases, rain, and fading"));
body.push(P("P.2001 models four more effects that ITM leaves to its empirical constants. Sporadic-E reflection (sub-model 4) matters for long paths at low frequencies; at 3 GHz its loss is millions of decibels above the others and plays no part. Gaseous absorption follows Recommendation ITU-R P.676 along the surface path and the troposcatter legs. Rain and wet-snow fading and clear-air multipath fading are combined as mutually exclusive conditions (the time percentages add) and set the high-percentage tail.", fn("P.2001-6, Attachments B, C, F, and G.", REC), " At 3 GHz these terms are small at the median (gaseous absorption is under 0.01 dB per km) but shape the tails of the time distribution."));

body.push(H2("Variability over time"));
body.push(P("ITM adds a variability term to A_ref. It converts the path to an effective distance d_e (130 km at a reference distance set by the effective heights and frequency, scaled linearly below it and offset above it) and reads the time variability from climate-dependent curves of d_e.", fn("ITM variability:", itm2Url(674, 760)), " The shape of the distribution depends on the climate, d_e, and frequency, not on which region produced A_ref. In P.2001 the distribution comes from the mechanisms: diffraction varies through the effective earth radius, ducting through β, troposcatter through Y_p, and fading through Attachments B and C, and the combination at each time percentage decides which one sets the loss."));
body.push(P(`On the smooth 120 km path (${FN("s42")}, left) ducting sets P.2001's loss up to ${n0("alg_t1_anom_until")}% of time, and its loss from 1% to 99% of time spans ${n0("alg_t1_p2001_spread")} dB against ${n0("alg_t1_itm_spread")} dB for ITM; above about 20% both follow troposcatter and agree. On the rough western link (right) P.2001's loss is diffraction at all percentages and changes by only ${n1("alg_t2_p2001_spread")} dB, because the effective earth radius barely matters behind high nearby horizons, while ITM applies its full variability curve and spans ${n0("alg_t2_itm_spread")} dB.`));
body.push(...fig("s42", "s42_time_mechanisms.png", "Basic transmission loss against time percentage at 3 GHz: ITM, P.2001's sub-models (thin gray), and P.2001's combined result, on 120 km of smooth earth and on the rough western link."));

body.push(H2("Do the models agree on the mechanism?"));
body.push(P(`ITM reports the region it used, and P.2001's dominant mechanism is the sub-model with the lowest loss. On the ${n0("alg_m50_n")} real links at 3 GHz (60 eastern and 60 western), the two agree on ${n0("alg_m50_agree")} at 50% of time (${FN("s43")}). Most of the disagreements are links where ITM uses its troposcatter line and P.2001 says diffraction dominates: ${n0("alg_m50_itm_tropo_p2001_diff")} of the ${n0("alg_m50_itm_tropo")} links ITM calls troposcatter. On those links ITM's scatter line starts from its diffraction line at the crossover distance, so it carries the diffraction level forward. At 1% of time the models agree on ${n0("alg_m1_agree")} links, and P.2001 names ducting on ${n0("alg_m1_p2001_anom")} links where ITM has no such mechanism.`));
body.push(...fig("s43", "s43_mechanism_agreement.png", "Number of links (120: 60 eastern, 60 western) by ITM's propagation mode and P.2001's dominant mechanism at 3 GHz, at 50% and 1% of time. Shaded blue: the models agree."));

body.push(H2("Testing the diffraction geometry"));
body.push(P("Three synthetic experiments from the plan in the next section isolate the diffraction geometry, using profiles where the right answer is known or the inputs can be controlled. They run both models on the same profiles at 3 GHz and 50% of time with the same antennas as above (diffraction_families_rev1)."));
body.push(P({ b: "Two ridges. " }, `A 30 km path over flat ground carries two triangular ridges, 300 m wide at the base, at 10 km and 20 km, each 0 m to 300 m high. For a reference, two classical multiple-knife-edge methods were computed on the same geometry with the knife-edge loss of Recommendation ITU-R P.526: Epstein-Peterson, which takes each edge against the line joining its neighbours, and Deygout, which takes the main edge first and then the edge on each side of it.`, fn("J(ν) from Recommendation ITU-R P.526-15, Propagation by diffraction, 2019, eq. (31). J. Epstein and D. W. Peterson, An experimental study of wave propagation at 850 Mc, Proc. IRE 41(5), 1953; J. Deygout, Multiple knife-edge diffraction of microwaves, IEEE Trans. Antennas Propag. AP-14(4), 1966."), ` With both ridges 280 m high, the references give ${A0("fam2_eq280", 2)} dB and ${A0("fam2_eq280", 3)} dB above free space, P.2001 ${A0("fam2_eq280", 1)} dB, and ITM ${A0("fam2_eq280", 0)} dB (${FN("s44")}). Over all ${n0("fam2_n")} ridge pairs, P.2001 is within 10 dB of the references' midpoint in ${n0("fam2_p_within10")}% of cases, with a median of ${A1("fam2_p_vs_ref", 0)} dB; ITM is never within 10 dB, and its median is ${A0("fam2_itm_vs_ref", 0)} dB above. P.2001 is high for a single ridge (${A0("fam2_one280", 1)} dB against ${A0("fam2_one280", 3)} dB to ${A0("fam2_one280", 2)} dB for one 280 m ridge, mostly its empirical add-on of 10 dB plus 0.02 dB per km) and low for two equal ridges, the known weakness of a single equivalent edge.`));
body.push(P(`ITM's excess has a specific cause in its code. Its terrain irregularity Δh is at most ${n1("fam2_itm_dh_max")} m on these profiles, because narrow ridges barely move an interdecile range, so the weight w puts most of its diffraction loss on the smooth-earth term. That term takes its curvature radii from the short horizon distances the ridges create, and the path is in ITM's line-of-sight region (d is less than d_sML on all ${n0("fam2_itm_mode_los")} profiles), so the result is read from the line-of-sight fit that ends at that diffraction value.`));
body.push(...fig("s44", "s44_two_obstacles.png", "Two triangular ridges on a 30 km path at 3 GHz: ITM minus P.2001 for every pair of heights (left), and loss above free space for two equal ridges with the Epstein-Peterson and Deygout references (right)."));
body.push(P({ b: "Synthetic rough terrain. " }, `${(NU.fam21_runs || 0).toLocaleString("en-US")} profiles of filtered random terrain (2 km correlation length) were scaled to a target roughness, the interdecile range of heights about a straight-line fit, from 10 m to 1,000 m, at lengths of 10 km to 150 km, 20 per cell. The median gap follows roughness (${FN("s45")}): ${A0("fam21_dh10", 0)} dB to ${A0("fam21_dh10", 1)} dB at 10 m, ${A0("fam21_dh100", 0)} dB to ${A0("fam21_dh100", 1)} dB at 100 m, ${A0("fam21_dh500", 0)} dB to ${A0("fam21_dh500", 1)} dB at 500 m, and ${A0("fam21_dh1000", 0)} dB to ${A0("fam21_dh1000", 1)} dB at 1,000 m. At 150 km the models agree within ${n1("fam21_150_le200")} dB up to 200 m, where both are troposcatter. This reproduces the divergence window found on real links (rough terrain, shorter than about 100 km) from terrain with no other structure, so the window comes from the models, not from features of the sampled regions. ITM flags a horizon angle over 200 mrad on ${n0("fam21_flagged")}% of these profiles, almost all at 1,000 m. ITM's own Δh differs from the target because of its distance correction: about ${n1("fam21_ratio10")} times the target at 10 km and ${n1("fam21_ratio150")} times at 150 km.`));
body.push(...fig("s45", "s45_roughness_grid.png", "Median ITM minus P.2001 at 3 GHz and 50% of time on synthetic rough terrain, by roughness (interdecile range of heights about a straight-line fit) and path length; 20 profiles per cell."));
body.push(P({ b: "Moving P.2001's evaluation point. " }, `To test whether ITM's habit of computing diffraction beyond the path explains the gap, P.2001 was given the same construction: flat terrain was inserted midway between ITM's two horizon points to lengthen each path to ITM's d_3 and d_4 without moving either horizon, and P.2001's loss at those lengths was extended back to the true distance. On the ${n0("fam24_n")} of ${n0("fam24_total")} real links where this applies, the median gap went from ${A0("fam24_gap", 0)} dB to ${A0("fam24_gap", 1)} dB, and it narrowed by more than half on only ${n0("fam24_closed_half")} link (${FN("s46")}). Where ITM evaluates its diffraction is not, by itself, the source of the gap.`));
body.push(...fig("s46", "s46_evaluation_point.png", "ITM minus P.2001 at 3 GHz on the real links where ITM's d₃ lies beyond the path, with P.2001 as it stands and with P.2001 computed at ITM's d₃ and d₄ and extended back to the path."));
body.push(P(`Together the experiments point at how ITM splits its diffraction loss rather than where it evaluates it: on rough or ridged terrain, ITM's horizon-based terms (two knife edges and a smooth-earth term with radii from short horizons) produce losses well above both P.2001 and the classical two-edge references. P.2001's single edge errs the other way on multiple equal obstacles. This matches the ITS mountain measurements, where the measured loss fell between the two models.`));

body.push(H2("The terms side by side"));
body.push(P("Five more items from the plan put the two models' terms next to each other on the same paths (term_splits_rev1). ITM's terms come from a function that recomputes them from ITM's own equations and checks that they rebuild ITM's reference attenuation to within 10⁻⁹ dB."));
body.push(P({ b: "Smooth-earth diffraction. " }, `Both models carry a smooth-earth diffraction formula: Vogler's three-radius method in ITM and the first-term spherical-earth loss in P.2001. Over smooth earth from 40 km to 300 km they agree within ${A1("term_se_vertical", 0)} dB to ${A1("term_se_vertical", 1)} dB for vertical polarization and ${A1("term_se_horizontal", 0)} dB to ${A1("term_se_horizontal", 1)} dB for horizontal (${FN("s47")}); at 150 km, for example, ${A1("term_se_v150", 0)} dB against ${A1("term_se_v150", 1)} dB. The physics of a smooth earth is not where the models differ.`));
body.push(...fig("s47", "s47_smooth_earth_terms.png", "ITM's smooth-earth diffraction term minus P.2001's spherical-earth diffraction loss over smooth earth at 3 GHz, 30 m and 10 m antennas, both polarizations."));
body.push(P({ b: "Where the diffraction gap comes from. " }, `On the ${n0("term_n")} real links ITM classes as diffraction (of ${n0("term_n_all")}; the other seven end within a metre of ITM's horizon distance, where its terms at the path aren't defined), the difference splits exactly into five parts (${FN("s48")}). Of a mean gap of ${A1("term_gap_total", 0)} dB, ${A1("term_gap_edges", 0)} dB comes from ITM's knife edge at each horizon against P.2001's single Bullington edge, and ${A1("term_gap_smooth", 0)} dB from ITM's weighted smooth-earth term, which ITM always adds; P.2001 adds its spherical-earth loss only where it exceeds the Bullington loss over a smooth profile, and on these links that excess has a median of ${A0("term_p2001_med", 2)} dB. ITM's clutter term outweighs P.2001's empirical add-on by ${A1("term_gap_addon", 0)} dB, extending the diffraction line from d_3 and d_4 back to the path adds ${A1("term_gap_extension", 0)} dB (median ${A1("term_gap_extension", 1)} dB), and gases and P.2001's other terms take off ${A1("term_gap_other", 0).replace("-", "")} dB. At the path, the median ITM terms are ${A1("term_itm_med", 0)} dB of weighted smooth earth, ${A1("term_itm_med", 1)} dB of weighted knife edges, and ${A1("term_itm_med", 2)} dB of clutter; P.2001's are ${A1("term_p2001_med", 0)} dB of knife edge and ${A1("term_p2001_med", 1)} dB of add-on.`));
body.push(...fig("s48", "s48_gap_waterfall.png", "Mean ITM minus P.2001 loss on the real diffraction links at 3 GHz and 50% of time, split into its parts; the parts add to the total."));
body.push(P({ b: "The empirical add-ons. " }, `Each model adds an empirical term to its diffraction loss, and they are similar in size (${FN("s49")}). ITM's clutter term A_fo runs from ${A1("term_afo", 0)} dB to its cap of 15 dB (median ${A1("term_afo", 1)} dB; at the cap on ${n0("term_afo_cap")} links), set by the antenna heights, frequency, and terrain roughness. P.2001's add-on runs from ${A1("term_emp", 0)} dB to ${A1("term_emp", 2)} dB (median ${A1("term_emp", 1)} dB) and grows with path length (correlation ${n1("term_emp_r")}), as its formula, 10 dB plus 0.02 dB per km once the edge is well into shadow, implies.`));
body.push(...fig("s49", "s49_empirical_terms.png", "Each model's empirical diffraction add-on on the real diffraction links at 3 GHz: ITM's clutter term A_fo and P.2001's term in eq. (A.23)."));
body.push(P({ b: "The ducting terms. " }, `P.2001's ducting loss is the sum of a coupling loss, an angular-distance loss, and a time-dependent loss (${FN("s50")}). On the smooth path at 1% of time, the coupling loss is ${A0("term_duct_aac", 0)} dB to ${A0("term_duct_aac", 1)} dB at every distance (it includes 102.45 + 20 log(f(d_lt + d_lr)), with the terminals' horizon distances, and site shielding); the angular-distance loss grows from ${A1("term_duct_50", 0)} dB at 50 km to ${A1("term_duct_500", 0)} dB at 500 km; and the time term rises from ${A1("term_duct_50", 1)} dB to ${A1("term_duct_500", 1)} dB. The result is far below ITM at moderate distances, ${A1("term_duct_125", 2)} dB above free space against ITM's ${A1("term_duct_125", 3)} dB at 125 km, and the two come within 4 dB of each other near 500 km (${A1("term_duct_500", 2)} dB against ${A1("term_duct_500", 3)} dB). On the 120 real links at 1% of time the ducting sub-model gives less loss than diffraction on ${n0("term_duct_links_lbm2_lt_lbm1")}.`));
body.push(...fig("s50", "s50_ducting_terms.png", "P.2001's ducting terms (Attachment D) over smooth earth at 3 GHz and 1% of time, and the resulting loss above free space against ITM's and P.2001's other sub-models."));
body.push(P({ b: "Combining the sub-models by Monte Carlo. " }, `The Recommendation calls its single-percentage blend an approximation and gives a Monte Carlo method for combining the uncorrelated sub-models correctly: draw an independent time percentage for each, read its loss, and add the powers (sec. 5.3, eq. 60). Applied with 200,000 draws on five paths (${FN("s51")}), the two methods agree within about 0.3 dB, the Monte Carlo sampling noise, up to a few percent of time, which is where interference studies usually work. They part in the middle of the distribution, where troposcatter and diffraction or ducting are comparable and uncorrelated: at 50% of time the Monte Carlo loss is ${n1("term_mc2_p50").replace("-", "")} dB lower on 120 km of smooth earth, ${n1("term_mc3_p50").replace("-", "")} dB lower at 300 km, and ${n1("term_mc5_p50").replace("-", "")} dB lower on the over-sea path (up to ${A1("term_mc5_max", 0).replace("-", "")} dB at ${A0("term_mc5_max", 1)}%). Where one mechanism dominates, as on the rough western link, they agree. The blend therefore overstates the loss in the middle of the distribution, which matters for medians and coverage rather than for small-percentage interference.`));
body.push(...fig("s51", "s51_monte_carlo.png", "P.2001's loss combined by the Monte Carlo method of sec. 5.3 minus the single-percentage blend of sec. 5.2, at 3 GHz on five paths."));

body.push(H2("Summary of the differences"));
body.push(...table("ITM and P.2001, mechanism by mechanism.",
  ["Element", "ITM v1.4", "P.2001-6", "Effect on the loss"],
  [["Structure", "One region selected by distance; one reference attenuation; variability added", "Four sub-models computed in parallel, each over time, combined by correlation", "P.2001 can switch mechanism with time percentage; ITM can't"],
   ["Earth curvature", "From surface refractivity; fixed for all time percentages", "From the ΔN map; recomputed for each time percentage", "Same at the median; P.2001's diffraction eases at small percentages"],
   ["Terrain", "Reduced to horizons, Δh, and effective heights", "Full profile for diffraction; smooth fit for heights", "ITM's loss tracks Δh; P.2001's tracks the main obstacle"],
   ["Line of sight", "Two-ray at two distances, fitted to a smooth curve", "Free space, gases, and statistical multipath", "Both near free space at the median; no lobes in either"],
   ["Diffraction", "Two knife edges and smooth earth at two points beyond the horizon, plus clutter; straight line to the path", "Delta-Bullington at the path: one equivalent edge plus spherical earth", "Agree on smooth earth; ITM far higher on rough terrain with low antennas"],
   ["Troposcatter", "NBS TN101 at two distances; line joined to diffraction at d_x", "Climate-zone method at the path, at least free space", "Agree on smooth earth; ITM inherits its diffraction level on rough paths"],
   ["Ducting", "None explicit", "Sub-model 2: coupling, angular distance, and time from β", "P.2001 predicts much less loss at small percentages"],
   ["Gases, rain, fading, sporadic-E", "Implicit in empirical constants", "Explicit attachments", "Small at the median; shape the tails"],
   ["Time variability", "Climate curves of effective distance, the same for every region", "Each mechanism's own statistics, combined at each percentage", "Spreads differ by tens of decibels on some paths"]],
  [1500, 2620, 2620, 2620]));

// ===== Plan: equation by equation (rendered from ALGORITHM_COMPARISON_PLAN.md)
body.push(H1("Plan: comparing the models equation by equation"));
body.push(P("The section above compares the two models mechanism by mechanism. The next revision will pair every equation in the two loss calculations: what each computes, from which inputs, and what one figure shows the difference. This section is that plan. It is kept as ALGORITHM_COMPARISON_PLAN.md in the repository and printed here so readers can see what is done, what is next, and in what order. Items marked done are in this revision."));
body.push(...planSection(path.join(__dirname, "ALGORITHM_COMPARISON_PLAN.md")));

// ===== Method
body.push(H1("Inputs and method"));
body.push(P("Each calculation builds one terrain profile at about 30 m spacing from USGS 3DEP 1 arc-second data and passes it to all three models. Each model applies its own earth curvature and climate inputs.", fn("ITM effective earth curvature:", itmUrl(193, 197)), " ITM uses ground permittivity 25, conductivity 0.02 S/m, variability mode 13, and 50% confidence, with its radio climate and N₀ from the ITU maps at the path midpoint.", fn("Wireless Innovation Forum, Requirements for Commercial Operation in the U.S. 3550-3700 MHz Citizens Broadband Radio Service Band, WINNF-TS-0112."), " P.452 stops at 50% of time."));
body.push(P("The calculations, all at 3 GHz, are the following:"));
body.push(B({ b: "Smooth earth" }, " over flat land and sea, 1 km to 200 km."));
body.push(B({ b: "A single knife edge" }, " on a 20 km path with 100 m antennas."));
body.push(B({ b: "Real terrain" }, `: ${nLinks} random links of 10 km to 150 km in three mid-Atlantic regions (coastal plain, Piedmont, Appalachians).`));
body.push(B({ b: "Western terrain" }, `: ${n0("west_n")} links drawn with the same rules in three western regions (Colorado Front Range, Nevada Basin and Range, and southern California).`));
body.push(B({ b: "Four radials" }, " of 150 km from a Piedmont site at 38.90 N, 77.45 W."));
body.push(B({ b: "Five archetype paths" }, " over the full time distribution: line of sight, single-horizon diffraction, double-horizon diffraction, troposcatter, and over-sea coastal."));

// ===== Results at 50%
body.push(H1("Results at 50% of time"));
body.push(H2("Smooth earth and a knife edge"));
body.push(P(`On smooth land the three models agree within ${n1("se_maxabs")} dB at every distance from 1 km to 200 km (${FN("s01")}). Over a single raised point on a 20 km path, all three follow the shape of the ITU-R P.526 knife-edge function J(v) but add loss beyond it (${FN("s02")}); ITM's loss rises fastest at large v.`, fn("Recommendation ITU-R P.526-15, Propagation by diffraction, 2019.")));
body.push(...fig("s01", "s01_smooth_earth.png", "Loss above free space on smooth land at 3 GHz and 50% of time, with 30 m and 10 m antennas."));
body.push(...fig("s02", "s02_knife_edge.png", "Loss above free space over a single raised point on a 20 km path at 3 GHz, against the Fresnel-Kirchhoff parameter v, with ITU-R P.526 J(v) for reference."));
body.push(H2("Real terrain by mechanism"));
body.push(P(`On real terrain the models agree in line of sight and split beyond it (${FN("s04")}). The median ITM minus P.2001 is ${n1("gap_Line of sight")} dB on line-of-sight links, ${n1("gap_Diffraction")} dB on diffraction links, and ${n1("gap_Troposcatter")} dB on troposcatter links, with ITM's mechanism class deciding the group. P.452 matches P.2001 within ${r2(NU.p2001_p452_maxmed)} dB at the median in every class, so the figures show P.2001 only.`));
body.push(...fig("s04", "s04_gap_by_mechanism.png", "ITM minus P.2001 on each real-terrain link at 3 GHz and 50% of time, by ITM's mechanism class. The bar is the median."));
body.push(P(`The gap tracks terrain roughness (${FN("s05")}): its median is -0.1 dB on links with a terrain irregularity Δh under 50 m and 44 dB on links with Δh over 200 m.`));
body.push(...fig("s05", "s05_gap_vs_terrain.png", "ITM minus P.2001 on each real-terrain link at 3 GHz against ITM's terrain irregularity Δh."));
body.push(H2("Frequency"));
body.push(P(`${FN("s06")} sweeps frequency from 100 MHz to 10 GHz on three archetype paths. On the line-of-sight and single-horizon paths the models stay within 5 dB at every frequency. On the double-horizon Appalachian path the gap grows from ${n0("sweep_Double-horizon diffraction_100")} dB at 100 MHz to ${n0("sweep_Double-horizon diffraction_3162")} dB near 3 GHz and ${n0("sweep_Double-horizon diffraction_10000")} dB at 10 GHz, so results at 3 GHz understate the gap at higher frequencies.`));
body.push(...fig("s06", "s06_frequency_sweep.png", "ITM minus P.2001 at 50% of time on three archetype paths from 100 MHz to 10 GHz. The shaded band is 1 GHz to 10 GHz."));
body.push(H2("Terrain resolution"));
body.push(P(`Resampling the ${n0("res_n")} diffraction links from 30 m to 90 m changes the median loss by ${r2(NU.res90_itm)} dB for ITM and ${r2(NU.res90_p2001)} dB for P.2001 (${FN("s07")}). Smoothing over 1 km lowers ITM's loss by a median of ${n1("res1k_itm")} dB and P.2001's by ${n1("res1k_p2001")} dB. The typical link's gap moves by ${n1("res_medabs")} dB, but ${n0("res_moved10")} links move by more than 10 dB, up to ${n0("res_max")} dB; a later section explains why.`));
body.push(...fig("s07", "s07_terrain_resolution.png", "ITM minus P.2001 on each diffraction link at 3 GHz on the 30 m profile, resampled at 90 m, and smoothed over 1 km."));

// ===== Diffraction
body.push(H1("Diffraction: one edge or two"));
body.push(H2("The knife-edge formula is not the difference"));
body.push(P("P.452 and P.2001 compute a knife-edge loss of 6.9 + 20 log(√((v − 0.1)² + 1) + v − 0.1),", fn("P.452 knife-edge loss, eq. (13):", p452Core(404, 404)), " and ITM uses 6.02 + 9.11v − 1.27v² below v = 2.4 and 12.953 + 20 log v above.", fn("ITM knife-edge function:", itmUrl(486, 501)), ` Both stay within 0.12 dB of J(v) from v = 0 to 10 (${FN("s03")}). The difference is that ITM adds one knife edge at each horizon, where the ITU models use a single equivalent edge. Two edges roughly double the loss, and double its growth with frequency: about 6 dB per doubling of frequency against 3 dB for one edge.`));
body.push(...fig("s03", "s03_knife_edge_function.png", "Knife-edge loss against the Fresnel-Kirchhoff parameter v: J(v) from the Fresnel integrals (wide gray), the ITU and ITM approximations for one edge, and ITM's two edges added."));
body.push(H2("What ITM's diffraction loss is made of"));
body.push(P("ITM's diffraction loss is A_d = w·A_se + (1 − w)·A_k + A_fo: a smooth-earth loss A_se with weight w, a double knife edge A_k, and a clutter term A_fo of up to 15 dB. The weight falls as terrain irregularity rises.", fn("ITM diffraction blend and weight:", itmUrl(469, 483)), ` On the ${n0("nd")} diffraction links at 3 GHz (${FN("s08")}), the median terms are ${n0("term_se")} dB from the weighted smooth earth, ${n0("term_k")} dB from the weighted knife edges, and ${n0("term_fo")} dB from clutter, against ${n0("term_bull")} dB for P.452's single knife edge.`));
body.push(...fig("s08", "s08_diffraction_terms.png", "Median diffraction loss above free space on the diffraction links at 3 GHz, split into its terms."));
body.push(P(`Removing ITM's ingredients one at a time locates the gap (${FN("s09")}). The median gap to P.452 is ${n1("ab_ITM as is")} dB as ITM stands; ${n1("ab_1 single edge")} dB with one knife edge instead of two; ${n1("ab_2 no clutter term")} dB without the clutter term; ${n1("ab_3 evaluated at the path")} dB with the loss evaluated at the path instead of extended from beyond the horizons; and ${n1("ab_4 all three")} dB with all three removed. These are diagnostics, not proposed fixes: ITM's terms were fitted to measurements as a set.`));
body.push(...fig("s09", "s09_ablation.png", "Median ITM minus P.452 diffraction loss at 3 GHz, as ITM stands and with one ingredient removed at a time."));
body.push(P(`ITM predicts more diffraction loss than P.452 on ${NU.nd - NU.ratio_lt1} of ${n0("nd")} diffraction links, with a median ratio of ${r2(NU.ratio)} (${FN("s16")}).`));
body.push(...fig("s16", "s16_itm_vs_p452.png", "ITM's diffraction loss above free space against P.452's on each diffraction link at 3 GHz. The solid line is equal loss; the dashed line is twice P.452's loss."));
body.push(H2("One link in detail"));
body.push(P(`${FN("s13")} takes the double-horizon archetype, a 65 km Appalachian link. The transmitter's horizon is a ridge 5.8 km away, so the rays from the two horizons meet about 5 km above the path, where P.452 and P.2001 put their single edge. ITM weights its smooth-earth loss by only 0.039, but that loss is over 1,300 dB, so the small weight still adds about 50 dB; the two knife edges and the clutter term add about 100 dB more.`));
body.push(...fig("s13", "s13_anatomy.png", "Top: the double-horizon archetype profile with the earth's bulge, both horizons, and the rays that meet at the Bullington point. Bottom: how each model's diffraction loss adds up at 3 GHz and 50% of time."));

// ===== Where they diverge
body.push(H1("Where the models start to diverge"));
body.push(P(`Along four radials (${FN("s10")}), the models agree for the first few kilometers and split as soon as the path goes beyond line of sight. To the east and south the gap reaches ${n0("rad90_max60")} dB to ${n0("rad180_max60")} dB within 60 km and then stays within about 4 dB beyond 80 km, where both models are in troposcatter. To the west, into the Appalachians, it stays at a median of ${n0("rad270_med80")} dB from 80 km to 150 km.`));
body.push(...fig("s10", "s10_radials.png", "ITM minus P.2001 at 3 GHz and 50% of time along four radials from 38.90 N, 77.45 W (median over 10 km), and on smooth earth."));
body.push(P(`The links and the measured paths show the same window (${FN("s11")}). The large gaps fall on calculated links from about 15 km to 150 km. On the ${n0("meas150_n")} measured databank paths longer than 150 km, ITM and P.2001 differ by a median of ${n1("meas150_med")} dB, which is why the measurement comparison finds the models close.`));
body.push(...fig("s11", "s11_window_by_length.png", "ITM minus P.2001 on the calculated links at 3 GHz and on the measured databank paths from 30 MHz to 10 GHz, against path length."));
body.push(P(`ITM's smooth-earth weight w decides which side of the split a link falls on (${FN("s12")}). Where w is 0.12 or more, the median gap is ${n0("w_ge")} dB (${n0("w_ge_n")} links); where w is under 0.12, it is ${n0("w_lt")} dB (${n0("w_lt_n")} links). Few links fall between, which also explains the terrain-resolution result: smoothing raises w on a few links enough to switch groups.`));
body.push(...fig("s12", "s12_the_jump.png", "ITM minus P.2001 on the diffraction links at 3 GHz against ITM's smooth-earth weight w."));
body.push(P(`Of the ${n0("win_n")} calculated links with Δh over 150 m and length under 150 km, ${n0("win_gt20")} have a gap over 20 dB (${FN("s14")}). ${n0("mwin_n")} measured datasets from 30 MHz to 10 GHz fall in that corner, and ITM classes ${n0("mwin_los")} of them as line of sight. On the ${n0("mwin_big_n")} datasets there where ITM and P.2001 differ by more than 10 dB, from ${n0("mwin_big_paths")} paths, the evidence splits by frequency. From 1 GHz to 10 GHz (${n0("mwin_hi_big_n")} datasets on ${n0("mwin_hi_big_paths")} paths), ITM predicts a mean of ${n0("mwin_hi_big_itm")} dB too much loss and P.2001 is within ${n0("mwin_hi_big_p2001").replace("-", "")} dB. Below 1 GHz (${n0("mwin_lo_big_n")} datasets on ${n0("mwin_lo_big_paths")} paths), ITM is within ${n0("mwin_lo_big_itm")} dB and P.2001 predicts ${n0("mwin_lo_big_p2001").replace("-", "")} dB too little loss. Neither model is right in the window across the whole range. The ITS spot measurements in the measurement section test the window nearer 3 GHz.`));
body.push(...fig("s14", "s14_where_window_falls.png", "Calculated links at 3 GHz, marked by whether ITM and P.2001 are more than 20 dB apart, and measured databank paths from 30 MHz to 10 GHz, by path length and terrain irregularity Δh."));
body.push(H2("Western terrain"));
body.push(P(`The mid-Atlantic sample is mostly gentle terrain. To see whether rougher terrain changes the picture, the same calculation was repeated on ${n0("west_n")} links drawn with the same rules in three western regions: the Colorado Front Range, the Nevada Basin and Range, and the Los Angeles basin and Transverse Ranges. The median terrain irregularity Δh is ${n0("west_dh_med")} m in the west against ${n0("east_dh_med")} m in the east, and ${n0("west_win_n")} of the ${n0("west_n")} western links fall in the divergence window.`));
body.push(P(`The western links sit at the rough end of the same trend (${FN("s35")}). The median ITM minus P.2001 is ${n1("west_gap_med")} dB in the west against ${n1("east_gap_med")} dB in the east, and ${n0("west_gt20")} of the ${n0("west_n")} western links differ by more than 20 dB, against ${n0("east_gt20")} eastern links. By region the median is ${n1("west_front_range_gap")} dB in the Front Range, ${n1("west_basin_and_range_gap")} dB in the Basin and Range, and ${n1("west_southern_california_gap")} dB in southern California. ITM classes ${n0("west_n_Diffraction")} links as diffraction and ${n0("west_n_Troposcatter")} as troposcatter, with medians of ${n1("west_gap_Diffraction")} dB and ${n1("west_gap_Troposcatter")} dB; unlike in the east, the troposcatter links don't reconverge within 150 km. P.452 and P.2001 still agree within ${n1("west_p2001_p452_maxabs")} dB on every link.`));
body.push(P(`The same mechanism explains the gap. On ${n0("west_w_lt_n")} of the ${n0("west_nd")} western diffraction links, ITM's smooth-earth weight w is under 0.12, and the median gap there is ${n0("west_w_lt")} dB. ITM flags a horizon angle over 200 mrad on ${n0("west_hzn_flag")} western links, outside its stated range; leaving them out, the median gap is ${n0("west_gap_noflag")} dB. At 1% of time the median gap is still ${n0("west_gap_1")} dB, so on this terrain ducting doesn't close it.`));
body.push(...fig("s35", "s35_east_west.png", "ITM minus P.2001 at 3 GHz and 50% of time against ITM's terrain irregularity Δh, on the 60 eastern links and the 60 western links."));

// ===== Time distribution
body.push(H1("Results over the time distribution"));
body.push(P(`${FN("s21")} shows each model's loss relative to its own 50% value on the five archetype paths. From 50% to 0.01% of time, P.2001's loss falls about twice as far as ITM's on the troposcatter, over-sea, and single-horizon paths: by 68 dB against 35 dB on the troposcatter path and 75 dB against 47 dB on the over-sea path, because ducting takes over in P.2001.`));
body.push(...fig("s21", "s21_archetypes.png", "Loss minus its 50% value against time percentage on the five archetype paths at 3 GHz, ITM and P.2001."));
body.push(P(`On the real-terrain links (${FN("s15")}), the gap on diffraction links holds across the distribution, from ${n0("time_Diffraction_0.001")} dB at 0.001% of time to ${n0("time_Diffraction_99")} dB at 99%. On line-of-sight links the models agree at 50% and split by about ${n0("time_Line of sight_0.001")} dB at 0.001%, where P.2001 adds ducting.`));
body.push(...fig("s15", "s15_window_over_time.png", "Median ITM minus P.2001 over the real-terrain links at 3 GHz against time percentage, by ITM's mechanism class."));

// ===== Ducting
body.push(H1("Ducting: the mechanism ITM leaves out"));
body.push(P("P.452 and P.2001 model ducting and layer reflection as their own mechanism. In P.452 the loss is L_ba = A_f + A_d(p) + A_g, where the time-dependent part depends on β, the time percentage for which strong refractivity lapse rates can be expected near the path.", fn("P.452 ducting and layer reflection, eq. (47) to (57):", p452Core(483, 527)), " P.2001 uses the same structure.", fn("P.2001 anomalous propagation, Attachment D:", p2001Url("private/tl_anomalous_reflection.m", 1, 265)), " ITM has no ducting term; its small-percentage loss comes from variability curves chosen by radio climate."));
body.push(P(`On the ${n0("sea_len")} km over-sea archetype (${FN("s17")}), both ITU models predict less loss than free space (${n1("sea_fs")} dB) for ${NU.sea_below_fs}% of time or less. At 1% of time ITM predicts ${n1("sea_itm_1")} dB and P.2001 ${n1("sea_p2001_1")} dB; at 0.01% the values are ${n1("sea_itm_0.01")} dB and ${n1("sea_p2001_0.01")} dB.`));
body.push(...fig("s17", "s17_over_sea.png", "Basic transmission loss on the 127 km over-sea coastal archetype at 3 GHz against time percentage."));
body.push(P(`On smooth earth (${FN("s18")}), P.2001 uses ducting for up to 10% of time on land paths beyond about 60 km and for up to 20% to 30% of time on sea paths beyond about 30 km.`));
body.push(...fig("s18", "s18_ducting_takeover.png", "The largest time percentage at which ducting is P.2001's lowest-loss mechanism, against distance, on smooth land and sea at 3 GHz."));
body.push(P(`On the inland real-terrain links, steep horizons limit ducting (${FN("s19")}). From 50% to 1% of time, P.2001's signal strengthens by a median of ${n1("dep_p2001_Line of sight")} dB on line-of-sight links and ${n1("dep_p2001_Diffraction")} dB on diffraction links, against ${n1("dep_itm_Line of sight")} dB and ${n1("dep_itm_Diffraction")} dB for ITM. On troposcatter links ITM's wide variability gives the larger change: ${n1("dep_itm_Troposcatter")} dB against ${n1("dep_p2001_Troposcatter")} dB.`));
body.push(...fig("s19", "s19_enhancement_real.png", "Median loss at 50% minus loss at 1% of time on the real-terrain links at 3 GHz, by ITM's mechanism class."));
body.push(P(`On the measured paths from 30 MHz to 10 GHz (${FN("s20")}), the signal strengthens by a median of ${n1("enh_meas")} dB from 50% to 1% of time. All three models predict more: ${n1("enh_itm")} dB for ITM, ${n1("enh_p452")} dB for P.452, and ${n1("enh_p2001")} dB for P.2001. ITM's only lever on this part of the distribution is its radio climate: on the double-horizon archetype, the seven climates move ITM's loss at 1% of time from ${n1("clim_min")} dB to ${n1("clim_max")} dB.`));
body.push(...fig("s20", "s20_enhancement_measured.png", "Median loss at 50% minus loss at 1% of time against path length on the measured databank paths from 30 MHz to 10 GHz, measured and predicted."));

// ===== Measurements
body.push(H1("Comparison with measurements"));
body.push(H2("The data"));
body.push(P("The comparison uses Table III of the ITU-R Study Group 3 databank (DBSG3), clear-air trans-horizon basic transmission loss.", fn("ITU-R Study Group 3 databanks (DBSG3), Table III, clear-air trans-horizon basic transmission loss statistics, long-term data.", "https://www.itu.int/oth/R0A04/en"), ` From 30 MHz to 10 GHz, 608 datasets have site coordinates, antenna heights, a measured median, and a surveyed profile or coordinates; after a quality screen, ${QN(dbQ, "kept")} remain, measured in North America, Europe, and Japan (${FN("fig25")}). Coordinates in Japan were converted from the Tokyo datum to WGS84.`, fn("EPSG Geodetic Parameter Dataset, Tokyo to WGS 84 (1).", "https://epsg.io/63016405"), " The databank includes the U.S. paths of OT/TRER 16; the medians of 10 paths read from that report match the databank exactly.", fn("A. G. Longley, R. K. Reasoner, and V. L. Fuller, Measured and Predicted Long-Term Distributions of Tropospheric Transmission Loss, OT/TRER 16, Office of Telecommunications, July 1971.", "https://its.ntia.gov/publications/download/OT-TRER-16.pdf")));
body.push(P(`Few datasets sit near 3 GHz: ${DBn("1-3 GHz")} from 1 GHz to 3 GHz and ${DBn("3-6 GHz")} from 3 GHz to 6 GHz. The comparison therefore uses all ${DBn("All")} datasets from 30 MHz to 10 GHz, reported in two groups, 30 MHz to 1 GHz and 1 GHz to 10 GHz, and by band. P.452 starts at 100 MHz. These data are not an independent test: ITU-R used the databank to develop P.452 and P.2001, and ITM's developers used many of the same U.S. measurements.`));
body.push(...fig("fig25", "fig25_dbsg3_map_v2.png", "The databank datasets used in the comparison, in the three regions where they were measured. One Australian path is not shown. Paths are colored by frequency."));
body.push(H2("Terrain and site locations"));
body.push(P(`Many sites are on hilltops, and coordinates from 1950s and 1960s maps can sit a few hundred meters off the summit, so a 30 m terrain model can put a ridge next to the antenna. The main results therefore use the databank's surveyed profiles. ${FN("fig30")} shows the effect on the ${TCn()} datasets that both runs kept: for ITM the RMS error in the median is ${TC("ITM v1.4", "rms_dem_listed")} dB on 30 m terrain at the listed coordinates, ${TC("ITM v1.4", "rms_dem_corrected")} dB after moving each site to the nearby point that best matches its surveyed elevation, and ${TC("ITM v1.4", "rms_survey")} dB on the surveyed profiles. The site correction made the errors larger, because on a mountainside the nearest point at the right height is often on the wrong slope.`));
body.push(...fig("fig30", "fig30_dbsg3_terrain_and_sites_v2.png", "Left: 30 m terrain minus surveyed ground elevation at each terminal, at the listed coordinates and after the site correction. Right: RMS error in the median for each terrain source."));
body.push(H2("Results"));
body.push(P(`Over all ${DBn("All")} datasets from 30 MHz to 10 GHz, the mean error in the median is ${M3("All", 50, "mean_error_db")}, and the RMS error is ${M3("All", 50, "rms_error_db")}. From 30 MHz to 1 GHz (${DBn("30 MHz-1 GHz")} datasets) all three predict about 3 dB too little loss: ${M3("30 MHz-1 GHz", 50, "mean_error_db")}. From 1 GHz to 10 GHz (${DBn("1-10 GHz")} datasets) the mean error is ${M3("1-10 GHz", 50, "mean_error_db")}, and the RMS error is ${M3("1-10 GHz", 50, "rms_error_db")}. From 1 GHz to 3 GHz the mean error is ${M3("1-3 GHz", 50, "mean_error_db")}, and from 3 GHz to 6 GHz it is ${M3("3-6 GHz", 50, "mean_error_db")}. ITM drifts toward too much loss from 6 GHz to 10 GHz (${FN("s23")}).`));
body.push(...fig("s23", "s23_error_vs_frequency.png", "Median predicted minus measured loss at 50% of time by frequency band, 30 MHz to 10 GHz."));
body.push(P(`At 1% of time the mean error over all datasets is ${M3("All", 1, "mean_error_db")} (${FN("s24")}): the ITU models predict too little loss at small percentages, because their ducting term enhances the signal more than was measured.`));
body.push(...fig("s24", "s24_error_vs_time.png", "Mean predicted minus measured loss over all datasets from 30 MHz to 10 GHz against time percentage. P.452 is defined only up to 50% and from 100 MHz."));
body.push(P(`Against terrain irregularity (${FN("s25")}), the median errors show no rough-terrain trend comparable to the calculated gap, because most measured paths are long troposcatter paths outside the divergence window.`));
body.push(...fig("s25", "s25_error_vs_terrain.png", "Median predicted minus measured loss at 50% of time from 30 MHz to 10 GHz against ITM's terrain irregularity Δh."));

body.push(H2("Point-to-area measurements"));
body.push(P(`The databank also holds VHF and UHF measurements relating to terrestrial broadcasting (Recommendation ITU-R P.311, Tables VI-1 and VI-2), which ITU-R distributes free.`, fn("ITU-R Study Group 3 databank, VHF/UHF measurements relating to terrestrial broadcasting, rsg3-dbsg5-rssdata.zip.", "https://www.itu.int/oth/R0A0400005B/en"), ` Each spatial record is a location median: the field strength exceeded at 50% of the locations measured around a point, for 1 kW e.r.p., which converts to basic transmission loss as 141.45 dB minus the field strength plus 20 log f. Keeping the records with site coordinates, a surveyed profile that matches them, a receiving antenna at least 10 m high, and a path of at least 1 km leaves ${n0("area_n")} records from ${n0("area_experiments")} experiments, from ${A0("area_f_range", 0)} MHz to ${A0("area_f_range", 1)} MHz on paths of ${A1("area_d_range", 0)} km to ${A1("area_d_range", 1)} km. They include ${r0(NU["area_2-3 GHz_itm"][2])} NTIA measurements at 2,180 MHz in Virginia, the closest to 3 GHz in the databank.`));
body.push(P(`All three models predict much less loss than these measurements (${FN("s31")}): over all records the mean error is ${A1("area_All_itm", 0)} dB for ITM and ${A1("area_All_p2001", 0)} dB for P.2001, and at 2,180 MHz it is ${A1("area_2-3 GHz_itm", 0)} dB for ITM, ${A1("area_2-3 GHz_p452", 0)} dB for P.452, and ${A1("area_2-3 GHz_p2001", 0)} dB for P.2001. The error grows with frequency and is largest on the U.S. experiments in rural Virginia, which used antennas 11 m to 15 m high, so it most likely reflects clutter and vegetation loss near the terminals that none of the three models includes without a clutter model such as Recommendation ITU-R P.2108. On these paths the three models agree with each other within about 3 dB on average, so the data say more about the missing clutter term than about which model to prefer.`));
body.push(...fig("s31", "s31_area_measurements.png", "Mean predicted minus measured location-median loss on the ITU-R point-to-area records by frequency band."));

body.push(H2("Rough-terrain spot measurements near 3 GHz"));
body.push(P(`The databank has few paths in the divergence window near 3 GHz. The ITS "Phase 2" spot measurements, which NTIA publishes free, fill part of that gap: short and medium paths over irregular terrain from 230 MHz to 9.2 GHz, each with a profile surveyed from topographic maps.`, fn("NTIA/ITS, Legacy radio propagation data, Phase 2.", "https://its.ntia.gov/data/legacy-radio-propagation-data/"), ` Four sets have profiles: the Colorado plains (Gunbarrel Hill receiver), the Colorado mountains (Fritz Peak receiver), North Table Mountain near Golden, Colorado, and the Virginia piedmont, measured from 1965 to 1967.`, fn("P. L. McQuate, J. M. Harman, and A. P. Barsis, Tabulations of Propagation Data over Irregular Terrain in the 230- to 9200-MHz Frequency Range, Part I: Gunbarrel Hill Receiver Site, ESSA Technical Report ERL 65-ITS 58, 1968; Parts II and III, 1968 and 1970.", "https://its.ntia.gov/publications/download/essa_erl_65-ITS_58.pdf"), fn("G. A. Hufford and F. K. Steele, Tabulations of Propagation Data over Irregular Terrain in the 75- to 8400-MHz Frequency Range, Part V: Virginia, NTIA Report 91-282, 1991.", "https://its.ntia.gov/publications/download/91-282.pdf"), ` The comparison keeps ${n0("its_paths")} measured paths, from ${A1("its_d_range", 0)} km to ${A1("its_d_range", 1)} km, and uses the frequencies on either side of 3 GHz: 1,846 MHz and 4,595 MHz in Colorado, and 2,180 MHz and 4,820 MHz in Virginia. Transmitting antennas were 6.6 m to 15 m high with horizontal polarization; in Colorado each receiving antenna was raised from 1 m to 13 m, and the comparison uses every height from 3 m, counting each path once. The models ran on the surveyed profiles.`));
body.push(P(`On many long paths the signal was too weak to measure, so the data give only a lower bound on the loss. Leaving those paths out would favor whichever model predicts less loss, so the medians below use the Kaplan-Meier estimate, which counts each bound as "at least this much loss."`, fn("E. L. Kaplan and P. Meier, Nonparametric estimation from incomplete observations, Journal of the American Statistical Association, 53(282), 1958.")));
body.push(P(`On the ${n0("its3_colorado_open_links")} open Colorado sites, ITM is the closest: its median error is ${n1("its3_colorado_open_itm")} dB, against ${n1("its3_colorado_open_p452")} dB for P.452 and ${n1("its3_colorado_open_p2001")} dB for P.2001 (${FN("s33")}). ITM's error grows with distance, from ${A1("its3_colorado_open_d0_itm", 0)} dB under 5 km to ${A1("its3_colorado_open_d50_itm", 0)} dB from 50 km to 150 km, while the ITU models stay ${A1("its3_colorado_open_d50_p2001", 0).replace("-", "")} dB to ${A1("its3_colorado_open_d5_p2001", 0).replace("-", "")} dB on the low side. Most of these paths are in the plains and near Golden, where ITM and P.2001 differ by only a few decibels.`));
body.push(P(`The Colorado mountains are the real test. On the ${n0("its3_r2far_links")} mountain paths longer than 15 km, where the median Δh is ${n0("its3_r2far_dh")} m, ${n0("its3_r2far_cens")}% of the results were below the receiver's sensitivity. Counting those as lower bounds, ITM predicts a median of ${A0("its3_r2far_itm", 1)} dB too much loss and P.2001 ${A0("its3_r2far_p2001", 1).replace("-", "")} dB too little; P.452 matches P.2001. Where the signal was too weak to measure, P.2001 predicts less loss than the bound on ${n0("its3_r2far_below_p2001")}% of the results and ITM on ${n0("its3_r2far_below_itm")}%. The measured loss falls between the two predictions: on this terrain ITM overstates the loss and the ITU models understate it, each by tens of decibels. Over all ${n0("its3_win_n")} measured paths in the divergence window (Δh over 150 m, 15 km and longer), the medians are ${A1("its3_win_itm", 2)} dB for ITM and ${A1("its3_win_p2001", 2)} dB for P.2001.`));
body.push(...fig("s33", "s33_its_error_by_distance.png", "Median predicted minus measured loss on the ITS Phase 2 open Colorado sites at 1,846 MHz and 4,595 MHz, by path length. Medians count paths below the receiver's sensitivity as lower bounds (Kaplan-Meier)."));
body.push(P(`In Virginia all three models predict too little loss even at open sites: the median error is ${n1("its3_virginia_open_itm")} dB for ITM and ${n1("its3_virginia_open_p2001")} dB for P.2001 on ${n0("its3_virginia_open_links")} links, at every distance. That matches the ITU point-to-area records from the same region and most likely reflects trees near the terminals, which bare-earth profiles leave out.`));
body.push(P(`The paired sites measure that clutter directly. On ${n0("its_pairs_paths")} paths, a second receiver site sat behind trees or a building next to the open one. Near 3 GHz the concealed site had a median of ${A1("its_pairs_3", 0)} dB more loss than the open one (middle half ${A1("its_pairs_3", 1)} dB to ${A1("its_pairs_3", 2)} dB, ${A0("its_pairs_3", 5)} pairs), rising from ${A1("its_pairs_lo", 0)} dB below 1 GHz to ${A1("its_pairs_hi", 0)} dB above 3 GHz (${FN("s34")}). The models predict almost no difference, because the two sites share nearly the same bare-earth profile. A clutter model such as Recommendation ITU-R P.2108 would be needed to capture it.`));
body.push(...fig("s34", "s34_its_concealed.png", "Measured loss at a concealed site (behind trees or a building) minus the nearby open site, ITS Phase 2, by frequency band. The bar is the median; the dashed line is the models' median difference."));
body.push(H2("Low antennas and low frequencies"));
body.push(P(`Two more ITS spot-measurement sets test the models with antennas near the ground. Phase 1 (1963 and 1964) measured at 50 MHz and 100 MHz in the Colorado plains, the Colorado mountains, and the Ohio hills, with transmitting antennas about 4 m high and receiving antennas 0.55 m to 9 m high, on surveyed profiles.`, fn("M. E. Johnson, M. J. Miles, P. L. McQuate, and A. P. Barsis, Tabulations of VHF Propagation Data Obtained over Irregular Terrain at 20, 50, and 100 MHz, ESSA Technical Report IER 38-ITSA 38, Parts I to III, 1967."), ` The low-antenna set (1968) measured at 230 MHz and 416 MHz in three arid western regions (the Laramie Mountains, the Snake River Plateau, and the Columbia Plateau) with both antennas 3 m high or lower.`, fn("L. G. Hause, F. G. Kimmett, and J. M. Harman, UHF Radio Propagation Data for Low Antenna Heights, ESSA Technical Report ERL 134-ITS 93, volumes 1 to 3, 1969."), ` It has no profiles, so the models ran on 30 m terrain at the listed coordinates. Together the two sets add ${n0("spot_paths")} paths.`));
body.push(P(`All three models predict too little loss with antennas this low (${FN("s37")}). The median error is ${n1("spot_phase1_itm")} dB for ITM and ${n1("spot_phase1_p2001")} dB for P.2001 on the ${n0("spot_phase1_paths")} Phase 1 paths, and ${n1("spot_lowant_itm")} dB for ITM and ${n1("spot_lowant_p2001")} dB for P.2001 on the ${n0("spot_lowant_paths")} low-antenna paths. On these paths ITM and P.2001 differ by a median of only ${n1("spot_gap_med")} dB, because the gap between the models is small at these low frequencies (it grows with frequency, as the frequency sweep shows), so the data say more about losses near the ground (ground reflection, vegetation, and small obstacles a map profile misses) than about which model to prefer. The low-antenna sites were said to be on the highest ground within 100 m of a chosen point; moving each terminal to the highest 30 m terrain point within 100 m lowers ITM's prediction by a median of ${n1("spot_shift_itm").replace("-", "")} dB, so at these heights the site position matters as much as the model.`));
body.push(...fig("s37", "s37_spot_sets.png", "Median predicted minus measured loss at 50% of time on the ITS Phase 1 (50 MHz and 100 MHz) and low-antenna (230 MHz and 416 MHz) spot measurements, by measurement set and frequency. Medians count results below the receiver's sensitivity as lower bounds."));

// ===== Uncertainty
body.push(H1("How certain are these numbers?"));
body.push(P(`The headline numbers come from small samples, so this section puts 95% confidence intervals on them by bootstrap: 10,000 resamples of the links, or of the measured paths, with a fixed seed. Resampling paths rather than datasets matters for the measurements, because datasets on one path share its terrain and its errors.`));
body.push(P(`The class medians are uncertain (${FN("s26")}). The median gap on the 27 diffraction links is ${A0("u_Diffraction_links", 0)} dB, with an interval of ${A0("u_Diffraction_links", 1)} dB to ${A0("u_Diffraction_links", 2)} dB, and on the 15 troposcatter links ${A0("u_Troposcatter_links", 0)} dB, with an interval of ${A0("u_Troposcatter_links", 1)} dB to ${A0("u_Troposcatter_links", 2)} dB. The intervals are wide because each class mixes two groups of links, and a resample that draws a few more from one group moves the median from one group to the other. The groups themselves are tight: ${A0("u_w_under_0.12", 0)} dB (${A0("u_w_under_0.12", 1)} dB to ${A0("u_w_under_0.12", 2)} dB) where ITM's smooth-earth weight is under 0.12, and ${A0("u_w_0.12_or_more", 0)} dB (${A0("u_w_0.12_or_more", 1)} dB to ${A0("u_w_0.12_or_more", 2)} dB) elsewhere. The share of diffraction links more than 20 dB apart is ${A0("u_Diffraction_links_share", 0)}% (${A0("u_Diffraction_links_share", 1)}% to ${A0("u_Diffraction_links_share", 2)}%), a more stable summary than the median. The weight that best separates the groups is ${NU.u_split[0]}, with an interval of ${NU.u_split[1]} to ${NU.u_split[2]}. With 27 links the formal bimodality tests are inconclusive: a two-group mixture (means of ${A0("u_mix", 0)} dB and ${A0("u_mix", 1)} dB) fits only slightly better than one group by BIC, and Sarle's bimodality coefficient is ${NU.u_bc}, below the 0.555 that suggests two groups. In the line-of-sight class the interval is ${Z0(NU.u_Line_of_sight_links[1])} dB to ${Z0(NU.u_Line_of_sight_links[2])} dB.`));
body.push(...fig("s26", "s26_uncertainty_gap.png", "Median ITM minus P.2001 at 3 GHz with 95% bootstrap intervals, by ITM's mechanism class and by ITM's smooth-earth weight w on the diffraction links."));
body.push(P(`Against the measurements (${FN("s27")}), the mean errors over all 573 datasets are ${A1("um_All_itm", 0)} dB for ITM (${A1("um_All_itm", 1)} dB to ${A1("um_All_itm", 2)} dB), ${A1("um_All_p452", 0)} dB for P.452, and ${A1("um_All_p2001", 0)} dB for P.2001, so all three predict slightly too little loss overall, and the intervals overlap. From 1 GHz to 10 GHz, on 76 paths, every interval includes zero: ${A1("um_1-10 GHz_itm", 1)} dB to ${A1("um_1-10 GHz_itm", 2)} dB for ITM and ${A1("um_1-10 GHz_p2001", 1)} dB to ${A1("um_1-10 GHz_p2001", 2)} dB for P.2001. The measurements can't separate the models at the median.`));
body.push(...fig("s27", "s27_uncertainty_measured.png", "Mean predicted minus measured loss at 50% of time with 95% intervals from resampling measured paths, by group."));

// ===== Sensitivity
body.push(H1("Sensitivity to model settings"));
body.push(P(`The results use one set of model settings. To test whether another setting closes the gap, the 60 real-terrain links were rerun at 3 GHz and 50% of time with each ITM setting changed in turn: ground constants (poor and average), confidence (10% and 90%), each of the seven radio climates, N₀ of 280 and 360 N-units, and horizontal polarization. P.452 was also run with surface heights from the Copernicus surface model added to the profile, and P.452 and P.2001 with horizontal polarization.`));
body.push(P(`No setting closes the gap (${FN("s28")}). On the diffraction links the median ITM minus P.2001 is ${n1("sens_base_gap_dif")} dB with the baseline settings. Confidence moves it most, to ${A1("sens_itm_confidence 10 %_Diffraction", 1)} dB at 10% and ${A1("sens_itm_confidence 90 %_Diffraction", 1)} dB at 90%, because it shifts every ITM prediction by about 9 dB. Ground constants, radio climate, N₀, and polarization each move it by less than 1 dB at the median, although radio climate moves individual links by up to ${A1("sens_itm_climate 7_All", 2)} dB. Adding surface heights raises P.452's loss by a median of ${A1("sens_p452_surface heights_All", 0)} dB and up to ${A1("sens_p452_surface heights_All", 2)} dB on one link; the ITU models' polarization changes their loss by less than 0.01 dB at the median.`));
body.push(...fig("s28", "s28_sensitivity.png", "Median ITM minus P.2001 on the diffraction links at 3 GHz for each ITM setting tested. The band is the baseline ± 3 dB."));

// ===== Distance
body.push(H1("What the differences mean in distance"));
body.push(P(`On smooth land, the models reach each loss threshold from 150 dB to 180 dB within 5 km of each other (${FN("s22")}), because the steep slope beyond the radio horizon makes distance insensitive to a few dB. Over rough terrain, ITM's extra 30 dB to 45 dB of diffraction loss lets it reach a threshold much sooner, so an analysis with ITM computes smaller separation distances there than one with P.452 or P.2001.`));
body.push(...fig("s22", "s22_distance_threshold.png", "Distance at which the 50% loss first reaches each threshold on smooth land at 3 GHz."));
body.push(H2("Two real scenarios: Washington, DC, and Los Angeles"));
body.push(P(`To see what the gap does to an exclusion area, a receiver with a 10 m antenna was placed at the Washington Monument and at Los Angeles City Hall, and a grid of transmitters with 30 m antennas was laid out over 300 km by 300 km around each, at a 2.5 km step: ${n0("grid_dc_n")} transmitter sites per city. Each transmitter is evaluated alone (single entry) at 3 GHz on its own 30 m terrain profile with all three models. The next subsection shows that this grid is fine enough and large enough.`));
body.push(P(`Around Washington, DC, the models agree over most of the grid, with a median difference of ${n1("grid_dc_gap_median")} dB, but ${n0("grid_dc_share_gt20")}% of sites differ by more than 20 dB, mostly in the Blue Ridge and Appalachians to the west and northwest (${FN("s29")}). Around Los Angeles, where mountains ring the basin, the median difference is ${n1("grid_la_gap_median")} dB and ${n0("grid_la_share_gt20")}% of sites differ by more than 20 dB, up to ${n0("grid_la_gap_max")} dB. P.452 matches P.2001 within ${r1(NU.grid_dc_p452_p2001_maxabs)} dB around DC and within ${r1(NU.grid_la_p452_p2001_maxabs)} dB around Los Angeles. The outlines show where a single transmitter would need more than 160 dB of loss: the ITU models' exclusion zone extends well beyond ITM's.`));
body.push(...fig("s29", "s29_grid_maps.png", "ITM minus P.2001 at 3 GHz and 50% of time from each transmitter site (30 m antenna) to the receiver (star, 10 m antenna), single entry, on a 300 km grid at a 2.5 km step. Outlines: exclusion zones at a required loss of 160 dB, P.2001 (purple) and ITM (black dashed). State lines and coastlines in gray."));
body.push(P(`A required loss turns these maps into an exclusion area: the sites where one transmitter alone would get less loss than the protection criterion needs. The required loss is the transmitter's e.i.r.p. plus the receiving antenna gain minus the interference threshold, all in decibels; for example, 61 dBm in 10 MHz into a 0 dBi antenna with a threshold of -105 dBm in 10 MHz needs 166 dB. At a required loss of 160 dB (${FN("s30")}), P.2001 and P.452 exclude ${n0("grid_dc_p2001_160_area")} km² around DC and ITM ${n0("grid_dc_itm_160_area")} km²; around Los Angeles the areas are ${n0("grid_la_p2001_160_area")} km² and ${n0("grid_la_itm_160_area")} km², and the farthest P.2001 exclusion is ${n0("grid_la_p2001_160_dmax")} km from the receiver. At 140 dB, close to the receiver, the models are close: ${n0("grid_dc_p2001_140_area")} km² against ${n0("grid_dc_itm_140_area")} km² around DC.`));
body.push(...fig("s30", "s30_grid_exclusion.png", "Area of the 300 km grid where a single transmitter would get less loss than the required loss, at 50% of time, by model. P.452 matches P.2001."));
body.push(H2("Is the grid fine enough and large enough?"));
body.push(P(`Two extra runs per city test the grid: the 300 km grid at a 2.5 km step, and a 100 km grid at a 1 km step. Coarser and smaller grids are subsets of these, so the exclusion area can be recomputed for widths of 100 km, 200 km, and 300 km and steps of 1 km, 2.5 km, and 5 km (${FN("s32")}). Two checks decide whether a grid is adequate: the area changes little when the step is refined, and no excluded site lies on the grid's outer edge.`));
body.push(P(`Step: on the 100 km grid from 150 dB to 170 dB, a 2.5 km step gives areas within ${n0("conv_step25_maxpct")}% of the 1 km step, and a 5 km step within ${n0("conv_step5_maxpct")}%. A 2.5 km step is fine enough; 5 km is adequate for a first look. Extent: around DC the 100 km grid already holds the whole exclusion zone up to 170 dB (${A0("conv_dc_p2001_160_50_2.5", 0)} km² at 160 dB for P.2001 on every grid size). Around Los Angeles it does not: excluded sites reach the edge of the 100 km grid from 150 dB up, and the P.2001 area at 160 dB grows from ${A0("conv_la_p2001_160_50_2.5", 0)} km² on the 100 km grid to ${A0("conv_la_p2001_160_100_2.5", 0)} km² on the 200 km grid and ${A0("conv_la_p2001_160_150_2.5", 0)} km² on the 300 km grid, with no excluded sites on its edge. The 100 km grid used in the first draft understated the Los Angeles exclusion area by about a fifth. Rough terrain, where mountain sites with long views of the receiver lie far from it, needs a wider grid than flat terrain.`));
body.push(...fig("s32", "s32_grid_convergence.png", "Exclusion area at a required loss of 160 dB against grid width, for grid steps of 1 km (diamond), 2.5 km (filled circle), and 5 km (open circle)."));

body.push(H2("Clutter at the receiver"));
body.push(P(`The grids so far use bare-earth loss. A receiver 10 m high in a suburban or urban area sits in clutter, so the grids were rerun with the terrestrial clutter loss of Recommendation ITU-R P.2108-1 Section 3.2 added at the receiver.`, fn("Recommendation ITU-R P.2108-1, Prediction of clutter loss, 2021. Implementation: nicklasorte/itu_p2108, a port of the NTIA reference code (NTIA/p2108 v1.1)."), ` That loss depends only on frequency, distance, and the percentage of locations, so it is the same for all three models: at 3 GHz and 2 km or more it is ${n1("gclut_loss_p10")} dB at 10% of locations, ${n1("gclut_loss")} dB at 50%, and ${n1("gclut_loss_p90")} dB at 90%. The 30 m transmitter is taken to be above the clutter.`));
body.push(P(`Clutter changes the areas more than the choice of model does (${FN("s36")}). At a required loss of 160 dB and 50% of locations, the exclusion area around Washington, DC, falls from ${n0("grid_dc_itm_160_area")} km² to ${A0("gclut_dc_itm_rx_p50_160", 0)} km² for ITM and from ${n0("grid_dc_p2001_160_area")} km² to ${A0("gclut_dc_p2001_rx_p50_160", 0)} km² for P.2001, and around Los Angeles from ${n0("grid_la_itm_160_area")} km² to ${A0("gclut_la_itm_rx_p50_160", 0)} km² for ITM and from ${n0("grid_la_p2001_160_area")} km² to ${A0("gclut_la_p2001_rx_p50_160", 0)} km² for P.2001. The models nearly agree at 160 dB with clutter, because the excluded points move inside about 25 km, where most paths are line of sight. The difference returns at larger required losses: at 190 dB, P.2001's area is ${A0("gclut_dc_p2001_rx_p50_190", 0)} km² against ${A0("gclut_dc_itm_rx_p50_190", 0)} km² for ITM around DC, and ${A0("gclut_la_p2001_rx_p50_190", 0)} km² against ${A0("gclut_la_itm_rx_p50_190", 0)} km² around Los Angeles. Clutter acts like lowering the required loss by about ${n0("gclut_loss")} dB: it decides where on the curve an analysis sits, and the model decides the curve.`));
body.push(...fig("s36", "s36_grid_clutter.png", "Single-entry exclusion area against required loss at 3 GHz and 50% of time, without clutter (dashed) and with ITU-R P.2108 Section 3.2 clutter loss at 50% of locations at the receiver (solid), on the 300 km grids."));

// ===== Implications
body.push(H1("What the comparison means for analyses"));
body.push(B({ b: "Line of sight: the choice of model matters little. " }, "The three models agree within a fraction of a decibel at the median."));
body.push(B({ b: "Rough-terrain paths of about 15 km to 150 km: the choice matters most. " }, `ITM predicts a median of ${g("Diffraction")} dB more loss than the ITU models on diffraction links, so it gives smaller separation distances at the median. The gap grows with frequency.`));
body.push(B({ b: "Exclusion areas can differ by a factor of about two. " }, `In the two city scenarios, the ITU models' exclusion area at a required loss of 160 dB is ${r1(NU.grid_dc_p2001_160_area / NU.grid_dc_itm_160_area)} times ITM's around DC and ${r1(NU.grid_la_p2001_160_area / NU.grid_la_itm_160_area)} times around Los Angeles.`));
body.push(B({ b: "Small time percentages: the choice matters through ducting. " }, "The ITU models give much less loss than ITM at 1% of time and below over water and on long paths, so they give larger separation distances at those percentages."));
body.push(B({ b: "In mountains, the truth lies between the models. " }, `Near 3 GHz on rough Colorado paths beyond 15 km, ITM predicts a median of ${A0("its3_r2far_itm", 1)} dB too much loss and the ITU models ${A0("its3_r2far_p2001", 1).replace("-", "")} dB too little. On gentler terrain ITM is closer. Neither model should be used on mountainous paths without a sensitivity run with the other.`));
body.push(B({ b: "Western analyses are the most exposed. " }, `On western terrain the median gap is ${n0("west_gap_med")} dB, so the model choice can change a western separation distance far more than an eastern one.`));
body.push(B({ b: "Clutter can matter as much as the model. " }, `Trees or a building next to a terminal added a median of ${A1("its_pairs_3", 0)} dB near 3 GHz in the ITS measurements, and P.2108 clutter at the receiver shrinks the city exclusion areas several times over. An analysis should state its clutter assumption as clearly as its model.`));
body.push(P("The differences are large enough to change an analysis outcome, so the model choice should be stated, justified, and tested for sensitivity."));

// ===== Look deeper
body.push(H1("Where to look deeper"));
startList();
body.push(N({ b: "The equation-by-equation comparison. " }, "The plan section lists 29 items, starting with synthetic two-obstacle and rough-terrain families that would map where ITM's extended diffraction line and P.2001's delta-Bullington loss part, and a Monte Carlo combination of P.2001's sub-models."));
body.push(N({ b: "Which diffraction prediction is right over rough terrain? " }, `The ITS mountain measurements put the truth between ITM and the ITU models, but ${n0("its3_r2far_cens")}% of those results were below the receiver's sensitivity, and the profiles come from 1950s maps. New measurements on rough paths of 15 km to 150 km near 3 GHz, with more sensitive receivers and 30 m terrain, would pin down the diffraction loss.`));
body.push(N({ b: "Should NTIA measure from 3 GHz to 10 GHz? " }, "The databank has few usable datasets above 3 GHz. A short campaign on a few diffraction and troposcatter paths would anchor the comparison."));
body.push(N({ b: "Do aggregate-interference results depend on ducting? " }, "The ITU models predict far less loss than ITM at small time percentages, from a mechanism ITM lacks."));
body.push(N({ b: "Which clutter loss fits each site? " }, "P.2108 Section 3.2 is a statistical model for urban and suburban terminals. Site-specific clutter from land-cover or lidar data, and measured clutter near 3 GHz, would show whether the statistical value fits a given receiver."));

// ===== Limitations
body.push(H1("Limitations"));
body.push(B(`The real-terrain sample is small: ${nLinks} links in three mid-Atlantic regions, ${n0("west_n")} in three western regions, and five archetype paths, at one frequency.`));
body.push(B("The measurements are old, mostly long trans-horizon paths, sparse above 3 GHz, and used by the models' developers."));
body.push(B("The ITS spot measurements are single median values, so they test 50% of time only; their profiles come from 1950s topographic maps, and many mountain results are only lower bounds."));
body.push(B("Each model ran with defaults this paper chose; the sensitivity section tests the main ones, but not ITM's variability mode; P.2108 clutter loss is tested on the grids only."));
body.push(B("The city scenarios are single entry, with one antenna height each, on a 300 km grid at a 2.5 km step; aggregate interference from many transmitters can change the areas."));
body.push(B("All results are basic transmission loss with isotropic antennas, without clutter or building entry loss."));

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
  "ITU-R Study Group 3 databanks (DBSG3), Table III, clear-air trans-horizon basic transmission loss statistics, long-term data. https://www.itu.int/oth/R0A04/en",
  "EPSG Geodetic Parameter Dataset, Tokyo to WGS 84 (1). https://epsg.io/63016405",
  "U.S. Geological Survey, 3D Elevation Program (3DEP), 1 arc-second digital elevation models.",
  "P. L. McQuate, J. M. Harman, and A. P. Barsis, Tabulations of Propagation Data over Irregular Terrain in the 230- to 9200-MHz Frequency Range, Part I: Gunbarrel Hill Receiver Site, ESSA Technical Report ERL 65-ITS 58, 1968. https://its.ntia.gov/publications/download/essa_erl_65-ITS_58.pdf",
  "G. A. Hufford and F. K. Steele, Tabulations of Propagation Data over Irregular Terrain in the 75- to 8400-MHz Frequency Range, Part V: Virginia, NTIA Report 91-282, 1991. https://its.ntia.gov/publications/download/91-282.pdf",
  "NTIA Institute for Telecommunication Sciences, Legacy radio propagation data. https://its.ntia.gov/data/legacy-radio-propagation-data/",
  "Recommendation ITU-R P.2108-1, Prediction of clutter loss, 2021.",
  "M. E. Johnson, M. J. Miles, P. L. McQuate, and A. P. Barsis, Tabulations of VHF Propagation Data Obtained over Irregular Terrain at 20, 50, and 100 MHz, ESSA Technical Report IER 38-ITSA 38, 1967.",
  "L. G. Hause, F. G. Kimmett, and J. M. Harman, UHF Radio Propagation Data for Low Antenna Heights, ESSA Technical Report ERL 134-ITS 93, 1969.",
  "E. L. Kaplan and P. Meier, Nonparametric estimation from incomplete observations, Journal of the American Statistical Association, 53(282), 1958.",
];
startList();
REFS.forEach((r) => body.push(N(r)));

// ===== Reproducing
body.push(new Paragraph({ children: [new PageBreak()] }));
body.push(H1("Appendix: reproducing the analysis"));
body.push(P("All analysis is MATLAB code in the matlab_itm repository, folder docs/model_comparison. MATLAB writes every result to CSV files in the repository, and Python only draws the figures from those files. To reproduce the paper, do the following:"));
startList();
body.push(N("Clone matlab_itm, itu_p2001, and matlab_itu_p452 into one folder."));
body.push(N("In MATLAB R2025b with Mapping and Statistics and Machine Learning Toolboxes, run run_3ghz_rev1. It runs make_wp_figures_rev1 at 3 GHz, diffraction_decomposition_rev1, export_deep_dive_data_rev1, sensitivity_rev1, grid_separation_rev1 for Washington, DC, and Los Angeles, western_terrain_rev1, uncertainty_rev1, paper_numbers_3ghz_rev1, and figure_data_3ghz_rev1, which computes the data every figure plots. Run grid_convergence_rev1 for the 300 km and 1 km grids."));
body.push(N("For the measurements, run compare_dbsg3_rev1 (point-to-point, Table III), compare_dbsg3_area_rev1 (point-to-area, Tables VI-1 and VI-2), compare_its_phase2_rev1 (ITS Phase 2 spot measurements), and compare_its_spot_rev1 (ITS Phase 1 and low-antenna measurements) before paper_numbers_3ghz_rev1. For the grids with clutter, run grid_clutter_rev1 (needs nicklasorte/itu_p2108)."));
body.push(N("For the algorithm comparison, run algorithm_comparison_rev1, which uses ITM's info.lines diagnostic (matlab_itm commit 5081c68 or later)."));
body.push(N("Run python3 make_wp_figures_3ghz.py, python3 make_wp_body_figures_rev1.py, and python3 make_wp_algorithm_figures.py to draw the figures from the CSV files."));
body.push(N("Run node build_wp_docx_rev4.js to rebuild this document. Every number in the text comes from figures/numbers_3ghz.json, which paper_numbers_3ghz_rev1 writes."));
body.push(P("The results are in chart_data/ (model results, uncertainty, sensitivity, grids, and measurement summaries) and figures/table_*.csv (model tables and the measurement comparisons). The model code cited in the footnotes is pinned to these commits:"));
body.push(B({ b: "matlab_itm: " }, SHA.itm));
body.push(B({ b: "itu_p2001: " }, SHA.p2001));
body.push(B({ b: "matlab_itu_p452: " }, SHA.p452));
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
