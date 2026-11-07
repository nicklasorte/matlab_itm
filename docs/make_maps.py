"""Draw the ITU-R climate and refractivity maps used by matlab_itm.

Reads the same files the MATLAB code reads (data/TropoClim.txt and
data/N050.TXT) and applies the same lookup rules, so the figures show
exactly what itm_radio_climate_rev1 and itm_surface_refractivity_rev1
return.

    python3 docs/make_maps.py      # writes docs/*.png
"""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, BoundaryNorm, LinearSegmentedColormap
from matplotlib.patches import Patch

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs")

SURFACE = "#fcfcfb"
INK = "#1f1f1e"
INK_2 = "#5c5b57"
GRID = "#d9d8d4"
SEA = "#eef1f4"
LAND = "#e3e2de"

# Validated categorical set (dataviz validator, all pairs, light mode)
CLIMATE_COLOR = {2: "#e87ba4", 4: "#eda100", 5: "#008300", 6: "#6250d6"}
OTHER = "#8a8984"   # codes 1 and 3: under 10 cells in the U.S. view
CLIMATE_NAME = {
    1: "Equatorial", 2: "Continental subtropical", 3: "Maritime subtropical",
    4: "Desert", 5: "Continental temperate", 6: "Maritime temperate, over land",
    7: "Maritime temperate, over sea",
}
BLUE_RAMP = ["#cde2fb", "#9ec5f4", "#6da7ec", "#3987e5", "#2a78d6", "#1c5cab", "#104281", "#0d366b"]

# Example paths: the README path (land midpoint) and a coastal path whose
# midpoint is over sea, which shows the sea rule
PATHS = [
    dict(name="Washington to Baltimore", tx=(38.8895, -77.0353), rx=(39.0458, -76.6413), xy=(-60, 28)),
    dict(name="Atlantic City to Ocean City", tx=(39.36, -74.42), rx=(38.34, -75.08), xy=(-175, -62)),
]

plt.rcParams.update({
    "font.size": 9, "axes.edgecolor": GRID, "axes.labelcolor": INK_2,
    "xtick.color": INK_2, "ytick.color": INK_2, "text.color": INK,
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
})


def load():
    clim = np.loadtxt(os.path.join(ROOT, "data", "TropoClim.txt"), dtype=int)
    n0 = np.loadtxt(os.path.join(ROOT, "data", "N050.TXT"))
    return clim, n0


def climate_at(clim, lat, lon):
    """Same rule as itm_radio_climate_rev1 (nearest 0.5 deg cell, 0 -> 7)."""
    lon = (lon + 180) % 360 - 180
    r = min(max(int(np.floor((89.75 - lat) / 0.5 + 0.5)), 0), 359)
    c = int(np.floor((lon + 179.75) / 0.5 + 0.5)) % 720
    v = clim[r, c]
    return 7 if v == 0 else int(v)


def n0_at(n0, lat, lon):
    """Same rule as itm_surface_refractivity_rev1 (bilinear, 1.5 deg)."""
    lon = lon % 360
    row, col = (90 - lat) / 1.5, lon / 1.5
    r, c = min(int(np.floor(row)), 119), min(int(np.floor(col)), 239)
    ar, ac = row - r, col - c
    return (n0[r + 1, c + 1] * ar * ac + n0[r, c] * (1 - ar) * (1 - ac)
            + n0[r, c + 1] * (1 - ar) * ac + n0[r + 1, c] * ar * (1 - ac))


def midpoint(a, b):
    # Spherical midpoint; within meters of the WGS84 geodesic midpoint for this path
    la1, lo1, la2, lo2 = map(np.radians, (a[0], a[1], b[0], b[1]))
    bx = np.cos(la2) * np.cos(lo2 - lo1)
    by = np.cos(la2) * np.sin(lo2 - lo1)
    lat = np.arctan2(np.sin(la1) + np.sin(la2), np.hypot(np.cos(la1) + bx, by))
    lon = lo1 + np.arctan2(by, np.cos(la1) + bx)
    return np.degrees(lat), np.degrees(lon)


def cell_edges():
    lat_e = 90 - 0.5 * np.arange(361)
    lon_e = -180 + 0.5 * np.arange(721)
    return lat_e, lon_e


def land_outline(ax, clim, **kw):
    lat_c = 89.75 - 0.5 * np.arange(360)
    lon_c = -179.75 + 0.5 * np.arange(720)
    ax.contour(lon_c, lat_c, (clim > 0).astype(float), levels=[0.5],
               colors=kw.get("color", INK_2), linewidths=kw.get("lw", 0.5))


