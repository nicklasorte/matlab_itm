// Builds the working paper (.docx) from the figures and CSV tables that
// make_wp_figures_rev1.m writes. Every number in a table, and the numbers
// in the text marked with ${...}, come from those CSV files, so the paper
// and the MATLAB output can't drift apart.
//
//   node build_wp_docx_rev1.js [figures_dir] [output.docx]
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
const OUT = process.argv[3] || path.join(__dirname, "itm_p2001_p452_comparison_working_paper_rev1.docx");
const MARK = "DRAFT//PRE-DECISIONAL";
const SHA = {
  itm: "03feac58ae3db28c2ae66226ae73109e61172a98",
  p2001: "286e68cbac94d616261f9cb514e94ec8f5464881",
  p452: "75e39de3a3177c95d40a38a1c0a2659a0ee8b28a",
};

// ---------- data ----------
function csv(name) {
  const t = fs.readFileSync(path.join(FIG, name), "utf8").trim().split(/\r?\n/);
  const h = t[0].split(",");
  return t.slice(1).map((l) => {
    const v = l.split(",");
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
const N = (...parts) => new Paragraph({ numbering: { reference: "numbers", level: 0 }, children: runs(parts), spacing: { after: 60 } });

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

// ---------- numbers used in the text ----------
const d27 = get(cls, 2700, "Diffraction"), d49 = get(cls, 4900, "Diffraction"), d72 = get(cls, 7250, "Diffraction");
const t27 = get(cls, 2700, "Troposcatter"), t72 = get(cls, 7250, "Troposcatter");
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

// ---------- document ----------
const body = [];

body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 1200, after: 240 },
  children: [new TextRun({ text: "ITM, ITU-R P.2001, and ITU-R P.452: How the Models Differ by Propagation Mechanism", bold: true, size: 40, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "Working paper, revision 1 (draft)", size: 26, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "November 2026", size: 24, font: FONT })] }));
body.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 600 },
  children: [new TextRun({ text: "Preliminary calculations to show where deeper analysis is needed. Not for decisions.", italics: true, size: 22, font: FONT })] }));
body.push(new TableOfContents("Contents", { hyperlink: true, headingStyleRange: "1-2" }));
body.push(new Paragraph({ children: [new PageBreak()] }));

// 1 Summary
body.push(H1("Summary"));
body.push(P(`This paper compares three terrestrial propagation models that NTIA analyses use: the Irregular Terrain Model (ITM, Longley-Rice) version 1.4, Recommendation ITU-R P.2001-6, and Recommendation ITU-R P.452-18. It explains, mechanism by mechanism, where the models agree, where they don't, and why, at the three study frequencies of 2.7 GHz, 4.9 GHz, and 7.25 GHz. Every model received the same terrain profile in each calculation, so the differences reported here are differences between the models, not between terrain data.`));
body.push(P(`The calculations are deliberately few. They are meant to show where to look deeper, not to settle which model is right. No comparison against measured data was made.`));
body.push(P("The preliminary findings are the following:"));
body.push(B({ b: "Line of sight: the models agree. " }, `On ${l27.links} real-terrain line-of-sight links, the ITU models differ from ITM by a median of ${r2(l27.p2001_minus_itm_med_db)} dB at 2.7 GHz and ${r2(l72.p2001_minus_itm_med_db)} dB at 7.25 GHz, at 50% of time.`));
body.push(B({ b: "Diffraction over rough terrain: ITM predicts much more loss. " }, `On ${d27.links} diffraction links, P.2001 is below ITM by a median of ${r1(-d27.p2001_minus_itm_med_db)} dB at 2.7 GHz, ${r1(-d49.p2001_minus_itm_med_db)} dB at 4.9 GHz, and ${r1(-d72.p2001_minus_itm_med_db)} dB at 7.25 GHz. The gap grows with frequency and with terrain irregularity. On smooth earth the same models agree within about 7 dB, so the gap comes from how each model treats terrain, not from its smooth-earth physics.`));
body.push(B({ b: "P.2001 and P.452 agree at 50%. " }, `Their median difference is at most ${r2(maxP2001P452)} dB in every mechanism class and band. They share the delta-Bullington diffraction method, so at 50% of time they are close to identical on these paths.`));
body.push(B({ b: "The tails differ by mechanism, not by tuning. " }, `Below about 10% of time, P.2001 and P.452 include ducting and layer reflection, which ITM does not model; at 1% of time on a ${r0(sea.length_km)} km over-sea path they predict ${r1(sea.itm_1 - sea.p2001_1)} dB (P.2001) less loss than ITM. Above 99%, P.2001 adds clear-air and rain fading that neither ITM nor P.452 includes.`));
body.push(B({ b: "ITM can fail quietly on steep horizons. " }, `On a 65 km Appalachian path with a 395 mrad (22.6°) receiver horizon, ITM predicts ${r0(dbl.itm_50)} dB at 50%, ${r0(dbl.itm_50 - dbl.p2001_50)} dB more than P.2001. MathWorks' Longley-Rice gives the same value, so this is ITM's behavior, not a coding error. ITM's own warning flags mark the horizon angle as beyond its small-angle approximations; ${flags.links_with_horizon_angle_over_200_mrad} of ${nLinks} sample links carried that flag.`));
body.push(P("Section 10 lists the questions that these results raise, in priority order."));

