-- MUTATION CHECK (optional): proves that the tests really detect a missing policy.
-- It switches GRADE_WRITE_VPD off and re-runs the write tests, then switches GRADE_VPD off and
-- re-runs the read tests.  Both runs MUST show FAIL lines; the policies are enabled again at the end.
--
-- WARNING: while this runs the policy is off, so GRADE is not protected.  Run it on the VM only
-- when nobody else is using the database.  If it is interrupted, re-run 03_vpd_policies.sql.
--     sqlplus /nolog @10_mutation_check.sql        (type EXIT afterwards)
DEFINE svc = "localhost:1521/cs5322"
SET FEEDBACK OFF
SET VERIFY OFF

PROMPT ##### MUTATION 1: GRADE_WRITE_VPD disabled -> write tests must FAIL
CONNECT CS5322_P1/"CS5322#2026"@&svc
EXEC DBMS_RLS.ENABLE_POLICY(USER, 'GRADE', 'GRADE_WRITE_VPD', FALSE)
@@08_write_tests.sql
CONNECT CS5322_P1/"CS5322#2026"@&svc
EXEC DBMS_RLS.ENABLE_POLICY(USER, 'GRADE', 'GRADE_WRITE_VPD', TRUE)

PROMPT ##### MUTATION 2: GRADE_VPD disabled -> alice must see the draft grade, read tests must FAIL
EXEC DBMS_RLS.ENABLE_POLICY(USER, 'GRADE', 'GRADE_VPD', FALSE)
@@07_real_user_smoke_tests.sql
CONNECT CS5322_P1/"CS5322#2026"@&svc
EXEC DBMS_RLS.ENABLE_POLICY(USER, 'GRADE', 'GRADE_VPD', TRUE)

PROMPT ##### Policies enabled again
SELECT policy_name, enable FROM user_policies WHERE policy_name IN ('GRADE_WRITE_VPD', 'GRADE_VPD');
