# CS5322 Project I - Virtual Private Database for a University Information System

Row-level access control for a university information system with Oracle Virtual Private
Database (`DBMS_RLS`).  One shared schema (14 tables) is used by six kinds of users; the same
`SELECT` returns different rows depending on who runs it, and every write is checked by a
separate deny-by-default policy.  Developed and verified on **Oracle AI Database 26ai Free
(23.26.2) in the pluggable database `CS5322` of the group VM**.

## What is implemented

* **Application**: students, professors, department administrators, finance officers, housing
  officers and university administrators over students, courses, course *sections*,
  enrolments, grades, payments and student housing (residences, rooms, allocations).
* **Trusted identity**: the application context `CS5322_APP_CTX`, writable only by the package
  `CS5322_SECURITY_CTX`.  A database user can activate only its own application identity.
* **27 VPD policies** on 13 tables: a `SELECT` policy and a `INSERT/UPDATE/DELETE` policy per
  table, row-level predicates derived from the schema (never from user input), one
  column-level policy (e-mail masking), `CONTEXT_SENSITIVE` policy type.
* **Non-trivial rules**: department scope derived through `SECTION -> COURSE`; professors see
  their own class lists; grades are drafts until a department administrator publishes them;
  a *resident fellow* sees the residents of the residence he currently looks after; ended
  assignments grant nothing; a trigger records who changed a grade and cannot be spoofed.
* **Tests** (190 PASS/FAIL checks): a hand-derived visibility matrix (06), real database logins
  for reads, impersonation and context-forgery attempts (07), writes (08), and two defense-in-depth
  scenarios (09): a DBA grants too much, and a user creates a look-alike table.  Disabling a policy makes the matching tests fail (mutation check).

See [SECURITY_POLICIES.md](SECURITY_POLICIES.md) for the policy catalogue,
[RUNBOOK_VM.md](RUNBOOK_VM.md) for the operating procedure and [report.md](report.md) for the
report text (the submitted PDF is `CS5322_Project1_Report_VPD.pdf`).

## Files

| File | Run as | Purpose |
|---|---|---|
| `00_run_all.sql` | OS user `oracle` (`sqlplus /nolog`) | One command: reset, deploy, verify, record logs |
| `00_create_schema.sql` | SYSDBA | Schema owner `CS5322_P1` in PDB `CS5322` (re-runnable) |
| `01_schema_and_data.sql` | `CS5322_P1` | Tables, context package, triggers, dummy data |
| `02_users_roles.sql` | SYSDBA | Demo accounts and roles; calls `02_regrant_object_privileges.sql` |
| `02_regrant_object_privileges.sql` | SYSDBA | Object privileges of the six roles (re-run after any table rebuild) |
| `03_vpd_policies.sql` | `CS5322_P1` (**not SYS**) | Predicate helpers, policy functions, `DBMS_RLS` policies |
| `03b_test_support.sql` | `CS5322_P1` | Assertion helper package used by 06-09 |
| `04_tests.sql` | `CS5322_P1` | Visibility matrix and sample result sets |
| `04b_show_predicates.sql` | `CS5322_P1` | Prints the predicate each policy function generates per identity |
| `05_cleanup.sql` | `CS5322_P1` | Drops every project object (users/roles are kept) |
| `06_verification.sql` | `CS5322_P1` | Automated checks: policy inventory, matrix, masking, audit |
| `07_real_user_smoke_tests.sql` | `sqlplus /nolog` | Reads with real logins, impersonation attempts |
| `08_write_tests.sql` | `sqlplus /nolog` | Writes with real logins (privileges + VPD) |
| `09_defense_in_depth.sql` | OS user `oracle` | A mistaken grant and a look-alike table are both neutralised |
| `10_mutation_check.sql` | `sqlplus /nolog` | Optional: switches two policies off to prove that the tests then fail |
| `demo.sql` | `sqlplus /nolog` | Ten-minute live demonstration (restores the data) |
| `project1_*.log`, `project1_vpd_visibility.png` | - | Evidence captured on the VM |

SYS is exempt from VPD, so scripts 03-06 must **not** be run as SYS: the counts would show every
row and `ADD_POLICY(USER, ...)` would target SYS's own schema.

## Quick start (on the VM)

The PDB must be open and the listener running; see [RUNBOOK_VM.md](RUNBOOK_VM.md) for starting
them and for copying the scripts to the VM.  Then, as the OS user `oracle`:

```bash
cd ~/p1_v3
mkdir -p logs
sqlplus /nolog @00_run_all.sql
grep -h "^===" logs/*.log        # every result line should say PASS
```

Run order when done by hand: `00` (SYSDBA) -> `01` (owner) -> `02` (SYSDBA) -> `03`, `03b`
(owner) -> `04`, `04b`, `06` (owner) -> `07`, `08` (`sqlplus /nolog`) -> `09` (OS user `oracle`).
`10_mutation_check.sql` is optional: it switches two policies off, shows that the tests then fail,
and switches them on again (never run it while someone else is testing).
After rebuilding tables, always re-run `02_users_roles.sql` (or just
`02_regrant_object_privileges.sql`): Oracle drops object grants together with the tables.

Connection string for the real-user scripts: `localhost:1521/cs5322` (also valid through the
SSH tunnel described in the runbook).  The scripts define it once at the top as `svc`.

## Reading the results

* Every checking script prints `PASS | <what was checked> | <detail>` / `FAIL | ...` lines and
  a final `=== <scope>: PASS (n passed, 0 failed) ===`.
* `ORA-28115` - the new row would violate a write policy (check option).
* `0 rows updated` - the row exists but the write policy hides it from the caller.
* `ORA-41900` / `ORA-01031` / `ORA-00942` - refused by the privilege layer (Oracle 23ai reports
  a missing DML privilege as `ORA-41900`; the test helper accepts all three).
* `ORA-28113` - a policy predicate is invalid.  Seen during development when a policy on
  `ROOM_ALLOCATION` queried `ROOM_ALLOCATION`; the `RESIDENT_FELLOW` table removes the recursion.

## Accounts

Passwords are demo-only and defined in `00_create_schema.sql` and `02_users_roles.sql`; change
them for any shared environment.  Application users: `alice`, `bob`, `carol` (students),
`prof_lee`, `prof_wong` (professors, both also resident fellows), `admin_comp`, `admin_bus`
(department administrators), `finance1`, `housing1`, `uni_admin`.  Re-running `02_users_roles.sql`
resets the passwords and unlocks an account that was locked by failed logins.

## Notes

* `CS5322_Project1_WSL_OracleLite_Runbook.docx` from the first iteration (local Docker
  environment, five policies) has been removed; `RUNBOOK_VM.md` replaces it.
* `CS5322_P1`, `SYS` and `SYSTEM` may activate any application identity so that the scripts can
  simulate users; every other account is limited to its own identity.  In a real application the
  context package would be called only by a trusted logon service or logon trigger.
