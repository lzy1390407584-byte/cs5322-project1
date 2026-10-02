-- CS5322 Project I: VPD predicate helpers, policy functions and DBMS_RLS policies.
-- Run as CS5322_P1 (the schema owner), never as SYS: the policy functions and the
-- policies must belong to the same schema as the protected tables.
--
-- Every table has a SELECT policy (<TABLE>_VPD) and a separate policy for
-- INSERT/UPDATE/DELETE (<TABLE>_WRITE_VPD) that denies by default, so a role that is
-- granted write privileges by mistake still cannot touch rows it may not manage.

-- 1. Remove existing policies so that the script can be re-run.
BEGIN
    FOR p IN (SELECT object_name, policy_name FROM user_policies) LOOP
        DBMS_RLS.DROP_POLICY(USER, p.object_name, p.policy_name);
    END LOOP;
END;
/

-- 2. Predicate helpers.  They only read the trusted application context and return
--    SQL text; every value spliced into a predicate is a number taken from the
--    context, never user input.  A missing context yields -1, which matches no row.
CREATE OR REPLACE PACKAGE cs5322_vpd_helper AS
    FUNCTION ctx_role RETURN VARCHAR2;
    FUNCTION ctx_user_id RETURN VARCHAR2;
    FUNCTION ctx_dept_id RETURN VARCHAR2;
    FUNCTION my_student RETURN VARCHAR2;
    FUNCTION my_professor RETURN VARCHAR2;
    FUNCTION fellow_residences RETURN VARCHAR2;
    FUNCTION student_sections RETURN VARCHAR2;
    FUNCTION professor_sections RETURN VARCHAR2;
    FUNCTION dept_sections RETURN VARCHAR2;
    FUNCTION student_enrollments RETURN VARCHAR2;
    FUNCTION professor_enrollments RETURN VARCHAR2;
    FUNCTION dept_enrollments RETURN VARCHAR2;
END;
/

CREATE OR REPLACE PACKAGE BODY cs5322_vpd_helper AS
    FUNCTION ctx_role RETURN VARCHAR2 IS
    BEGIN
        RETURN SYS_CONTEXT('CS5322_APP_CTX', 'ROLE');
    END;

    FUNCTION ctx_user_id RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(SYS_CONTEXT('CS5322_APP_CTX', 'USER_ID'), '-1');
    END;

    FUNCTION ctx_dept_id RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(SYS_CONTEXT('CS5322_APP_CTX', 'DEPARTMENT_ID'), '-1');
    END;

    -- The caller's own STUDENT / PROFESSOR key, resolved through the identity mapping.
    FUNCTION my_student RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT student_id FROM student WHERE user_id = ' || ctx_user_id || ')';
    END;

    FUNCTION my_professor RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT professor_id FROM professor WHERE user_id = ' || ctx_user_id || ')';
    END;

    -- Residences the caller currently looks after as resident fellow.  The data comes
    -- from RESIDENT_FELLOW, not from ROOM_ALLOCATION, so that no policy on
    -- ROOM_ALLOCATION has to query ROOM_ALLOCATION (that recursion raises ORA-28113).
    FUNCTION fellow_residences RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT rf.residence_id FROM resident_fellow rf WHERE rf.status = ''ACTIVE'''
            || ' AND rf.professor_id = ' || my_professor || ')';
    END;

    FUNCTION student_sections RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT e.section_id FROM enrollment e WHERE e.status <> ''DROPPED'''
            || ' AND e.student_id = ' || my_student || ')';
    END;

    FUNCTION professor_sections RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT x.section_id FROM section x WHERE x.professor_id = ' || my_professor || ')';
    END;

    -- Sections whose COURSE belongs to the caller's department (not a submitted value).
    FUNCTION dept_sections RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT x.section_id FROM section x JOIN course c ON c.course_id = x.course_id'
            || ' WHERE c.department_id = ' || ctx_dept_id || ')';
    END;

    FUNCTION student_enrollments RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT e.enrollment_id FROM enrollment e WHERE e.student_id = ' || my_student || ')';
    END;

    FUNCTION professor_enrollments RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT e.enrollment_id FROM enrollment e WHERE e.section_id IN ' || professor_sections || ')';
    END;

    FUNCTION dept_enrollments RETURN VARCHAR2 IS
    BEGIN
        RETURN '(SELECT e.enrollment_id FROM enrollment e WHERE e.section_id IN ' || dept_sections || ')';
    END;
