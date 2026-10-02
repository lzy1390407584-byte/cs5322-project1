-- Optional reset script. Run as CS5322_P1 only when rebuilding the project from scratch.
-- Drops every object created by 01, 03 and 03b (policies, triggers, tables, functions,
-- packages). Demo users, roles and the application context are kept: after rebuilding,
-- re-run 02_users_roles.sql (or just 02_regrant_object_privileges.sql) as SYSDBA, because
-- Oracle removes object grants together with the tables.
DECLARE
    PROCEDURE run_ddl(p_sql VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_sql;
    EXCEPTION
        -- table/object/trigger does not exist: nothing to drop
        WHEN OTHERS THEN
            IF SQLCODE NOT IN (-942, -4043, -4080) THEN
                RAISE;
            END IF;
    END;
BEGIN
    FOR p IN (SELECT object_name, policy_name FROM user_policies) LOOP
        DBMS_RLS.DROP_POLICY(USER, p.object_name, p.policy_name);
    END LOOP;

    run_ddl('DROP TRIGGER grade_audit_trg');
    run_ddl('DROP TRIGGER grade_editor_trg');

    FOR t IN (SELECT column_value AS name FROM TABLE(sys.odcivarchar2list(
                  'GRADE_AUDIT','PAYMENT','ROOM_ALLOCATION','RESIDENT_FELLOW','RESIDENCE_ROOM','RESIDENCE',
                  'GRADE','ENROLLMENT','SECTION','COURSE','PROFESSOR','STUDENT','APP_USER','DEPARTMENT'))) LOOP
        run_ddl('DROP TABLE ' || t.name || ' CASCADE CONSTRAINTS PURGE');
    END LOOP;

    FOR f IN (SELECT object_name FROM user_objects
               WHERE object_type = 'FUNCTION' AND object_name LIKE '%\_FN' ESCAPE '\') LOOP
        run_ddl('DROP FUNCTION ' || f.object_name);
    END LOOP;

    run_ddl('DROP PACKAGE cs5322_test');
    run_ddl('DROP PACKAGE cs5322_vpd_helper');
    run_ddl('DROP PACKAGE cs5322_security_ctx');
END;
/
