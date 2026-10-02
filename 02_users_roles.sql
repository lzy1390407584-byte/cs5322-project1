-- Run as SYSDBA (sqlplus / as sysdba) after 01_schema_and_data.sql.
-- Creates the demo accounts and roles, then applies the object privileges.
-- Safe to re-run: existing accounts get their demo password reset and are unlocked,
-- which also recovers an account locked by repeated failed logins.
-- Change CS5322_P1 here and in 02_regrant_object_privileges.sql if your schema differs.
ALTER SESSION SET CONTAINER = CS5322;

DECLARE
    PROCEDURE ensure_user(p_name VARCHAR2, p_password VARCHAR2) IS
        v_exists NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM dba_users WHERE username = UPPER(p_name);
        IF v_exists = 0 THEN
            EXECUTE IMMEDIATE 'CREATE USER ' || p_name || ' IDENTIFIED BY "' || p_password || '"';
        ELSE
            EXECUTE IMMEDIATE 'ALTER USER ' || p_name || ' IDENTIFIED BY "' || p_password || '" ACCOUNT UNLOCK';
        END IF;
        EXECUTE IMMEDIATE 'GRANT CREATE SESSION TO ' || p_name;
    END;

    PROCEDURE ensure_role(p_name VARCHAR2) IS
        v_exists NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_exists FROM dba_roles WHERE role = UPPER(p_name);
        IF v_exists = 0 THEN
            EXECUTE IMMEDIATE 'CREATE ROLE ' || p_name;
        END IF;
    END;
BEGIN
    -- Demo-only passwords. Change them in a real environment.
    ensure_user('alice', 'Alice#5322');
    ensure_user('bob', 'Bob#5322');
    ensure_user('carol', 'Carol#5322');
    ensure_user('prof_lee', 'Lee#5322');
    ensure_user('prof_wong', 'Wong#5322');
    ensure_user('admin_comp', 'Comp#5322');
    ensure_user('admin_bus', 'Bus#5322');
    ensure_user('finance1', 'Finance#5322');
    ensure_user('housing1', 'Housing#5322');
    ensure_user('uni_admin', 'Uni#5322');

    ensure_role('cs5322_student_role');
    ensure_role('cs5322_professor_role');
    ensure_role('cs5322_dept_admin_role');
    ensure_role('cs5322_finance_role');
    ensure_role('cs5322_housing_officer_role');
    ensure_role('cs5322_university_admin_role');
END;
/

GRANT cs5322_student_role TO alice, bob, carol;
GRANT cs5322_professor_role TO prof_lee, prof_wong;
GRANT cs5322_dept_admin_role TO admin_comp, admin_bus;
GRANT cs5322_finance_role TO finance1;
GRANT cs5322_housing_officer_role TO housing1;
GRANT cs5322_university_admin_role TO uni_admin;

-- Object privileges live in one file so that a rebuild only needs to re-run that file.
@@02_regrant_object_privileges.sql