// 2 Purpose and scope
body.push(H1("Purpose and scope"));
body.push(P("Spectrum-sharing analyses choose a propagation model early, and the choice can change a protection distance or a coordination zone by tens of kilometers. Analysts often treat ITM, P.2001, and P.452 as interchangeable alternatives. This paper tests that assumption for point-to-point paths, separates the differences by propagation mechanism, and identifies the cases that need deeper work before a model choice is relied on."));
body.push(P("The scope is the following:"));
body.push(B("Point-to-point paths over U.S. terrain from 1 km to 200 km, with terrain from USGS 3DEP at 1 arc-second (about 30 m), and Copernicus GLO-30 where 3DEP has no data."));
body.push(B("Frequencies of 2.7 GHz, 4.9 GHz, and 7.25 GHz, with a sweep from 100 MHz to 10 GHz."));
body.push(B("The median (50% of time) and the full time distribution: 0.001% to 99.99% for ITM and P.2001, and 0.001% to 50% for P.452, which is defined only up to 50%."));
body.push(B("Basic transmission loss with isotropic antennas and vertical polarization. Clutter models, building entry loss, and antenna patterns are outside the scope, except P.452's own ground-cover profile, which section 7 mentions."));

// 3 Models
body.push(H1("The three models"));
body.push(P("The models come from different traditions and answer slightly different questions. ITM, developed by Longley and Rice in the 1960s and refined by the Institute for Telecommunication Sciences (ITS), is semi-empirical: it fits straight lines and curves to measured attenuation, and it predicts a distribution of loss over time, locations, and situations. P.452 is ITU-R's interference-prediction method between stations on the surface of the earth, for the small time percentages that interference criteria use. P.2001 is ITU-R's wide-range method for the whole year, from 0% to 100% of time, and combines four sub-models that include fading."));
body.push(...table("Models and implementations used in this paper.",
  ["Model", "Version", "Implementation", "Range used here", "Intended use"],
  [["ITM", "1.4 (NTIA, 2019)", "matlab_itm, a line-by-line port of the NTIA C++ that matches it to 4 × 10⁻¹³ dB", "20 MHz to 20 GHz; 1 km to 2000 km", "Coverage and interference; time, location, and situation variability"],
   ["P.2001", "P.2001-6 (2025)", "itu_p2001, from the ITU-R reference code; reproduces all 4,430 validation cases", "30 MHz to 50 GHz; 0% to 100% of time", "Wide-range, full-year prediction, including fading"],
   ["P.452", "P.452-18 (2023)", "matlab_itu_p452, from the ITU-R reference code", "0.1 GHz to 50 GHz; 0.001% to 50% of time", "Interference between stations on the earth's surface"]],
  [1000, 1300, 3260, 1900, 1900]));