def style(ax, extent, title):
    ax.set_xlim(extent[0], extent[1])
    ax.set_ylim(extent[2], extent[3])
    ax.set_aspect(1 / np.cos(np.radians((extent[2] + extent[3]) / 2)))
    ax.set_title(title, loc="left", fontsize=10.5, fontweight="bold", color=INK)
    ax.tick_params(length=0)
    for s in ax.spines.values():
        s.set_visible(False)


def us_climate(ax, clim):
    lat_e, lon_e = cell_edges()
    codes = [2, 4, 5, 6]
    img = np.full(clim.shape, 0.0)            # 0 sea
    for k, code in enumerate(codes, start=1):
        img[clim == code] = k
    img[(clim == 1) | (clim == 3)] = 5         # other
    cmap = ListedColormap([SEA] + [CLIMATE_COLOR[c] for c in codes] + [OTHER])
    norm = BoundaryNorm(np.arange(-0.5, 6.5, 1), cmap.N)
    ax.pcolormesh(lon_e, lat_e, img, cmap=cmap, norm=norm, edgecolors="none")
    land_outline(ax, clim, color=SURFACE, lw=0.6)
    handles = [Patch(color=CLIMATE_COLOR[c], label=f"{c}  {CLIMATE_NAME[c]}") for c in codes]
    handles += [Patch(color=OTHER, label="1, 3  Equatorial, maritime subtropical"),
                Patch(facecolor=SEA, edgecolor=GRID, label="7  Sea (file code 0)")]
    ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(0, -0.08), ncol=2, fontsize=7.5,
              frameon=False, title="Radio climate code", title_fontsize=8, alignment="left")


def us_n0(ax, clim, n0):
    lat_p = 90 - 1.5 * np.arange(121)
    lon_p = np.concatenate([1.5 * np.arange(120, 241) - 360, 1.5 * np.arange(0, 121)])
    data = np.concatenate([n0[:, 120:241], n0[:, 0:121]], axis=1)
    cmap = LinearSegmentedColormap.from_list("blue", BLUE_RAMP)
    m = ax.pcolormesh(lon_p, lat_p, data, cmap=cmap, shading="gouraud", vmin=300, vmax=390)
    land_outline(ax, clim, color=INK, lw=0.6)
    return m


def mark_paths(ax, clim, n0):
    out = []
    for p in PATHS:
        tx, rx = p["tx"], p["rx"]
        mlat, mlon = midpoint(tx, rx)
        ax.plot([tx[1], rx[1]], [tx[0], rx[0]], color=INK, lw=2, solid_capstyle="round", zorder=5)
        ax.plot([tx[1], rx[1]], [tx[0], rx[0]], "o", ms=5, mfc=SURFACE, mec=INK, mew=1.5, zorder=6)
        ax.plot(mlon, mlat, "D", ms=7, mfc=INK, mec=SURFACE, mew=1.5, zorder=7)
        c_mid = climate_at(clim, mlat, mlon)
        c = c_mid if c_mid != 7 else min(climate_at(clim, *tx), climate_at(clim, *rx))
        n = n0_at(n0, mlat, mlon)
        rule = f"midpoint climate {c_mid}" + (f" (sea) \u2192 min of ends = {c}" if c_mid == 7 else "")
        txt = f"{p['name']}\n{rule}\nN\u2080 {n:.1f}"
        ax.annotate(txt, (mlon, mlat), xytext=p["xy"], textcoords="offset points", fontsize=7.5,
                    color=INK, ha="left", va="center",
                    bbox=dict(boxstyle="round,pad=0.3", fc=SURFACE, ec=GRID),
                    arrowprops=dict(arrowstyle="-", color=INK_2, lw=0.8), zorder=8)
        out.append((c, n))
    return out


