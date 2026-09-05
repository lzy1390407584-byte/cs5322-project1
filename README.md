# CS5322 Project I - University Information System with Oracle VPD

This project implements row-level access control using Oracle Virtual Private Database (VPD).
The application is a university information system with students, professors, departments,
courses, enrolments, grades and payments.

## Files

- `00_create_schema.sql` - creates the project schema in `FREEPDB1`; run as SYSDBA.
- `00_run_all.sql` - master checklist for a DBA/schema owner; run in SQL*Plus or SQLcl.
- `01_schema_and_data.sql` - tables, constraints, views, context package and dummy data.
- `02_users_roles.sql` - application users, roles and grants. Run as a DBA.
- `02_regrant_object_privileges.sql` - re-applies object grants after tables are recreated.
- `03_vpd_policies.sql` - application context and DBMS_RLS policies. Run as a DBA.
- `04_tests.sql` - positive, negative and bypass-oriented tests. Run as DBA/schema owner.
- `06_verification.sql` - automated PASS/FAIL acceptance check.
- `07_real_user_smoke_tests.sql` - end-to-end checks with real Oracle users.
- `05_cleanup.sql` - optional cleanup script; run only when the project is being reset.
- `demo.sql` - short live demonstration script.
- `report.md` - complete report draft, ready to move into the required double-column template.
- `contribution_statement.md` - six-person contribution template.

## Assumptions

The scripts target Oracle Database 19c+ and use `DBMS_RLS`, application context and proxy
users. Run the schema scripts as a project schema owner with privileges to create tables,
packages, contexts and VPD policies. Run `02_users_roles.sql` and `03_vpd_policies.sql` as a
DBA or a user with the required administrative privileges.

The scripts use passwords only for a local dummy-data demonstration. Change them before any
shared or deployed environment.

## Run order

1. Run `00_create_schema.sql` as SYSDBA against `FREEPDB1`.
2. Run `01_schema_and_data.sql` as that schema owner.
3. Run `02_users_roles.sql` as DBA. Change the `CS5322_P1` schema name first if needed.
4. Run `03_vpd_policies.sql` as the project schema owner (`CS5322_P1`), not SYS.
5. Run `04_tests.sql` as schema owner/DBA.
6. Run `06_verification.sql` as schema owner and retain its log.
7. Run `07_real_user_smoke_tests.sql` with `sqlplus /nolog` to verify actual user accounts.
8. Run `demo.sql` during the demonstration.

If tables are deleted and recreated, run `02_regrant_object_privileges.sql` as SYSDBA before
testing real users; Oracle drops object grants when their underlying tables are dropped.

In SQL*Plus/SQLcl:

```sql
@01_schema_and_data.sql
@02_users_roles.sql
@03_vpd_policies.sql
@04_tests.sql
```

The schema-owner tests use `CS5322_SECURITY_CTX.SET_USER` to simulate application identities.
The real-user smoke test additionally connects as Alice, Finance and University Admin. In a
real application, the context package should be called only after trusted authentication.