END;
/

-- 3. SELECT policy functions.  Unknown or missing roles fall through to 1=0.

-- Reference data: every authenticated application user may read it.
CREATE OR REPLACE FUNCTION department_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE WHEN cs5322_vpd_helper.ctx_role IN
                ('STUDENT','PROFESSOR','DEPT_ADMIN','FINANCE','HOUSING_OFFICER','UNIVERSITY_ADMIN')
                THEN '1=1' ELSE '1=0' END;
END;
/

-- A professor sees the students of the sections he teaches, plus the residents of the
-- residence he looks after as fellow.  Finance sees every student (e-mail is masked by
-- STUDENT_EMAIL_MASK_VPD); housing sees students that have a room allocation.
CREATE OR REPLACE FUNCTION student_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'FINANCE' THEN '1=1'
        WHEN 'DEPT_ADMIN' THEN 'department_id = ' || cs5322_vpd_helper.ctx_dept_id
        WHEN 'STUDENT' THEN 'user_id = ' || cs5322_vpd_helper.ctx_user_id
        WHEN 'PROFESSOR' THEN
            '(student_id IN (SELECT e.student_id FROM enrollment e WHERE e.status <> ''DROPPED'''
            || ' AND e.section_id IN ' || cs5322_vpd_helper.professor_sections || ')'
            || ' OR student_id IN (SELECT a.student_id FROM room_allocation a WHERE a.student_id IS NOT NULL'
            || ' AND a.allocation_status = ''ACTIVE'' AND a.room_id IN (SELECT rr.room_id FROM residence_room rr'
            || ' WHERE rr.residence_id IN ' || cs5322_vpd_helper.fellow_residences || ')))'
        WHEN 'HOUSING_OFFICER' THEN
            'student_id IN (SELECT a.student_id FROM room_allocation a WHERE a.student_id IS NOT NULL)'
        ELSE '1=0'
    END;
END;
/

-- Column-level policy on STUDENT.EMAIL: only roles with a need to contact the student
-- may read it.  Finance still sees the rows, but the column comes back NULL.
CREATE OR REPLACE FUNCTION student_email_mask_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE WHEN cs5322_vpd_helper.ctx_role IN
                ('UNIVERSITY_ADMIN','DEPT_ADMIN','PROFESSOR','STUDENT','HOUSING_OFFICER')
                THEN '1=1' ELSE '1=0' END;
END;
/

CREATE OR REPLACE FUNCTION professor_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'DEPT_ADMIN' THEN 'department_id = ' || cs5322_vpd_helper.ctx_dept_id
        WHEN 'PROFESSOR' THEN 'user_id = ' || cs5322_vpd_helper.ctx_user_id
        WHEN 'STUDENT' THEN
            'professor_id IN (SELECT x.professor_id FROM section x WHERE x.section_id IN '
            || cs5322_vpd_helper.student_sections || ')'
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION course_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'DEPT_ADMIN' THEN 'department_id = ' || cs5322_vpd_helper.ctx_dept_id
        WHEN 'PROFESSOR' THEN
            'course_id IN (SELECT x.course_id FROM section x WHERE x.section_id IN '
            || cs5322_vpd_helper.professor_sections || ')'
        WHEN 'STUDENT' THEN
            'course_id IN (SELECT x.course_id FROM section x WHERE x.section_id IN '
            || cs5322_vpd_helper.student_sections || ')'
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION section_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'DEPT_ADMIN' THEN
            'course_id IN (SELECT c.course_id FROM course c WHERE c.department_id = '
            || cs5322_vpd_helper.ctx_dept_id || ')'
        WHEN 'PROFESSOR' THEN 'professor_id = ' || cs5322_vpd_helper.my_professor
        WHEN 'STUDENT' THEN 'section_id IN ' || cs5322_vpd_helper.student_sections
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION enrollment_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'DEPT_ADMIN' THEN 'section_id IN ' || cs5322_vpd_helper.dept_sections
        WHEN 'PROFESSOR' THEN 'section_id IN ' || cs5322_vpd_helper.professor_sections
        WHEN 'STUDENT' THEN 'student_id = ' || cs5322_vpd_helper.my_student
        ELSE '1=0'
    END;
