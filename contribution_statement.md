# Contribution Statement

The contribution statement is part of the report (last page of `CS5322_Project1_Report_VPD.pdf`,
outside the page limit).  It is generated from [`report/team.json`](report/team.json), together
with the member table on the cover page.

To finish it:

1. Open `report/team.json` and replace every `[bracketed]` value with the real name, matric
   number, what the member actually did, and the share of work (the shares must add up to 100 %).
   Delete unused members.
2. Run `python report/build_report.py` (needs Python with matplotlib/pypdf, pandoc and Microsoft
   Edge); it rebuilds the figures and the PDF and checks that the body stays within 10 pages.

What the repository can show as evidence of individual work: the scripts `00`-`10` and their
commits, the logs `project1_*.log` recorded on the VM, and the review of each other's work.  Every
member should commit his own work under his own name before the submission, and the statement
must describe the real division of labour: members who do not contribute a fair share do not
receive the same mark.