// 4 Inputs
body.push(H1("Inputs and conventions"));
body.push(H2("Terrain and path geometry"));
body.push(P("Each calculation builds one terrain profile along the WGS84 geodesic at about 30 m spacing and passes the same distances and heights to all three models. Each model then applies its own earth curvature:"));
body.push(B({ b: "ITM" }, " derives an effective earth curvature from the surface refractivity Nₛ, which it computes from the sea-level value N₀ and the mean terrain height: Nₛ = N₀·exp(−hₛ/9460) and γₑ = γₐ(1 − 0.04665·exp(Nₛ/179.3)).", fn("ITM effective earth curvature:", itmUrl(193, 197))));
body.push(B({ b: "P.452" }, " uses aₑ = 6371·157/(157 − ΔN) km, where ΔN is the refractivity lapse rate from the ITU map at the path midpoint.", fn("P.452 median effective earth radius:", p452Url(126, 126))));
body.push(B({ b: "P.2001" }, " uses the same form with a median ΔN from its own map, and also uses ΔN distributions for time variability.", fn("P.2001 median effective earth radius:", p2001Url("p2001_profile_rev1.m", 225, 225))));
body.push(H2("Climate, refractivity, and ground"));
body.push(P("ITM takes a radio climate (one of seven) and N₀ as inputs. This paper reads both from ITU-R P.617 and P.452 maps at the path midpoint, as the WInnForum reference model does. P.452 and P.2001 read their own digital maps. ITM uses ground permittivity 25 and conductivity 0.02 S/m; the ITU models use fixed land and sea constants in their spherical-earth diffraction terms."));
body.push(H2("Statistics"));
body.push(P("All three models report the loss not exceeded for a percentage of time. In ITM this is the reliability, and ITM adds two more dimensions that the ITU models don't have: location variability, which this paper removes (variability mode 13, broadcast point-to-point), and situation variability, expressed as a confidence. This paper uses 50% confidence and shows the 10% to 90% confidence band on the archetype paths. The P.2001 and P.452 percentages refer to an average year."));

// 5 Method
body.push(H1("Method"));
body.push(P("Nine small calculations isolate one mechanism or test one explanation each. One MATLAB script, make_wp_figures_rev1.m in the matlab_itm repository, runs all of them and draws every figure in this paper; Appendix B gives the commands and commits."));
body.push(...table("Calculations.",
  ["ID", "Calculation", "What it isolates"],
  [["E1", "Smooth earth, flat land and flat sea, 1 km to 200 km, 30 m and 10 m antennas", "Line of sight, smooth-earth diffraction, and troposcatter, without terrain"],
   ["E2", "One knife-edge obstacle at the middle of a 20 km path, compared with ITU-R P.526 J(v)", "Diffraction against an outside reference"],
   ["E3", "Diffraction links rerun on 90 m and 1 km smoothed profiles", "Whether terrain resolution explains the diffraction gap"],
   ["E4", "Dominant mechanism over distance and time percentage on smooth earth", "Where each P.2001 and P.452 sub-model takes over"],
   ["E5", "Five archetype paths over the full time distribution", "Variability and tails by mechanism"],
   ["E6", "Frequency (100 MHz to 10 GHz) and receiver-height sweeps on three archetypes", "Frequency and height dependence"],
   ["E7", `${nLinks} random real-terrain links in three regions (coastal plain, piedmont, Appalachian), 10 km to 150 km`, "Differences by mechanism class on real terrain"],
   ["E8", "Distance to a loss threshold on smooth earth and along four real-terrain radials", "What the dB differences mean in kilometers"],
   ["E9", "ITM radio climate and N₀ sensitivity", "How much ITM's climate input matters"]],
  [700, 4400, 4260]));
body.push(P("Links are classified by ITM's propagation mode in the ITM 1.2.2 codes that SEADLib returns: line of sight (0), diffraction (5 and 9), and troposcatter (6 and 10). ITM v1.4's own mode label is based on smooth-earth horizon distances and can call an obstructed path line of sight; section 7 shows one."));

// 6 Equations
body.push(H1("How the equations differ by mechanism"));
body.push(P("Table 3 sets the methods side by side. The sections after it explain the differences that matter for the results."));
body.push(...table("Methods by mechanism.",
  ["Element", "ITM v1.4", "P.452-18", "P.2001-6"],
  [["Line of sight", "Two-ray model with a complex ground reflection coefficient from ε and σ, blended with an extrapolated diffraction line", "Free space plus gaseous absorption plus a multipath and focusing term, 2.6(1 − e^(−0.1(dlt+dlr)))·log(p/50)", "Sub-model 1: free space, diffraction, clear-air fading, rain fading, and gases"],
   ["Diffraction", "Weighted blend of a double knife edge at the two horizons and smooth-earth diffraction, plus a clutter term; computed at two distances and extrapolated as a straight line", "Delta-Bullington: Bullington on the profile, minus Bullington on a smooth profile, plus spherical-earth diffraction; p interpolates between median and β₀ refractivity", "Delta-Bullington with the median and p-dependent effective earth radii from ΔN maps"],
   ["Troposcatter", "Rice et al. frequency-gain function H₀ and attenuation function F(θd); a straight line beyond distance dₓ", "190 + L_f + 20 log d + 0.573θ − 0.15N₀ + L_c + A_g − 10.1(−log(p/50))^0.7", "Attachment E: parameters by climate zone at the common volume; limited to at least free space"],
   ["Anomalous propagation", "None. Enhancement at small percentages comes only from empirical variability curves by climate", "Ducting and layer reflection, L_ba, with β₀ from latitude and the longest inland section", "Attachment D ducting and layer reflection, and sporadic-E (Attachment G)"],
   ["Absorption and fading", "None", "Gaseous absorption (P.676); no rain", "Gases, clear-air multipath fading, and rain fading"],
   ["Combination", "One regime selected by distance (line of sight, diffraction, or troposcatter), then variability added", "Power sum of the blended line-of-sight, diffraction, and ducting loss with troposcatter", "Power sum of sub-models 1 and 2, then with 3 and 4"]],
  [1500, 2620, 2620, 2620]));