END;
/

-- Students only see grades that have been released.  Professors and the department
-- see drafts as well.
CREATE OR REPLACE FUNCTION grade_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'DEPT_ADMIN' THEN 'enrollment_id IN ' || cs5322_vpd_helper.dept_enrollments
        WHEN 'PROFESSOR' THEN 'enrollment_id IN ' || cs5322_vpd_helper.professor_enrollments
        WHEN 'STUDENT' THEN
            'released = ''Y'' AND enrollment_id IN ' || cs5322_vpd_helper.student_enrollments
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION payment_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'FINANCE' THEN '1=1'
        WHEN 'STUDENT' THEN 'student_id = ' || cs5322_vpd_helper.my_student
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION residence_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'HOUSING_OFFICER' THEN '1=1'
        WHEN 'STUDENT' THEN
            'residence_id IN (SELECT rr.residence_id FROM residence_room rr WHERE rr.room_id IN'
            || ' (SELECT a.room_id FROM room_allocation a WHERE a.student_id = ' || cs5322_vpd_helper.my_student
            || ' AND a.allocation_status = ''ACTIVE''))'
        WHEN 'PROFESSOR' THEN 'residence_id IN ' || cs5322_vpd_helper.fellow_residences
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION residence_room_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'HOUSING_OFFICER' THEN '1=1'
        WHEN 'STUDENT' THEN
            'room_id IN (SELECT a.room_id FROM room_allocation a WHERE a.student_id = '
            || cs5322_vpd_helper.my_student || ' AND a.allocation_status = ''ACTIVE'')'
        WHEN 'PROFESSOR' THEN 'residence_id IN ' || cs5322_vpd_helper.fellow_residences
        ELSE '1=0'
    END;
END;
/

-- A student sees his own allocations (including past ones).  A resident fellow sees
-- the active allocations of every room in the residence he looks after.
CREATE OR REPLACE FUNCTION room_allocation_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'HOUSING_OFFICER' THEN '1=1'
        WHEN 'STUDENT' THEN 'student_id = ' || cs5322_vpd_helper.my_student
        WHEN 'PROFESSOR' THEN
            '(allocation_status = ''ACTIVE'' AND room_id IN (SELECT rr.room_id FROM residence_room rr'
            || ' WHERE rr.residence_id IN ' || cs5322_vpd_helper.fellow_residences || '))'
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION resident_fellow_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        WHEN 'HOUSING_OFFICER' THEN '1=1'
        WHEN 'PROFESSOR' THEN 'professor_id = ' || cs5322_vpd_helper.my_professor
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION grade_audit_vpd_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'UNIVERSITY_ADMIN' THEN '1=1'
        ELSE '1=0'
    END;
END;
/

