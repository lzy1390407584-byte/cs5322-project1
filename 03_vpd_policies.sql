-- CS5322 Project I: VPD policy implementation
-- Run as CS5322_P1 (the project schema owner), not SYS.

-- Remove stale policies from an earlier attempt so this script is rerunnable.
BEGIN
    FOR p IN (SELECT policy_name, object_name FROM user_policies
              WHERE policy_name IN ('STUDENT_VPD','COURSE_VPD','ENROLLMENT_VPD','GRADE_VPD','PAYMENT_VPD')) LOOP
        DBMS_RLS.DROP_POLICY(USER, p.object_name, p.policy_name);
    END LOOP;
END;
/

CREATE OR REPLACE FUNCTION student_vpd_fn(
    p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN RETURN 'department_id = ' || v_dept;
    ELSIF v_role = 'STUDENT' THEN RETURN 'user_id = ' || v_user_id;
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION course_vpd_fn(
    p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN RETURN 'department_id = ' || v_dept;
    ELSIF v_role = 'PROFESSOR' THEN RETURN 'professor_id = (SELECT professor_id FROM professor WHERE user_id = ' || v_user_id || ')';
    ELSIF v_role = 'STUDENT' THEN RETURN 'course_id IN (SELECT e.course_id FROM enrollment e JOIN student s ON s.student_id=e.student_id WHERE s.user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION enrollment_vpd_fn(
    p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN RETURN 'student_id IN (SELECT student_id FROM student WHERE department_id=' || v_dept || ')';
    ELSIF v_role = 'PROFESSOR' THEN RETURN 'course_id IN (SELECT course_id FROM course WHERE professor_id=(SELECT professor_id FROM professor WHERE user_id=' || v_user_id || '))';
    ELSIF v_role = 'STUDENT' THEN RETURN 'student_id=(SELECT student_id FROM student WHERE user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION grade_vpd_fn(
    p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN RETURN 'enrollment_id IN (SELECT e.enrollment_id FROM enrollment e JOIN student s ON s.student_id=e.student_id WHERE s.department_id=' || v_dept || ')';
    ELSIF v_role = 'PROFESSOR' THEN RETURN 'enrollment_id IN (SELECT e.enrollment_id FROM enrollment e JOIN course c ON c.course_id=e.course_id WHERE c.professor_id=(SELECT professor_id FROM professor WHERE user_id=' || v_user_id || '))';
    ELSIF v_role = 'STUDENT' THEN RETURN 'enrollment_id IN (SELECT e.enrollment_id FROM enrollment e JOIN student s ON s.student_id=e.student_id WHERE s.user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION payment_vpd_fn(
    p_schema VARCHAR2, p_object VARCHAR2
) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
BEGIN
    IF v_role IN ('UNIVERSITY_ADMIN','FINANCE') THEN RETURN '1=1';
    ELSIF v_role = 'STUDENT' THEN RETURN 'student_id=(SELECT student_id FROM student WHERE user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(USER,'STUDENT','STUDENT_VPD',USER,'STUDENT_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'COURSE','COURSE_VPD',USER,'COURSE_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'ENROLLMENT','ENROLLMENT_VPD',USER,'ENROLLMENT_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'GRADE','GRADE_VPD',USER,'GRADE_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'PAYMENT','PAYMENT_VPD',USER,'PAYMENT_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
END;
/

-- Allow the context package to be called by application users.
GRANT EXECUTE ON CS5322_P1.cs5322_security_ctx TO PUBLIC;