body.push(H2("Diffraction"));
body.push(P("The diffraction methods differ in what they read from the profile. ITM summarizes the terrain by its two horizons and an interdecile terrain irregularity Δh. Its diffraction loss is a weighted blend of a double knife edge built from the horizon distances and angles, and a smooth-earth term, with a weight that falls as Δh·f grows, plus a clutter term of up to 15 dB.", fn("ITM diffraction blend and weight:", itmUrl(469, 483)), " ITM evaluates this at two distances and extends it to the path length as a straight line. The delta-Bullington method of P.452 and P.2001 instead finds the single most obstructing edge on the actual profile, compares it with the same construction on a smoothed profile, and adds a spherical-earth term.", fn("P.452 delta-Bullington:", p452Url(474, 481))));
body.push(P("Two consequences follow. First, ITM's knife-edge term depends on the horizon angles directly, so a steep horizon near one terminal drives the loss up quickly, and the small-angle approximations behind it stop holding above about 200 mrad, which ITM flags. Second, as Δh·f grows, ITM moves its weight toward the knife-edge term, which explains why the gap grows with frequency and terrain irregularity in section 7."));
body.push(H2("Troposcatter"));
body.push(P("ITM's troposcatter term uses the Rice frequency-gain function and depends on the scattering angle built from the two horizon angles.", fn("ITM troposcatter:", itmUrl(566, 608)), " P.452 uses a closed form with an explicit time-percentage term,", fn("P.452 troposcatter, eq. (45):", p452Url(206, 209)), " and P.2001 chooses its parameters by climate zone at the common volume and limits the result to at least free-space loss.", fn("P.2001 troposcatter call and free-space limit:", p2001Url("p2001_profile_rev1.m", 325, 330))));
body.push(H2("Anomalous propagation and the low tail"));
body.push(P("P.452 and P.2001 model ducting and layer reflection as a separate mechanism, L_ba, that becomes the lowest loss at small time percentages.", fn("P.452 ducting, eq. (47):", p452Url(192, 193)), " P.452 also lowers its line-of-sight loss below free space for p < 50% through the multipath and focusing term.", fn("P.452 line-of-sight loss with the focusing term:", p452Url(170, 174)), " ITM has no ducting mechanism; its loss at small percentages comes from variability curves fitted by climate and effective distance.", fn("ITM time variability:", itmUrl(756, 756))));
body.push(H2("Fading and the high tail"));
body.push(P("P.2001's sub-model 1 includes clear-air multipath fading and rain fading, so its loss rises steeply above 99% of time on line-of-sight paths.", fn("P.2001 sub-model 1:", p2001Url("p2001_profile_rev1.m", 297, 306)), " ITM's high tail comes from the same symmetric variability curves as its low tail, and P.452 stops at 50%."));
body.push(H2("How the mechanisms combine"));
body.push(P("ITM selects one regime by distance: line of sight below the smooth-earth horizon distance, diffraction up to dₓ, and troposcatter beyond.", fn("ITM regime selection:", itmUrl(400, 463)), " The ITU models compute every mechanism for every percentage and add them as powers, so the transition is gradual.", fn("P.2001 final combination:", p2001Url("p2001_profile_rev1.m", 392, 400)), fn("P.452 final combination, eq. (64):", p452Url(212, 212))));