-- 4. Write policy functions (INSERT / UPDATE / DELETE).  The predicate is also checked
--    against the new row (update_check), so a row cannot be moved out of scope.
CREATE OR REPLACE FUNCTION student_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'DEPT_ADMIN' THEN 'department_id = ' || cs5322_vpd_helper.ctx_dept_id
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION course_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'DEPT_ADMIN' THEN 'department_id = ' || cs5322_vpd_helper.ctx_dept_id
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION section_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'DEPT_ADMIN' THEN
            'course_id IN (SELECT c.course_id FROM course c WHERE c.department_id = '
            || cs5322_vpd_helper.ctx_dept_id || ')'
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION enrollment_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'DEPT_ADMIN' THEN 'section_id IN ' || cs5322_vpd_helper.dept_sections
        ELSE '1=0'
    END;
END;
/

-- Grade workflow.  A professor may only create or edit DRAFT grades of his own sections
-- and cannot publish them or touch published ones; the department administrator
-- reviews, publishes and, if needed, corrects (every change is audited).
CREATE OR REPLACE FUNCTION grade_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'PROFESSOR' THEN
            'released = ''N'' AND enrollment_id IN ' || cs5322_vpd_helper.professor_enrollments
        WHEN 'DEPT_ADMIN' THEN 'enrollment_id IN ' || cs5322_vpd_helper.dept_enrollments
        ELSE '1=0'
    END;
END;
/

-- Published grades are permanent: only drafts of the department can be deleted.
CREATE OR REPLACE FUNCTION grade_delete_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'DEPT_ADMIN' THEN
            'released = ''N'' AND enrollment_id IN ' || cs5322_vpd_helper.dept_enrollments
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION payment_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'FINANCE' THEN '1=1'
        ELSE '1=0'
    END;
END;
/

CREATE OR REPLACE FUNCTION room_allocation_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN CASE cs5322_vpd_helper.ctx_role
        WHEN 'HOUSING_OFFICER' THEN '1=1'
        ELSE '1=0'
    END;
END;
/