def figure_us(clim, n0):
    fig, axes = plt.subplots(2, 2, figsize=(11, 10),
                             gridspec_kw=dict(height_ratios=[1, 1.15], hspace=0.42, wspace=0.12))
    us = (-126, -65, 23, 51)
    zoom = (-79.5, -72.5, 37.0, 41.0)

    us_climate(axes[0, 0], clim)
    style(axes[0, 0], us, "Radio climate (ITU-R P.617-3)")
    m = us_n0(axes[0, 1], clim, n0)
    style(axes[0, 1], us, "Sea-level refractivity N\u2080 (ITU-R P.452)")
    for ax in axes[0]:
        ax.add_patch(plt.Rectangle((zoom[0], zoom[2]), zoom[1] - zoom[0], zoom[3] - zoom[2],
                                   fill=False, ec=INK, lw=1))

    us_climate(axes[1, 0], clim)
    axes[1, 0].get_legend().remove()
    style(axes[1, 0], zoom, "Mid-Atlantic: climate cells (0.5\u00b0)")
    for v in np.arange(-79.5, -72.4, 0.5):
        axes[1, 0].axvline(v, color=SURFACE, lw=0.4, zorder=1)
    for v in np.arange(37.0, 41.01, 0.5):
        axes[1, 0].axhline(v, color=SURFACE, lw=0.4, zorder=1)
    res = mark_paths(axes[1, 0], clim, n0)
    us_n0(axes[1, 1], clim, n0)
    style(axes[1, 1], zoom, "Mid-Atlantic: refractivity (bilinear, 1.5\u00b0 grid)")
    mark_paths(axes[1, 1], clim, n0)

    cb = fig.colorbar(m, ax=axes[:, 1], fraction=0.035, pad=0.03)
    cb.set_label("N\u2080 (N-units)")
    cb.outline.set_visible(False)
    fig.suptitle("How itm_pathloss_rev1 picks climate and refractivity", x=0.06, y=0.985, ha="left",
                 fontsize=13, fontweight="bold")
    fig.text(0.06, 0.945,
             "Both are looked up at the path midpoint. Climate: nearest 0.5\u00b0 cell; if the midpoint "
             "is sea (7), the lower of the two terminal climates. N\u2080: bilinear on the 1.5\u00b0 grid.",
             fontsize=9, color=INK_2)
    fig.text(0.06, 0.03, "Data: ITU-R P.617-3 TropoClim.txt; ITU-R P.452-16 N050.TXT (\u00a9 ITU). "
             "Drawn by docs/make_maps.py from the files in data/.", fontsize=7.5, color=INK_2)
    fig.savefig(os.path.join(OUT, "climate_refractivity_us.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)
    return res


def figure_world(clim, n0):
    lat_e, lon_e = cell_edges()
    fig = plt.figure(figsize=(11, 8.4))
    gs = fig.add_gridspec(3, 3, height_ratios=[1, 1, 1.9], hspace=0.18, wspace=0.04)
    world = (-180, 180, -60, 80)
    for k, code in enumerate(range(1, 7)):
        ax = fig.add_subplot(gs[k // 3, k % 3])
        img = np.where(clim == code, 2, np.where(clim > 0, 1, 0))
        ax.pcolormesh(lon_e, lat_e, img, cmap=ListedColormap([SEA, LAND, "#2a78d6"]),
                      norm=BoundaryNorm([-0.5, 0.5, 1.5, 2.5], 3), edgecolors="none")
        ax.set_xlim(world[0], world[1]); ax.set_ylim(world[2], world[3]); ax.set_aspect("auto")
        ax.set_xticks([]); ax.set_yticks([])
        for s in ax.spines.values():
            s.set_visible(False)
        ax.set_title(f"{code}  {CLIMATE_NAME[code]}", loc="left", fontsize=9, color=INK)
    ax = fig.add_subplot(gs[2, :])
    lon_p = np.concatenate([1.5 * np.arange(120, 241) - 360, 1.5 * np.arange(0, 121)])
    lat_p = 90 - 1.5 * np.arange(121)
    data = np.concatenate([n0[:, 120:241], n0[:, 0:121]], axis=1)
    m = ax.pcolormesh(lon_p, lat_p, data, cmap=LinearSegmentedColormap.from_list("b", BLUE_RAMP),
                      shading="gouraud")
    land_outline(ax, clim, color=INK, lw=0.4)
    ax.set_xlim(-180, 180); ax.set_ylim(-60, 80); ax.set_aspect("auto")
    ax.set_title("Sea-level refractivity N₀ (ITU-R P.452 N050, 1.5° grid)", loc="left",
                 fontsize=10.5, fontweight="bold")
    for s in ax.spines.values():
        s.set_visible(False)
    ax.tick_params(length=0)
    cb = fig.colorbar(m, ax=ax, fraction=0.025, pad=0.01)
    cb.set_label("N₀ (N-units)")
    cb.outline.set_visible(False)
    fig.suptitle("ITU-R radio climate zones, one panel per zone (P.617-3, 0.5° grid)",
                 x=0.06, ha="left", fontsize=12, fontweight="bold")
    fig.text(0.06, 0.925, "Blue: the zone named in each panel. Sea, everywhere not shaded, is "
             "zone 7 (maritime temperate, over sea).", fontsize=9, color=INK_2)
    fig.savefig(os.path.join(OUT, "climate_refractivity_world.png"), dpi=150, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    clim, n0 = load()
    for p, (c, n) in zip(PATHS, figure_us(clim, n0)):
        print(f"{p['name']}: climate {c}, N_0 {n:.3f}")
    figure_world(clim, n0)
