-- Optional reset script. Run as DBA/schema owner only when resetting this project.
BEGIN
    FOR p IN (SELECT policy_name, object_name FROM user_policies
              WHERE policy_name IN ('STUDENT_VPD','COURSE_VPD','ENROLLMENT_VPD','GRADE_VPD','PAYMENT_VPD')) LOOP
        DBMS_RLS.DROP_POLICY(USER, p.object_name, p.policy_name);
    END LOOP;
END;
/

DROP TABLE payment CASCADE CONSTRAINTS;
DROP TABLE grade CASCADE CONSTRAINTS;
DROP TABLE enrollment CASCADE CONSTRAINTS;
DROP TABLE course CASCADE CONSTRAINTS;
DROP TABLE professor CASCADE CONSTRAINTS;
DROP TABLE student CASCADE CONSTRAINTS;
DROP TABLE app_user CASCADE CONSTRAINTS;
DROP TABLE department CASCADE CONSTRAINTS;
DROP PACKAGE cs5322_security_ctx;
DROP CONTEXT cs5322_app_ctx;