-- Tables that no application role may modify through SQL.
CREATE OR REPLACE FUNCTION deny_write_fn(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
    RETURN '1=0';
END;
/

-- 5. Register the policies.  CONTEXT_SENSITIVE: the predicate depends only on the
--    application context, so Oracle re-runs the policy function only when the context
--    changes instead of on every execution.
DECLARE
    PROCEDURE add_pol(p_table VARCHAR2, p_policy VARCHAR2, p_fn VARCHAR2,
                      p_stmts VARCHAR2, p_check BOOLEAN DEFAULT FALSE) IS
    BEGIN
        DBMS_RLS.ADD_POLICY(
            object_schema   => USER,
            object_name     => p_table,
            policy_name     => p_policy,
            function_schema => USER,
            policy_function => p_fn,
            statement_types => p_stmts,
            update_check    => p_check,
            enable          => TRUE,
            policy_type     => DBMS_RLS.CONTEXT_SENSITIVE);
    END;
BEGIN
    -- Read policies
    add_pol('DEPARTMENT',      'DEPARTMENT_VPD',      'DEPARTMENT_VPD_FN',      'SELECT');
    add_pol('STUDENT',         'STUDENT_VPD',         'STUDENT_VPD_FN',         'SELECT');
    add_pol('PROFESSOR',       'PROFESSOR_VPD',       'PROFESSOR_VPD_FN',       'SELECT');
    add_pol('COURSE',          'COURSE_VPD',          'COURSE_VPD_FN',          'SELECT');
    add_pol('SECTION',         'SECTION_VPD',         'SECTION_VPD_FN',         'SELECT');
    add_pol('ENROLLMENT',      'ENROLLMENT_VPD',      'ENROLLMENT_VPD_FN',      'SELECT');
    add_pol('GRADE',           'GRADE_VPD',           'GRADE_VPD_FN',           'SELECT');
    add_pol('PAYMENT',         'PAYMENT_VPD',         'PAYMENT_VPD_FN',         'SELECT');
    add_pol('RESIDENCE',       'RESIDENCE_VPD',       'RESIDENCE_VPD_FN',       'SELECT');
    add_pol('RESIDENCE_ROOM',  'RESIDENCE_ROOM_VPD',  'RESIDENCE_ROOM_VPD_FN',  'SELECT');
    add_pol('ROOM_ALLOCATION', 'ROOM_ALLOCATION_VPD', 'ROOM_ALLOCATION_VPD_FN', 'SELECT');
    add_pol('RESIDENT_FELLOW', 'RESIDENT_FELLOW_VPD', 'RESIDENT_FELLOW_VPD_FN', 'SELECT');
    add_pol('GRADE_AUDIT',     'GRADE_AUDIT_VPD',     'GRADE_AUDIT_VPD_FN',     'SELECT');

    -- Column-level policy: with ALL_ROWS the rows stay visible and only the
    -- sensitive column is returned as NULL when the predicate is false.
    DBMS_RLS.ADD_POLICY(
        object_schema         => USER,
        object_name           => 'STUDENT',
        policy_name           => 'STUDENT_EMAIL_MASK_VPD',
        function_schema       => USER,
        policy_function       => 'STUDENT_EMAIL_MASK_FN',
        statement_types       => 'SELECT',
        enable                => TRUE,
        policy_type           => DBMS_RLS.CONTEXT_SENSITIVE,
        sec_relevant_cols     => 'EMAIL',
        sec_relevant_cols_opt => DBMS_RLS.ALL_ROWS);

    -- Write policies (update_check => TRUE validates the new row as well).  GRADE_AUDIT
    -- has none: it is filled by a trigger and no role holds a write privilege on it.
    add_pol('STUDENT',         'STUDENT_WRITE_VPD',         'STUDENT_WRITE_FN',         'INSERT,UPDATE,DELETE', TRUE);
    add_pol('COURSE',          'COURSE_WRITE_VPD',          'COURSE_WRITE_FN',          'INSERT,UPDATE,DELETE', TRUE);
    add_pol('SECTION',         'SECTION_WRITE_VPD',         'SECTION_WRITE_FN',         'INSERT,UPDATE,DELETE', TRUE);
    add_pol('ENROLLMENT',      'ENROLLMENT_WRITE_VPD',      'ENROLLMENT_WRITE_FN',      'INSERT,UPDATE,DELETE', TRUE);
    add_pol('GRADE',           'GRADE_WRITE_VPD',           'GRADE_WRITE_FN',           'INSERT,UPDATE', TRUE);
    add_pol('GRADE',           'GRADE_DELETE_VPD',          'GRADE_DELETE_FN',          'DELETE');
    add_pol('PAYMENT',         'PAYMENT_WRITE_VPD',         'PAYMENT_WRITE_FN',         'INSERT,UPDATE,DELETE', TRUE);
    add_pol('ROOM_ALLOCATION', 'ROOM_ALLOCATION_WRITE_VPD', 'ROOM_ALLOCATION_WRITE_FN', 'INSERT,UPDATE,DELETE', TRUE);
    add_pol('DEPARTMENT',      'DEPARTMENT_WRITE_VPD',      'DENY_WRITE_FN',            'INSERT,UPDATE,DELETE', TRUE);
    add_pol('PROFESSOR',       'PROFESSOR_WRITE_VPD',       'DENY_WRITE_FN',            'INSERT,UPDATE,DELETE', TRUE);
    add_pol('RESIDENCE',       'RESIDENCE_WRITE_VPD',       'DENY_WRITE_FN',            'INSERT,UPDATE,DELETE', TRUE);
    add_pol('RESIDENCE_ROOM',  'RESIDENCE_ROOM_WRITE_VPD',  'DENY_WRITE_FN',            'INSERT,UPDATE,DELETE', TRUE);
    add_pol('RESIDENT_FELLOW', 'RESIDENT_FELLOW_WRITE_VPD', 'DENY_WRITE_FN',            'INSERT,UPDATE,DELETE', TRUE);
END;
/
