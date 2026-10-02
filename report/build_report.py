"""Build CS5322_Project1_Report_VPD.pdf from report.md.

    python report/build_report.py

Pipeline: figures (matplotlib) -> report.md + team.json -> pandoc (HTML) -> Microsoft Edge headless
(print to PDF, two-column A4 layout from report.css).  Edit report/team.json for the cover page and
the contribution statement.  The body (without cover and contribution page) must stay within 10 pages.
"""
import html
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
BUILD = HERE / "_build"
BUILD.mkdir(exist_ok=True)
EDGE_CANDIDATES = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
]
PDF = REPO / "CS5322_Project1_Report_VPD.pdf"


def esc(s: str) -> str:
    return html.escape(s, quote=False)


def team_cover(team: dict) -> str:
    rows = "".join(f"<tr><td>{esc(m['name'])}</td><td>{esc(m['matric'])}</td></tr>" for m in team["members"])
    return f'<table class="team"><thead><tr><th>Team member</th><th>Matric no.</th></tr></thead><tbody>{rows}</tbody></table>'


def contribution_table(team: dict) -> str:
    rows = "".join(
        f"<tr><td>{esc(m['name'])}<br><small>{esc(m['matric'])}</small></td><td>{esc(m['contribution'])}</td>"
        f"<td style='text-align:right;white-space:nowrap'>{esc(m['share'])}</td></tr>"
        for m in team["members"])
    return ("<table><thead><tr><th style='width:34%'>Member</th><th>Contribution</th><th style='width:9%'>Share</th></tr></thead>"
            f"<tbody>{rows}</tbody></table>")


def main() -> int:
    sys.path.insert(0, str(HERE))
    import build_figures
    build_figures.er_diagram()
    build_figures.vpd_flow()
    build_figures.visibility_heatmap()

    team = json.loads((HERE / "team.json").read_text(encoding="utf-8"))
    md = (REPO / "report.md").read_text(encoding="utf-8")
    md = md.replace("{{TEAM_COVER}}", team_cover(team)).replace("{{CONTRIBUTION_TABLE}}", contribution_table(team))
    filled = BUILD / "report_filled.md"
    filled.write_text(md, encoding="utf-8")

    html_out = BUILD / "report.html"
    subprocess.run([
        "pandoc", str(filled), "-f", "markdown+pipe_tables+fenced_divs+raw_html+implicit_figures",
        "-t", "html5", "-s", "--template", str(HERE / "template.html"), "--number-sections",
        "--highlight-style=tango", "--metadata", "pagetitle=CS5322 Project I - VPD report",
        "--resource-path", str(REPO), "-o", str(html_out)], check=True, cwd=REPO)
    page = html_out.read_text(encoding="utf-8")
    page = page.replace('src="report/figures/', 'src="../figures/')
    html_out.write_text(page, encoding="utf-8")

    edge = next((p for p in EDGE_CANDIDATES if Path(p).exists()), None)
    if not edge:
        print("Edge/Chrome not found; open", html_out, "and print it to PDF (A4, no headers)")
        return 1
    if PDF.exists():
        PDF.unlink()
    subprocess.run([edge, "--headless=new", "--disable-gpu", "--no-pdf-header-footer",
                    f"--user-data-dir={BUILD / 'edge-profile'}", "--virtual-time-budget=8000",
                    f"--print-to-pdf={PDF}", html_out.as_uri()], check=True, timeout=180,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    from pypdf import PdfReader
    pages = len(PdfReader(str(PDF)).pages)
    body = pages - 2
    print(f"PDF written: {PDF}  ({pages} pages = cover + {body} body pages + contribution statement)")
    if body > 10:
        print("WARNING: the body exceeds 10 pages - shorten report.md")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
