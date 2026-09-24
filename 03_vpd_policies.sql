-- CS5322 Project I: VPD policies with section-based course offerings.
-- Run as CS5322_P1 (the project schema owner), not SYS.
BEGIN
    FOR p IN (SELECT policy_name, object_name FROM user_policies
              WHERE policy_name IN ('STUDENT_VPD','COURSE_VPD','SECTION_VPD','ENROLLMENT_VPD','GRADE_VPD','PAYMENT_VPD',
                                    'RESIDENCE_VPD','RESIDENCE_ROOM_VPD','ROOM_ALLOCATION_VPD')) LOOP
        DBMS_RLS.DROP_POLICY(USER, p.object_name, p.policy_name);
    END LOOP;
END;
/

CREATE OR REPLACE FUNCTION student_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
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

CREATE OR REPLACE FUNCTION course_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN RETURN 'department_id = ' || v_dept;
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'course_id IN (SELECT x.course_id FROM section x JOIN professor p ON p.professor_id=x.professor_id WHERE p.user_id=' || v_user_id || ')';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'course_id IN (SELECT x.course_id FROM enrollment e JOIN section x ON x.section_id=e.section_id JOIN student s ON s.student_id=e.student_id WHERE s.user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION section_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN
        RETURN 'course_id IN (SELECT course_id FROM course WHERE department_id=' || v_dept || ')';
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'professor_id = (SELECT professor_id FROM professor WHERE user_id=' || v_user_id || ')';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'section_id IN (SELECT e.section_id FROM enrollment e JOIN student s ON s.student_id=e.student_id WHERE s.user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION enrollment_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN
        RETURN 'section_id IN (SELECT x.section_id FROM section x JOIN course c ON c.course_id=x.course_id WHERE c.department_id=' || v_dept || ')';
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'section_id IN (SELECT x.section_id FROM section x JOIN professor p ON p.professor_id=x.professor_id WHERE p.user_id=' || v_user_id || ')';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'student_id=(SELECT student_id FROM student WHERE user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION grade_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
    v_dept VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','DEPARTMENT_ID');
BEGIN
    IF v_role = 'UNIVERSITY_ADMIN' THEN RETURN '1=1';
    ELSIF v_role = 'DEPT_ADMIN' THEN
        RETURN 'enrollment_id IN (SELECT e.enrollment_id FROM enrollment e JOIN section x ON x.section_id=e.section_id JOIN course c ON c.course_id=x.course_id WHERE c.department_id=' || v_dept || ')';
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'enrollment_id IN (SELECT e.enrollment_id FROM enrollment e JOIN section x ON x.section_id=e.section_id JOIN professor p ON p.professor_id=x.professor_id WHERE p.user_id=' || v_user_id || ')';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'enrollment_id IN (SELECT e.enrollment_id FROM enrollment e JOIN student s ON s.student_id=e.student_id WHERE s.user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION payment_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
BEGIN
    IF v_role IN ('UNIVERSITY_ADMIN','FINANCE') THEN RETURN '1=1';
    ELSIF v_role = 'STUDENT' THEN RETURN 'student_id=(SELECT student_id FROM student WHERE user_id=' || v_user_id || ')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION residence_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
BEGIN
    IF v_role IN ('UNIVERSITY_ADMIN','HOUSING_OFFICER') THEN RETURN '1=1';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'residence_id IN (SELECT rr.residence_id FROM room_allocation a JOIN residence_room rr ON rr.room_id=a.room_id JOIN student s ON s.student_id=a.student_id WHERE s.user_id=' || v_user_id || ' AND a.allocation_status=''ACTIVE'')';
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'residence_id IN (SELECT rr.residence_id FROM room_allocation a JOIN residence_room rr ON rr.room_id=a.room_id JOIN professor p ON p.professor_id=a.professor_id WHERE p.user_id=' || v_user_id || ' AND a.allocation_status=''ACTIVE'')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION residence_room_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
BEGIN
    IF v_role IN ('UNIVERSITY_ADMIN','HOUSING_OFFICER') THEN RETURN '1=1';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'room_id IN (SELECT a.room_id FROM room_allocation a JOIN student s ON s.student_id=a.student_id WHERE s.user_id=' || v_user_id || ' AND a.allocation_status=''ACTIVE'')';
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'residence_id IN (SELECT rr.residence_id FROM room_allocation a JOIN residence_room rr ON rr.room_id=a.room_id JOIN professor p ON p.professor_id=a.professor_id WHERE p.user_id=' || v_user_id || ' AND a.allocation_status=''ACTIVE'')';
    ELSE RETURN '1=0'; END IF;
END;
/

CREATE OR REPLACE FUNCTION room_allocation_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
    v_role VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','ROLE');
    v_user_id VARCHAR2(30) := SYS_CONTEXT('CS5322_APP_CTX','USER_ID');
BEGIN
    IF v_role IN ('UNIVERSITY_ADMIN','HOUSING_OFFICER') THEN RETURN '1=1';
    ELSIF v_role = 'STUDENT' THEN
        RETURN 'student_id = (SELECT student_id FROM student WHERE user_id=' || v_user_id || ')';
    ELSIF v_role = 'PROFESSOR' THEN
        RETURN 'room_id IN (SELECT rr.room_id FROM room_allocation own_a JOIN residence_room rr ON rr.room_id=own_a.room_id JOIN professor p ON p.professor_id=own_a.professor_id WHERE p.user_id=' || v_user_id || ' AND own_a.allocation_status=''ACTIVE'')';
    ELSE RETURN '1=0'; END IF;
END;
/

BEGIN
    DBMS_RLS.ADD_POLICY(USER,'STUDENT','STUDENT_VPD',USER,'STUDENT_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'COURSE','COURSE_VPD',USER,'COURSE_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'SECTION','SECTION_VPD',USER,'SECTION_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'ENROLLMENT','ENROLLMENT_VPD',USER,'ENROLLMENT_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'GRADE','GRADE_VPD',USER,'GRADE_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'PAYMENT','PAYMENT_VPD',USER,'PAYMENT_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'RESIDENCE','RESIDENCE_VPD',USER,'RESIDENCE_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'RESIDENCE_ROOM','RESIDENCE_ROOM_VPD',USER,'RESIDENCE_ROOM_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
    DBMS_RLS.ADD_POLICY(USER,'ROOM_ALLOCATION','ROOM_ALLOCATION_VPD',USER,'ROOM_ALLOCATION_VPD_FN','SELECT,INSERT,UPDATE,DELETE',TRUE,TRUE);
END;
/

GRANT EXECUTE ON CS5322_P1.cs5322_security_ctx TO PUBLIC;