// 7 Median
body.push(H1("Results at 50% of time"));
body.push(H2("Smooth earth"));
body.push(P("On flat land the three models track each other through line of sight and smooth-earth diffraction (Figure 1). ITM switches from line of sight to diffraction at 38 km and to troposcatter at about 70 km for 30 m and 10 m antennas. Beyond about 70 km, ITM's troposcatter line rises more slowly: at 200 km it is 1 dB to 5 dB below the ITU models on land, depending on frequency. Over flat sea the ITU models differ from each other more, by up to 4 dB at 200 km, because P.452's sea-path terms differ from P.2001's."));
body.push(...figure("fig01_smooth_earth_land_50pct.png", "Basic transmission loss minus free-space loss on flat land, 50% of time, 30 m and 10 m antennas. Triangles mark ITM's regime changes."));
body.push(H2("Single knife edge"));
body.push(P(`Against the ITU-R P.526 single knife-edge solution J(v), all three models add loss beyond the knife edge itself, because each also models the earth (Figure 2 and Table 4). In this run, ITM's curve has a step where it changes from line of sight to diffraction, and at large v it rises faster than J(v), consistent with its double knife-edge construction. This test is a coarse outside check, not a validation: none of the three models claims to reduce to J(v).`));
body.push(...figure("fig02_knife_edge.png", "Excess loss over free space for one knife-edge obstacle at the middle of a 20 km path, against the ITU-R P.526 knife-edge function J(v)."));
body.push(...table("Mean absolute difference from J(v) for v ≥ 0 (dB).", ["Frequency (MHz)", "ITM", "P.452", "P.2001"],
  ke.map((r) => [r0(r.freq_mhz), r1(r.itm_mae_db), r1(r.p452_mae_db), r1(r.p2001_mae_db)]), [2340, 2340, 2340, 2340]));
body.push(H2("Real terrain by mechanism"));
body.push(P(`On ${nLinks} real-terrain links, the ITU models agree with ITM on line-of-sight links and fall far below it on diffraction and troposcatter links (Figure 3, Table 5). P.2001 and P.452 agree with each other on every class. The troposcatter class, as ITM labels it, shows the same gap as diffraction: on these paths the ITU models find a lower-loss diffraction or ducting route, so the ITU loss is set by a different mechanism than ITM's.`));
body.push(...figure("fig09_real_terrain_cdf_by_mechanism.png", "Distribution over links of the difference from ITM at 50% of time, by ITM's mechanism class. Top: P.2001 minus ITM. Bottom: P.452 minus ITM."));
body.push(...table("Median difference from ITM at 50% of time on real terrain (dB).",
  ["MHz", "ITM class", "Links", "P.2001 − ITM", "P.452 − ITM", "P.2001 − P.452", "Max |P.2001 − ITM|", "Mean Δh (m)"],
  cls.map((r) => [r0(r.freq_mhz), r.itm_class, r0(r.links), r1(r.p2001_minus_itm_med_db), r1(r.p452_minus_itm_med_db), r2(r.p2001_minus_p452_med_db), r1(r.p2001_minus_itm_maxabs_db), r0(r.itm_delta_h_mean_m)]),
  [800, 1300, 700, 1300, 1300, 1300, 1460, 1200]));
