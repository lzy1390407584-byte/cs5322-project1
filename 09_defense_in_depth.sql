-- DEFENSE IN DEPTH.  Two things an administrator or an attacker could get wrong or try:
--   A. a DBA grants a write privilege by mistake: the VPD write policies deny by default, so the
--      extra privilege changes nothing;
--   B. a user who may create tables adds a look-alike ENROLLMENT table to his own schema, hoping
--      that the unqualified table names inside a policy predicate resolve to his fake table:
--      Oracle resolves them in the schema of the protected table, so nothing changes.
-- Both scenarios temporarily change grants and revoke them again at the end.
-- Run on the VM as the OS user oracle (it needs SYSDBA; type EXIT afterwards):
--     sqlplus /nolog @09_defense_in_depth.sql
DEFINE svc = "localhost:1521/cs5322"
SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 200

PROMPT === A. DBA mistake: GRANT INSERT, UPDATE, DELETE ON grade TO cs5322_student_role ===
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = CS5322;
GRANT INSERT, UPDATE, DELETE ON CS5322_P1.grade TO cs5322_student_role;

PROMPT === alice now holds the privileges, but the write policy still blocks her ===
CONNECT alice/"Alice#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('alice');
    CS5322_P1.cs5322_test.expect_rows('alice updates 0 grades despite the UPDATE privilege', q'[UPDATE CS5322_P1.grade SET grade_value = 'A+']', 0);
    CS5322_P1.cs5322_test.expect_rows('alice deletes 0 grades despite the DELETE privilege', q'[DELETE FROM CS5322_P1.grade]', 0);
    CS5322_P1.cs5322_test.expect_error('alice cannot insert a grade despite the INSERT privilege', q'[INSERT INTO CS5322_P1.grade (grade_id, enrollment_id, grade_value, released, last_updated_by) VALUES (90099, 10001, 'A+', 'Y', 1001)]', -28115);
    CS5322_P1.cs5322_test.summary('defense in depth');
END;
/

PROMPT === Revoke the mistaken grants ===
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = CS5322;
REVOKE INSERT, UPDATE, DELETE ON CS5322_P1.grade FROM cs5322_student_role;

PROMPT === B. Name resolution: alice may create tables and adds a look-alike ENROLLMENT table ===
GRANT CREATE TABLE TO alice;
ALTER USER alice QUOTA 1M ON USERS;

CONNECT alice/"Alice#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('alice');
    -- The fake table claims that the enrollments of Bob (10002) and Carol (10003) are Alice's.
    EXECUTE IMMEDIATE 'CREATE TABLE enrollment (enrollment_id NUMBER, student_id NUMBER, section_id NUMBER, status VARCHAR2(15))';
    EXECUTE IMMEDIATE 'INSERT INTO enrollment VALUES (10002, 1, 1, ''ENROLLED'')';
    EXECUTE IMMEDIATE 'INSERT INTO enrollment VALUES (10003, 1, 1, ''ENROLLED'')';
    COMMIT;
    CS5322_P1.cs5322_test.expect_count('a look-alike ENROLLMENT table in alice''s schema does not change her grades', 'SELECT COUNT(*) FROM CS5322_P1.grade', 1);
    CS5322_P1.cs5322_test.expect_count('... nor her enrollments', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 2);
    CS5322_P1.cs5322_test.summary('look-alike table');
END;
/

PROMPT === Remove the fake table and revoke the privileges again ===
CONNECT / AS SYSDBA
ALTER SESSION SET CONTAINER = CS5322;
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE alice.enrollment PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE <> -942 THEN RAISE; END IF;
END;
/
REVOKE CREATE TABLE FROM alice;
ALTER USER alice QUOTA 0 ON USERS;
