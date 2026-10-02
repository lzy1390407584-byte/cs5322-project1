-- One-command rebuild, verification and evidence capture for the project VM.
-- Run as the OS user oracle (it needs OS-authenticated SYSDBA), from the folder that holds
-- the scripts:
--     mkdir -p logs && sqlplus /nolog @00_run_all.sql
-- The PDB must be open and the listener running (see RUNBOOK_VM.md).  Step 1 drops and
-- recreates every project table; demo users and roles are kept.  The output of each step
-- goes to logs/<step>.log; the last line of every PASS/FAIL script
-- ("=== ... : PASS (n passed, 0 failed) ===") is its result.
DEFINE svc = "localhost:1521/cs5322"
SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 200
WHENEVER SQLERROR CONTINUE

PROMPT >>> 1. Reset and deploy: schema owner, tables, users, context package, VPD policies
SPOOL logs/01_deploy.log
CONNECT / AS SYSDBA
@@00_create_schema.sql
CONNECT CS5322_P1/"CS5322#2026"@&svc
@@05_cleanup.sql
@@01_schema_and_data.sql
CONNECT / AS SYSDBA
@@02_users_roles.sql
CONNECT CS5322_P1/"CS5322#2026"@&svc
@@03_vpd_policies.sql
@@03b_test_support.sql
SPOOL OFF

PROMPT >>> 2. Visibility matrix (04), generated predicates (04b), automated verification (06)
SPOOL logs/04_visibility_matrix.log
@@04_tests.sql
SPOOL OFF
SPOOL logs/04b_predicates.log
@@04b_show_predicates.sql
SPOOL OFF
SPOOL logs/06_verification.log
@@06_verification.sql
SPOOL OFF

PROMPT >>> 3. Real-user read tests (07), write tests (08), defense in depth (09)
SPOOL logs/07_real_user_reads.log
@@07_real_user_smoke_tests.sql
SPOOL OFF
SPOOL logs/08_write_tests.log
@@08_write_tests.sql
SPOOL OFF
SPOOL logs/09_defense_in_depth.log
@@09_defense_in_depth.sql
SPOOL OFF

PROMPT >>> 4. Live demonstration transcript (restores the data at its end)
SPOOL logs/demo.log
@@demo.sql
SPOOL OFF

PROMPT >>> 5. Verification again: the demo left the data unchanged
CONNECT CS5322_P1/"CS5322#2026"@&svc
SPOOL logs/06_verification_after_demo.log
@@06_verification.sql
SPOOL OFF
EXIT