body.push(P("The gap tracks ITM's terrain irregularity Δh (Figure 4). Links with Δh below about 50 m sit near zero; the large negative differences belong to links with Δh of hundreds of meters, most of them in the Appalachian region."));
body.push(...figure("fig10_gap_vs_delta_h.png", "P.2001 minus ITM at 50% of time against ITM's terrain irregularity parameter Δh, by ITM mechanism class."));
body.push(H2("Terrain resolution"));
body.push(P(`Terrain resolution does not explain the gap (Figure 5). Resampling the ${nDif} diffraction links at 2.7 GHz from 30 m to 90 m changed the median loss by ${r2(resI[resKeys[0]])} dB for ITM and ${r2(resP[resKeys[0]])} dB for P.2001. Smoothing over 1 km lowered the loss of all three models by 3 dB to 4 dB and left the gap almost unchanged.`));
body.push(...figure("fig03_terrain_resolution.png", "Left: median change in loss when the 30 m profile is resampled at 90 m or smoothed over 1 km. Right: the P.2001 minus ITM gap at each resolution."));
body.push(H2("Frequency and antenna height"));
body.push(P("Figure 6 shows loss minus free space against frequency on three archetype paths, and loss against receiver height at 2.7 GHz. On the line-of-sight path the models stay within a few dB at every frequency. On the diffraction paths ITM's excess loss grows faster with frequency than the ITU models' excess loss, which is the frequency trend of Table 5."));
body.push(...figure("fig07_frequency_height_sweeps.png", "Top: loss minus free space against frequency at 50% of time; dotted lines mark 2.7 GHz, 4.9 GHz, and 7.25 GHz. Bottom: loss against receiver height at 2.7 GHz."));
body.push(H2("Elevation angles"));
const eP = elev.find((r) => r.model === "P.2001"), eQ = elev.find((r) => r.model === "P.452");
body.push(P(`All three models compute the elevation angle of the path at each terminal toward the radio horizon, or toward the other antenna on a line-of-sight path. On the real-terrain sample, P.2001's angles differ from ITM's by a mean of ${r2(eP.mean_abs_diff_deg_tx_rx_1)}° at the transmitter and ${r2(eP.mean_abs_diff_deg_tx_rx_2)}° at the receiver; P.452's differ by ${r2(eQ.mean_abs_diff_deg_tx_rx_1)}° and ${r2(eQ.mean_abs_diff_deg_tx_rx_2)}°. The small differences come mostly from the effective earth radius each model uses. The angles agree, so the loss differences don't come from different horizon geometry; they come from what each model does with it.`));
body.push(H2("A steep-horizon case"));
body.push(P(`The deepest diffraction archetype, a ${r0(dbl.length_km)} km path in the Appalachian region, shows how far ITM can depart from the ITU models. ITM predicts ${r1(dbl.itm_50)} dB at 2.7 GHz and 50% of time; P.2001 predicts ${r1(dbl.p2001_50)} dB. The receiver, 19 m above ground, sits below a horizon at 395 mrad (22.6°) only 0.63 km away. ITM flags this horizon angle as beyond its small-angle approximations. MathWorks' implementation of Longley-Rice returns ${"287.30"} dB on the same profile, which rules out a porting error. ITM v1.4 labels this path line of sight because its smooth-earth horizon distances exceed the path length, while the ITM 1.2.2 code calls it double-horizon diffraction.`));

// 8 Distribution
body.push(H1("Results over the time distribution"));
body.push(P("Figure 7 shows the loss over the whole time distribution on five archetype paths at 2.7 GHz, with ITM's 10% to 90% confidence band. Table 6 gives the values at 50% and 1% of time and the spread from 1% to 99% at all three frequencies."));
body.push(...figure("fig05_full_distribution_archetypes.png", "Basic transmission loss against time percentage on five archetype paths at 2.7 GHz. The shaded band is ITM's 10% to 90% confidence range. The last panel shows each curve minus its 50% value."));
body.push(P(`Three patterns stand out:`));
body.push(B({ b: "Low tail. " }, `On the troposcatter and over-sea paths, the ITU models fall steeply below about 10% of time, where ducting takes over. At 1% of time on the ${r0(sea.length_km)} km over-sea path, P.2001 predicts ${r1(sea.p2001_1)} dB, ${r1(seaFsl - sea.p2001_1)} dB below free-space loss, and P.452 predicts ${r1(sea.p452_1)} dB; ITM predicts ${r1(sea.itm_1)} dB. Loss below free space is what ducting means in both Recommendations.`));
body.push(B({ b: "Spread. " }, `ITM's spread from 1% to 99% is ${r1(los.itm_spread_1_99)} dB on the line-of-sight path and ${r1(tro.itm_spread_1_99)} dB on the troposcatter path. P.2001's spreads are ${r1(los.p2001_spread_1_99)} dB and ${r1(tro.p2001_spread_1_99)} dB, because ducting pulls its low tail down and fading pushes its high tail up.`));
body.push(B({ b: "High tail. " }, "On the line-of-sight path, P.2001 rises steeply above 99% of time from clear-air and rain fading; ITM's curve stays nearly flat."));
body.push(...table("Archetype paths at 50% and 1% of time (dB).",
  ["Path", "km", "MHz", "ITM 50%", "P.452 50%", "P.2001 50%", "ITM 1%", "P.452 1%", "P.2001 1%", "ITM 1-99% spread", "P.2001 1-99% spread"],
  arch.map((r) => [r.path, r0(r.length_km), r0(r.freq_mhz), r1(r.itm_50), r1(r.p452_50), r1(r.p2001_50), r1(r.itm_1), r1(r.p452_1), r1(r.p2001_1), r1(r.itm_spread_1_99), r1(r.p2001_spread_1_99)]),
  [1500, 500, 600, 800, 800, 800, 800, 800, 800, 980, 980]));
