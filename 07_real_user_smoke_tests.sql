-- End-to-end READ checks with real database logins: object privileges and VPD together,
-- plus attempts to impersonate another user or to read tables the role has no grant on.
-- Run from the VM (type EXIT afterwards):  sqlplus /nolog @07_real_user_smoke_tests.sql
-- Needs 03b_test_support.sql.  Through an SSH tunnel the same service string works, because
-- the tunnel forwards localhost:1521 to the VM.
DEFINE svc = "localhost:1521/cs5322"
SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 200

PROMPT === alice (student, Computing) ===
CONNECT alice/"Alice#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_test.expect_count('alice before activating an identity sees no students', 'SELECT COUNT(*) FROM CS5322_P1.student', 0);
    CS5322_P1.cs5322_test.expect_error('alice cannot impersonate bob', 'BEGIN CS5322_P1.cs5322_security_ctx.set_user(''bob''); END;', -20002);
    CS5322_P1.cs5322_test.expect_error('alice cannot become the university administrator', 'BEGIN CS5322_P1.cs5322_security_ctx.set_user(''uni_admin''); END;', -20002);
    CS5322_P1.cs5322_test.expect_error('alice cannot forge the context with DBMS_SESSION.SET_CONTEXT', 'BEGIN DBMS_SESSION.SET_CONTEXT(''CS5322_APP_CTX'', ''ROLE'', ''UNIVERSITY_ADMIN''); END;', -1031);
    CS5322_P1.cs5322_test.expect_count('failed impersonation and forgery attempts grant nothing', 'SELECT COUNT(*) FROM CS5322_P1.student', 0);
    CS5322_P1.cs5322_security_ctx.set_user('alice');
    CS5322_P1.cs5322_test.expect_count('alice sees only her own student row', 'SELECT COUNT(*) FROM CS5322_P1.student', 1);
    CS5322_P1.cs5322_test.expect_count('alice sees the instructor of her sections', 'SELECT COUNT(*) FROM CS5322_P1.professor', 1);
    CS5322_P1.cs5322_test.expect_count('alice sees her 2 courses', 'SELECT COUNT(*) FROM CS5322_P1.course', 2);
    CS5322_P1.cs5322_test.expect_count('alice sees her 2 sections', 'SELECT COUNT(*) FROM CS5322_P1.section', 2);
    CS5322_P1.cs5322_test.expect_count('alice sees her 2 enrollments', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 2);
    CS5322_P1.cs5322_test.expect_count('alice sees only the released grade (the other is a draft)', 'SELECT COUNT(*) FROM CS5322_P1.grade', 1);
    CS5322_P1.cs5322_test.expect_count('alice sees her own payment', 'SELECT COUNT(*) FROM CS5322_P1.payment', 1);
    CS5322_P1.cs5322_test.expect_count('alice sees her residence', 'SELECT COUNT(*) FROM CS5322_P1.residence', 1);
    CS5322_P1.cs5322_test.expect_count('alice sees her room', 'SELECT COUNT(*) FROM CS5322_P1.residence_room', 1);
    CS5322_P1.cs5322_test.expect_count('alice sees her allocation', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', 1);
    CS5322_P1.cs5322_test.expect_error('alice has no grant on RESIDENT_FELLOW', 'SELECT COUNT(*) FROM CS5322_P1.resident_fellow', -942);
    CS5322_P1.cs5322_test.expect_error('alice has no grant on GRADE_AUDIT', 'SELECT COUNT(*) FROM CS5322_P1.grade_audit', -942);
    CS5322_P1.cs5322_test.expect_error('alice has no grant on APP_USER', 'SELECT COUNT(*) FROM CS5322_P1.app_user', -942);
    CS5322_P1.cs5322_security_ctx.clear_user;
    CS5322_P1.cs5322_test.expect_count('after clear_user alice sees nothing again', 'SELECT COUNT(*) FROM CS5322_P1.student', 0);
    CS5322_P1.cs5322_test.summary('alice');
END;
/

PROMPT === bob (student, Business) ===
CONNECT bob/"Bob#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('bob');
    CS5322_P1.cs5322_test.expect_count('bob sees only his own student row', 'SELECT COUNT(*) FROM CS5322_P1.student', 1);
    CS5322_P1.cs5322_test.expect_count('bob sees 2 courses (a Business and a Computing course)', 'SELECT COUNT(*) FROM CS5322_P1.course', 2);
    CS5322_P1.cs5322_test.expect_count('bob sees 2 enrollments', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 2);
    CS5322_P1.cs5322_test.expect_count('bob sees his one released grade', 'SELECT COUNT(*) FROM CS5322_P1.grade', 1);
    CS5322_P1.cs5322_test.expect_count('bob sees his payment', 'SELECT COUNT(*) FROM CS5322_P1.payment', 1);
    CS5322_P1.cs5322_test.expect_count('bob sees his current room only (ended allocation hides the old room)', 'SELECT COUNT(*) FROM CS5322_P1.residence_room', 1);
    CS5322_P1.cs5322_test.expect_count('bob sees his allocation history (2 rows)', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', 2);
    CS5322_P1.cs5322_test.summary('bob');
END;
/

PROMPT === carol (student, Medicine) ===
CONNECT carol/"Carol#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('carol');
    CS5322_P1.cs5322_test.expect_count('carol sees only her own student row', 'SELECT COUNT(*) FROM CS5322_P1.student', 1);
    CS5322_P1.cs5322_test.expect_count('carol sees 1 enrollment', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 1);
    CS5322_P1.cs5322_test.expect_count('carol sees her grade', 'SELECT COUNT(*) FROM CS5322_P1.grade', 1);
    CS5322_P1.cs5322_test.expect_count('carol sees her residence', 'SELECT COUNT(*) FROM CS5322_P1.residence', 1);
    CS5322_P1.cs5322_test.summary('carol');
END;
/

PROMPT === prof_lee (professor, Computing, resident fellow of Kent Ridge Hall) ===
CONNECT prof_lee/"Lee#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_test.expect_error('prof_lee cannot become the university administrator', 'BEGIN CS5322_P1.cs5322_security_ctx.set_user(''uni_admin''); END;', -20002);
    CS5322_P1.cs5322_security_ctx.set_user('prof_lee');
    CS5322_P1.cs5322_test.expect_count('prof_lee sees only his own professor row', 'SELECT COUNT(*) FROM CS5322_P1.professor', 1);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees his 2 courses', 'SELECT COUNT(*) FROM CS5322_P1.course', 2);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees his 2 sections', 'SELECT COUNT(*) FROM CS5322_P1.section', 2);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees the enrollments of his sections', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 2);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees the grades of his sections, drafts included', 'SELECT COUNT(*) FROM CS5322_P1.grade', 2);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees his class list plus the residents of his residence', 'SELECT COUNT(*) FROM CS5322_P1.student', 2);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees his fellowship', 'SELECT COUNT(*) FROM CS5322_P1.resident_fellow', 1);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees Kent Ridge Hall only', 'SELECT COUNT(*) FROM CS5322_P1.residence', 1);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees the 3 rooms of Kent Ridge Hall', 'SELECT COUNT(*) FROM CS5322_P1.residence_room', 3);
    CS5322_P1.cs5322_test.expect_count('prof_lee sees the 3 active allocations of Kent Ridge Hall', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', 3);
    CS5322_P1.cs5322_test.expect_error('prof_lee has no grant on PAYMENT', 'SELECT COUNT(*) FROM CS5322_P1.payment', -942);
    CS5322_P1.cs5322_test.summary('prof_lee');
END;
/

PROMPT === prof_wong (professor, Business, fellow of Prince George's Park) ===
CONNECT prof_wong/"Wong#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('prof_wong');
    CS5322_P1.cs5322_test.expect_count('prof_wong sees his 3 courses (CS5322 S2 is taught by him)', 'SELECT COUNT(*) FROM CS5322_P1.course', 3);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees his 3 sections', 'SELECT COUNT(*) FROM CS5322_P1.section', 3);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees the 3 enrollments of his sections', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 3);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees 2 grades (one enrollment is not graded yet)', 'SELECT COUNT(*) FROM CS5322_P1.grade', 2);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees his two fellowships (one ended)', 'SELECT COUNT(*) FROM CS5322_P1.resident_fellow', 2);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees only the residence he currently looks after', 'SELECT COUNT(*) FROM CS5322_P1.residence', 1);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees the 2 rooms of his residence', 'SELECT COUNT(*) FROM CS5322_P1.residence_room', 2);
    CS5322_P1.cs5322_test.expect_count('prof_wong sees the 2 active allocations of his residence', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', 2);
    CS5322_P1.cs5322_test.summary('prof_wong');
END;
/

PROMPT === admin_comp (Computing department administrator) ===
CONNECT admin_comp/"Comp#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('admin_comp');
    CS5322_P1.cs5322_test.expect_count('admin_comp sees the Computing student only', 'SELECT COUNT(*) FROM CS5322_P1.student', 1);
    CS5322_P1.cs5322_test.expect_count('admin_comp sees the Computing professor only', 'SELECT COUNT(*) FROM CS5322_P1.professor', 1);
    CS5322_P1.cs5322_test.expect_count('admin_comp sees the 2 Computing courses', 'SELECT COUNT(*) FROM CS5322_P1.course', 2);
    CS5322_P1.cs5322_test.expect_count('admin_comp sees the 3 sections of Computing courses', 'SELECT COUNT(*) FROM CS5322_P1.section', 3);
    CS5322_P1.cs5322_test.expect_count('admin_comp sees the 3 enrollments in those sections', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 3);
    CS5322_P1.cs5322_test.expect_count('admin_comp sees the 2 grades of those enrollments', 'SELECT COUNT(*) FROM CS5322_P1.grade', 2);
    CS5322_P1.cs5322_test.expect_error('admin_comp has no grant on PAYMENT', 'SELECT COUNT(*) FROM CS5322_P1.payment', -942);
    CS5322_P1.cs5322_test.expect_error('admin_comp has no grant on ROOM_ALLOCATION', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', -942);
    CS5322_P1.cs5322_test.summary('admin_comp');
END;
/

PROMPT === admin_bus (Business department administrator) ===
CONNECT admin_bus/"Bus#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('admin_bus');
    CS5322_P1.cs5322_test.expect_count('admin_bus sees the Business student only', 'SELECT COUNT(*) FROM CS5322_P1.student', 1);
    CS5322_P1.cs5322_test.expect_count('admin_bus sees the Business course only', 'SELECT COUNT(*) FROM CS5322_P1.course', 1);
    CS5322_P1.cs5322_test.expect_count('admin_bus sees the grade of that course only', 'SELECT COUNT(*) FROM CS5322_P1.grade', 1);
    CS5322_P1.cs5322_test.summary('admin_bus');
END;
/

PROMPT === finance1 (finance officer) ===
CONNECT finance1/"Finance#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('finance1');
    CS5322_P1.cs5322_test.expect_count('finance sees all 3 payments', 'SELECT COUNT(*) FROM CS5322_P1.payment', 3);
    CS5322_P1.cs5322_test.expect_count('finance sees all 3 students', 'SELECT COUNT(student_name) FROM CS5322_P1.student', 3);
    CS5322_P1.cs5322_test.expect_count('finance sees no e-mail address (column masking)', 'SELECT COUNT(email) FROM CS5322_P1.student', 0);
    CS5322_P1.cs5322_test.expect_error('finance has no grant on GRADE', 'SELECT COUNT(*) FROM CS5322_P1.grade', -942);
    CS5322_P1.cs5322_test.expect_error('finance has no grant on ENROLLMENT', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', -942);
    CS5322_P1.cs5322_test.expect_error('finance has no grant on ROOM_ALLOCATION', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', -942);
    CS5322_P1.cs5322_test.summary('finance1');
END;
/

PROMPT === housing1 (housing officer) ===
CONNECT housing1/"Housing#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('housing1');
    CS5322_P1.cs5322_test.expect_count('housing sees both residences', 'SELECT COUNT(*) FROM CS5322_P1.residence', 2);
    CS5322_P1.cs5322_test.expect_count('housing sees all 5 rooms', 'SELECT COUNT(*) FROM CS5322_P1.residence_room', 5);
    CS5322_P1.cs5322_test.expect_count('housing sees all 6 allocations (history included)', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', 6);
    CS5322_P1.cs5322_test.expect_count('housing sees the 3 fellowship records', 'SELECT COUNT(*) FROM CS5322_P1.resident_fellow', 3);
    CS5322_P1.cs5322_test.expect_count('housing sees the 3 students that have an allocation', 'SELECT COUNT(*) FROM CS5322_P1.student', 3);
    CS5322_P1.cs5322_test.expect_error('housing has no grant on PAYMENT', 'SELECT COUNT(*) FROM CS5322_P1.payment', -942);
    CS5322_P1.cs5322_test.expect_error('housing has no grant on GRADE', 'SELECT COUNT(*) FROM CS5322_P1.grade', -942);
    CS5322_P1.cs5322_test.summary('housing1');
END;
/

PROMPT === uni_admin (university administrator) ===
CONNECT uni_admin/"Uni#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('uni_admin');
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 3 students', 'SELECT COUNT(*) FROM CS5322_P1.student', 3);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 2 professors', 'SELECT COUNT(*) FROM CS5322_P1.professor', 2);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 4 courses', 'SELECT COUNT(*) FROM CS5322_P1.course', 4);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 5 sections', 'SELECT COUNT(*) FROM CS5322_P1.section', 5);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 5 enrollments', 'SELECT COUNT(*) FROM CS5322_P1.enrollment', 5);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 4 grades, drafts included', 'SELECT COUNT(*) FROM CS5322_P1.grade', 4);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 3 payments', 'SELECT COUNT(*) FROM CS5322_P1.payment', 3);
    CS5322_P1.cs5322_test.expect_count('uni_admin sees all 6 allocations', 'SELECT COUNT(*) FROM CS5322_P1.room_allocation', 6);
    CS5322_P1.cs5322_test.expect_count('uni_admin reads the audit trail (empty after the tests)', 'SELECT COUNT(*) FROM CS5322_P1.grade_audit', 0);
    CS5322_P1.cs5322_test.expect_error('even uni_admin has no grant on APP_USER', 'SELECT COUNT(*) FROM CS5322_P1.app_user', -942);
    CS5322_P1.cs5322_test.summary('uni_admin');
END;
/
