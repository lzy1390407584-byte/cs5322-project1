"""Figures for the Project I report.

  figures/er_diagram.png        schema (14 tables) drawn from a hand layout
  figures/vpd_flow.png          how a statement is rewritten by a VPD policy
  ../project1_vpd_visibility.png  heat map of rows visible per identity and table, parsed from
                                the real run in ../project1_visibility_matrix.log
Run:  python report/build_figures.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch
import numpy as np

ROOT = Path(__file__).resolve().parent
FIG = ROOT / "figures"
FIG.mkdir(exist_ok=True)

plt.rcParams["font.family"] = "DejaVu Sans"

# one hue per domain
C_HEAD = {"org": "#5b6b7a", "acad": "#2f6fab", "fin": "#b8721d", "house": "#2e8b57", "audit": "#7a4f9a"}
C_BODY = {"org": "#eef1f4", "acad": "#e8f0f9", "fin": "#faf0e2", "house": "#e6f3ec", "audit": "#f1eaf6"}


# ================================================================= ER diagram
def er_diagram():
    W, H = 114.0, 49.0
    fig = plt.figure(figsize=(7.2, 7.2 * H / W))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.axis("off")

    BW, LH, HH = 16.6, 1.62, 2.2

    # column centres
    cR, c0, c1, c15, c2, c3, c4 = 9.5, 28.0, 47.0, 56.5, 66.0, 85.0, 104.0
    r0, r1, r2 = 47.5, 32.0, 17.0       # top of each row

    tables = {
        # name: (domain, centre x, top y, lines, dashed)
        "department":      ("org",   c3,  r0, ["department_id  PK", "department_name"], True),
        "app_user":        ("org",   c4,  r0, ["user_id  PK", "username", "user_role", "department_id  FK†"], True),
        "residence_room":  ("house", c0,  r0, ["room_id  PK", "residence_id  FK", "room_number"], False),
        "room_allocation": ("house", c15, r0, ["allocation_id  PK", "room_id  FK", "student_id  FK", "professor_id  FK", "allocation_status"], False),
        "residence":       ("house", cR,  38.0, ["residence_id  PK", "residence_name"], False),
        "resident_fellow": ("house", c0,  r1, ["professor_id  PK,FK", "residence_id  PK,FK", "status  ACTIVE/ENDED"], False),
        "professor":       ("acad",  c1,  r1, ["professor_id  PK", "user_id  FK†", "department_id  FK†"], False),
        "student":         ("acad",  c2,  r1, ["student_id  PK", "user_id  FK†", "department_id  FK†", "email  (masked)"], False),
        "payment":         ("fin",   c3,  r1, ["payment_id  PK", "student_id  FK", "payment_status"], False),
        "course":          ("acad",  c0,  r2, ["course_id  PK", "department_id  FK†", "course_code"], False),
        "section":         ("acad",  c1,  r2, ["section_id  PK", "course_id  FK", "professor_id  FK", "semester"], False),
        "enrollment":      ("acad",  c2,  r2, ["enrollment_id  PK", "student_id  FK", "section_id  FK", "status"], False),
        "grade":           ("acad",  c3,  r2, ["grade_id  PK", "enrollment_id  FK", "grade_value", "released  Y/N", "last_updated_by  FK†"], False),
        "grade_audit":     ("audit", c4,  r2, ["audit_id  PK", "grade_id", "action", "actor_user_id", "db_user"], False),
    }

    boxes = {}
    for name, (dom, cx, top, lines, dashed) in tables.items():
        h = HH + LH * len(lines) + 0.6
        x0, y0 = cx - BW / 2, top - h
        ax.add_patch(Rectangle((x0, y0), BW, h, facecolor=C_BODY[dom], edgecolor=C_HEAD[dom], linewidth=0.9,
                               linestyle=(0, (3, 1.6)) if dashed else "-", zorder=3))
        ax.add_patch(Rectangle((x0, top - HH), BW, HH, facecolor=C_HEAD[dom], edgecolor=C_HEAD[dom], linewidth=0.9, zorder=4))
        ax.text(cx, top - HH / 2, name.upper(), ha="center", va="center", color="white", fontsize=5.4,
                fontweight="bold", zorder=5)
        for i, ln in enumerate(lines):
            key = ln.endswith("PK") or "PK,FK" in ln
            ax.text(x0 + 0.9, top - HH - 0.35 - LH * (i + 0.5), ln, ha="left", va="center",
                    fontsize=4.6, fontweight="bold" if key else "normal", color="#222", zorder=5)
        boxes[name] = (x0, y0, BW, h)

    def centre(name):
        x0, y0, w, h = boxes[name]
        return x0 + w / 2, y0 + h / 2

    def anchor(name, toward):
        x0, y0, w, h = boxes[name]
        cx, cy = centre(name)
        dx, dy = toward[0] - cx, toward[1] - cy
        sx = (w / 2) / abs(dx) if dx else 1e9
        sy = (h / 2) / abs(dy) if dy else 1e9
        s = min(sx, sy)
        return cx + dx * s, cy + dy * s

    def link(child, parent, color="#555", ls="-"):
        c = anchor(child, centre(parent))
        p = anchor(parent, centre(child))
        ax.add_patch(FancyArrowPatch(c, p, arrowstyle="-|>", mutation_scale=5.5, lw=0.75, color=color, ls=ls,
                                     zorder=2, shrinkA=0, shrinkB=0))

    # child -> parent; all lines are short and cross no box
    for ch, pa in [("section", "course"), ("section", "professor"), ("enrollment", "student"),
                   ("enrollment", "section"), ("grade", "enrollment"), ("payment", "student"),
                   ("room_allocation", "student"), ("room_allocation", "professor"),
                   ("room_allocation", "residence_room"), ("residence_room", "residence"),
                   ("resident_fellow", "professor"), ("resident_fellow", "residence")]:
        link(ch, pa)
    link("grade_audit", "grade", color=C_HEAD["audit"], ls=(0, (3, 2)))

    # legend (bottom left) and notes (top right)
    lx, ly = 1.5, 30.0
    ax.text(lx, ly, "Legend", fontsize=5.4, fontweight="bold", va="top")
    items = [("org", "organisation / identity"), ("acad", "academic"), ("fin", "finance"),
             ("house", "housing"), ("audit", "audit (trigger only)")]
    for i, (dom, label) in enumerate(items):
        yy = ly - 3.6 - i * 2.55
        ax.add_patch(Rectangle((lx, yy - 0.85), 2.4, 1.7, facecolor=C_HEAD[dom], edgecolor="none"))
        ax.text(lx + 3.4, yy, label, fontsize=4.6, va="center")
    yy = ly - 3.6 - len(items) * 2.55
    ax.add_patch(FancyArrowPatch((lx, yy), (lx + 2.4, yy), arrowstyle="-|>", mutation_scale=5, lw=0.75, color="#555"))
    ax.text(lx + 3.4, yy, "child -> parent (FK)", fontsize=4.6, va="center")
    ax.add_patch(FancyArrowPatch((lx, yy - 2.55), (lx + 2.4, yy - 2.55), arrowstyle="-|>", mutation_scale=5, lw=0.75,
                                 color=C_HEAD["audit"], ls=(0, (3, 2))))
    ax.text(lx + 3.4, yy - 2.55, "logical reference", fontsize=4.6, va="center")

    ax.text(1.5, 4.4,
            "† foreign key to DEPARTMENT or APP_USER (lookup tables, drawn dashed); these lines are omitted to keep the "
            "diagram readable.\nAPP_USER maps a database login to its role and department; only the context package reads it "
            "and no role has a grant on it.",
            fontsize=4.5, va="top", color="#333", linespacing=1.4)

    fig.savefig(FIG / "er_diagram.png", dpi=300)
    plt.close(fig)


# ================================================================= VPD flow
def vpd_flow():
    """Five boxes left to right: login -> SET_USER -> context -> statement -> rewritten statement."""
    W, H = 100.0, 14.2
    fig = plt.figure(figsize=(7.2, 7.2 * H / W))
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.axis("off")

    steps = [
        ("1  Login", "alice connects with\nher own database\naccount", "#e8f0f9", "#2f6fab", 13.0),
        ("2  SET_USER('alice')", "CS5322_SECURITY_CTX:\nthe caller must be\nalice; reads APP_USER,\nwrites the context", "#eef1f4", "#5b6b7a", 15.5),
        ("3  Context", "CS5322_APP_CTX\nUSER_ID = 1001\nROLE = STUDENT\nDEPARTMENT_ID = 10", "#eef1f4", "#5b6b7a", 13.0),
        ("4  Statement", "SELECT * FROM grade\nOracle calls GRADE_VPD_FN\n(reads only the context)\nand gets a predicate", "#faf0e2", "#b8721d", 15.5),
        ("5  Executed instead", "SELECT * FROM grade WHERE released = 'Y'\nAND enrollment_id IN (SELECT e.enrollment_id\nFROM enrollment e WHERE e.student_id =\n  (SELECT student_id FROM student\n   WHERE user_id = 1001))", "#e6f3ec", "#2e8b57", 29.0),
    ]
    gap = 3.2
    x = 0.8
    y0, h = 1.0, 12.2
    prev_right = None
    for title, body, bg, fg, w in steps:
        ax.add_patch(FancyBboxPatch((x, y0), w, h, boxstyle="round,pad=0,rounding_size=1.1", facecolor=bg,
                                    edgecolor=fg, linewidth=0.9))
        ax.text(x + 1.0, y0 + h - 1.5, title, fontsize=5.5, fontweight="bold", va="top", color=fg)
        ax.text(x + 1.0, y0 + h - 5.0, body, fontsize=4.7, va="top", color="#222", linespacing=1.3)
        if prev_right is not None:
            ax.add_patch(FancyArrowPatch((prev_right, y0 + h / 2), (x, y0 + h / 2), arrowstyle="-|>", mutation_scale=6,
                                         lw=0.9, color="#444", shrinkA=0.4, shrinkB=0.4))
        prev_right = x + w
        x += w + gap
    fig.savefig(FIG / "vpd_flow.png", dpi=300)
    plt.close(fig)


# ================================================================= heat map of the real run
def visibility_heatmap():
    log = (ROOT.parent / "project1_visibility_matrix.log").read_text(encoding="utf-8", errors="replace")
    rows = []
    for line in log.splitlines():
        if not line.startswith("MATRIX") or line.startswith("MATRIX identity"):
            continue
        tok = line.split()
        rows.append((" ".join(tok[1:-13]), [int(t) for t in tok[-13:]]))
    assert len(rows) == 11, rows

    cols = ["department", "student", "professor", "course", "section", "enrollment", "grade", "payment",
            "residence", "residence_room", "room_allocation", "resident_fellow", "grade_audit"]
    data = np.array([r[1] for r in rows], dtype=float)
    totals = np.array([3, 3, 2, 4, 5, 5, 4, 3, 2, 5, 6, 3, 1], dtype=float)  # rows per table (audit: nominal 1)
    share = data / totals

    fig, ax = plt.subplots(figsize=(7.2, 3.3))
    ax.imshow(np.clip(share, 0, 1), cmap=plt.get_cmap("Blues"), vmin=0, vmax=1.15, aspect="auto")
    ax.set_xticks(range(len(cols)))
    ax.set_xticklabels([c.replace("_", "\n") for c in cols], fontsize=6.2)
    ax.xaxis.tick_top()
    ax.set_yticks(range(len(rows)))
    ax.set_yticklabels([r[0] for r in rows], fontsize=7)
    ax.tick_params(length=0)
    for i in range(data.shape[0]):
        for j in range(data.shape[1]):
            v = int(data[i, j])
            full = share[i, j] >= 0.6
            ax.text(j, i, str(v), ha="center", va="center", fontsize=7.5,
                    color="white" if full else ("#9aa5b1" if v == 0 else "#1d3f66"),
                    fontweight="bold" if v else "normal")
    for s in ax.spines.values():
        s.set_visible(False)
    ax.set_xticks(np.arange(-.5, len(cols), 1), minor=True)
    ax.set_yticks(np.arange(-.5, len(rows), 1), minor=True)
    ax.grid(which="minor", color="white", linewidth=1.4)
    ax.tick_params(which="minor", length=0)
    fig.text(0.01, 0.005, "Rows each identity sees (SELECT COUNT(*)); shading = share of the table; "
             "uni_admin sees the full table.  Source: 04_tests.sql run on the group VM.", fontsize=5.8, color="#444")
    fig.tight_layout(rect=(0, 0.03, 1, 1))
    fig.savefig(ROOT.parent / "project1_vpd_visibility.png", dpi=250)
    fig.savefig(FIG / "visibility_heatmap.png", dpi=250)
    plt.close(fig)


if __name__ == "__main__":
    er_diagram()
    vpd_flow()
    visibility_heatmap()
    print("figures written to", FIG)