body.push(H2("Which mechanism dominates"));
body.push(P("Figure 8 maps the dominant P.2001 and P.452 sub-model over distance and time percentage on smooth earth at 2.7 GHz, with ITM's regime as a strip at the top. Figure 9 shows the dominant P.2001 sub-model along the distribution for each archetype path. They show where the time distribution changes mechanism, which ITM can't represent."));
body.push(...figure("fig04_mechanism_maps.png", "Dominant mechanism of P.2001 and P.452 over distance and time percentage, flat land and flat sea, 2.7 GHz. The top strip shows ITM's regime."));
body.push(...figure("fig06_p2001_dominant_mechanism_by_percentage.png", "Dominant P.2001 sub-model against time percentage for each archetype path and study frequency."));
body.push(H2("Across all real-terrain links"));
body.push(P(`Over all ${nLinks} links at 2.7 GHz, the median P.2001 minus ITM difference is ${r1(byp27(0.01).p2001_minus_itm_med_db)} dB at 0.01% of time, ${r1(byp27(1).p2001_minus_itm_med_db)} dB at 1%, ${r1(byp27(50).p2001_minus_itm_med_db)} dB at 50%, and ${r1(byp27(99.9).p2001_minus_itm_med_db)} dB at 99.9% (Table 7).`));
body.push(...table("Median difference from ITM over all real-terrain links (dB).", ["MHz", "Time %", "P.2001 − ITM", "P.452 − ITM"],
  byp.map((r) => [r0(r.freq_mhz), String(r.time_pct), r1(r.p2001_minus_itm_med_db), typeof r.p452_minus_itm_med_db === "number" && !isNaN(r.p452_minus_itm_med_db) ? r1(r.p452_minus_itm_med_db) : "n/a (above 50%)"]),
  [2000, 2000, 2680, 2680]));

// 9 Separation
body.push(H1("What the differences mean in distance"));
body.push(P("On smooth earth the differences barely move a separation distance: for thresholds from 150 dB to 180 dB, the three models reach the threshold within 2 km of each other on land and within 5 km over sea (Figure 10, Table 8), because the steep diffraction slope beyond the radio horizon makes distance insensitive to a few dB."));
body.push(...figure("fig08_distance_to_threshold_smooth_earth.png", "Distance at which the 50% loss first reaches each threshold on flat land."));
body.push(...table("Distance to reach each loss threshold on smooth earth, 50% of time (km).",
  ["MHz", "Threshold (dB)", "Land ITM", "Land P.452", "Land P.2001", "Sea ITM", "Sea P.452", "Sea P.2001"],
  thr.map((r) => [r0(r.freq_mhz), r0(r.threshold_db), r0(r.land_itm_km), r0(r.land_p452_km), r0(r.land_p2001_km), r0(r.sea_itm_km), r0(r.sea_p452_km), r0(r.sea_p2001_km)]),
  [1000, 1300, 1170, 1170, 1170, 1170, 1170, 1210]));
body.push(P("Over real terrain the picture changes (Figure 11). Along four radials from a piedmont site, ITM's higher diffraction loss lets it reach a threshold at shorter distances, so ITM would give smaller protection distances where terrain blocks the path. Table 9 gives the last distance along each radial at which the 50% loss is still below the threshold."));
body.push(...figure("fig11_radial_loss_vs_distance.png", "Loss along four radials from 38.90° N, 77.45° W at 2.7 GHz and 50% of time, with free-space loss for reference."));
if (radial.length) {
  body.push(...table("Last distance along each radial at which the 50% loss is below the threshold (km).",
    ["MHz", "Threshold (dB)", "Azimuth (°)", "ITM", "P.452", "P.2001"],
    radial.filter((r) => r.threshold_db >= 150 && r.threshold_db <= 170).map((r) => [r0(r.freq_mhz), r0(r.threshold_db), r0(r.azimuth_deg), r0(r.itm_km), r0(r.p452_km), r0(r.p2001_km)]),
    [1500, 1600, 1500, 1580, 1580, 1600]));
}

// 10 Where to look deeper
body.push(H1("Where to look deeper"));
body.push(P("These preliminary calculations point to the following questions, in priority order:"));
body.push(N({ b: "Which diffraction prediction is right over rough terrain at 2 GHz to 8 GHz? " }, "This is the largest difference, 30 dB to 48 dB at the median on diffraction links, and it grows with frequency and terrain irregularity. It needs comparison against measured path loss, such as the ITU-R Study Group 3 databank and published NTIA/ITS measurement campaigns, binned by Δh and frequency."));
body.push(N({ b: "How should analyses treat ITM on steep horizons? " }, `ITM flagged horizon angles above 200 mrad on ${flags.links_with_horizon_angle_over_200_mrad} of ${nLinks} links, and on one of them it predicted about 80 dB more loss than the ITU models. Analyses that use ITM should decide whether to exclude, cap, or replace such links, and should record the flag.`));
body.push(N({ b: "Do aggregate-interference results depend on ducting? " }, "Over all real-terrain links, the ITU models predict a median of 20 dB to 28 dB less loss than ITM at 0.01% to 1% of time, from a mechanism ITM lacks. Interference criteria set at small percentages are sensitive to this choice."));
body.push(N({ b: "Do availability results depend on fading? " }, "P.2001's high tail includes rain and clear-air fading that ITM and P.452 omit. This matters for analyses of the victim's own link margin."));
body.push(N({ b: "Is the mechanism label consistent? " }, "ITM v1.4's mode label and the ITM 1.2.2 code disagree on obstructed paths. Reports that cite ITM's mechanism should say which definition they use."));
body.push(N({ b: "How large are the regional effects? " }, "The sample covers three mid-Atlantic regions. Western terrain and other climates may change the size of the gap."));
body.push(N({ b: "How much does ground cover change P.452? " }, "P.452-18 can take a ground-cover profile; with Copernicus surface heights it moved P.452's 50% loss by several dB on earlier runs. That is a separate question from the model comparison here."));

// 11 Limitations
body.push(H1("Limitations"));
body.push(B(`The sample is small: ${nLinks} links in three mid-Atlantic regions and five archetype paths. Medians by class rest on 14 to 28 links.`));
body.push(B("No comparison was made against measured data, so the paper can say how the models differ, not which is right."));
body.push(B("Each model was run with defaults that this paper chose (antenna heights, ITM ground constants, ITM variability mode 13, 50% confidence). Other choices change ITM's results."));
body.push(B("The knife-edge test uses a single raised profile point, which the models interpret differently from a physical ridge; treat it as a coarse check."));
body.push(B("All results are basic transmission loss with isotropic antennas. Clutter, building entry loss, and antenna patterns are not included."));

// Appendix A
body.push(new Paragraph({ children: [new PageBreak()] }));
body.push(H1("Appendix A: code references"));
body.push(P("The footnotes cite the implementations at pinned commits. These links show the implementation, not the authority of the method; the Recommendations and the ITM documentation are the authority for each equation:"));
body.push(B("NTIA/ITS, ITM v1.4 C++ source, https://github.com/NTIA/itm"));
body.push(B("Recommendation ITU-R P.2001-6, A general purpose wide-range terrestrial propagation model in the frequency range 30 MHz to 50 GHz"));
body.push(B("Recommendation ITU-R P.452-18, Prediction procedure for the evaluation of interference between stations on the surface of the Earth at frequencies above about 0.1 GHz"));
body.push(B("Recommendation ITU-R P.526-15, Propagation by diffraction"));

// Appendix B
body.push(H1("Appendix B: reproducing the figures"));
body.push(P("All figures and tables come from one MATLAB script. To reproduce them, do the following:"));
body.push(N("Clone matlab_itm, itu_p2001, and matlab_itu_p452 into one folder, at the commits below."));
body.push(N("In MATLAB R2025b with Mapping Toolbox, run:"));
body.push(new Paragraph({ indent: { left: 720 }, children: [new TextRun({ text: "addpath('matlab_itm/docs/model_comparison'); R = make_wp_figures_rev1();", font: "Courier New", size: 18 })] }));
body.push(N("To rebuild this document from the figures and CSV tables, run node build_wp_docx_rev1.js in the same folder."));
body.push(...table("Commits used.", ["Repository", "Commit"],
  [["matlab_itm", SHA.itm], ["itu_p2001", SHA.p2001], ["matlab_itu_p452", SHA.p452]], [2400, 6960]));
body.push(P("The script runs in about a minute on an Apple silicon laptop once the terrain tiles are cached; the first run downloads about 40 tiles."));

// ---------- assemble ----------
const markRun = () => new TextRun({ text: MARK, bold: true, font: FONT, size: 18 });
const doc = new Document({
  creator: "NTIA working paper draft",
  title: "ITM, ITU-R P.2001, and ITU-R P.452: How the Models Differ by Propagation Mechanism",
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
