-- WRITE-path checks with real database logins.  Every statement runs with the caller's own
-- object privileges AND the VPD write policies, and is rolled back afterwards.
--   ORA-01031 / ORA-41900 / ORA-00942 : refused by the privilege layer (no grant; Oracle
--                           23ai reports a missing DML privilege as ORA-41900)
--   0 rows                : the row is outside what the write policy lets the caller touch
--   ORA-28115             : the new row would violate the policy (check option)
-- Run from the VM (type EXIT afterwards):  sqlplus /nolog @08_write_tests.sql
DEFINE svc = "localhost:1521/cs5322"
SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 200

PROMPT === alice (student): read-only role ===
CONNECT alice/"Alice#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('alice');
    CS5322_P1.cs5322_test.expect_denied('alice cannot update a grade', q'[UPDATE CS5322_P1.grade SET grade_value = 'A+' WHERE grade_id = 90001]');
    CS5322_P1.cs5322_test.expect_denied('alice cannot delete an enrollment', q'[DELETE FROM CS5322_P1.enrollment WHERE enrollment_id = 10001]');
    CS5322_P1.cs5322_test.expect_denied('alice cannot insert a payment', q'[INSERT INTO CS5322_P1.payment VALUES (70099, 1, 1.00, 'PAID', SYSDATE)]');
    CS5322_P1.cs5322_test.expect_denied('alice cannot change her profile', q'[UPDATE CS5322_P1.student SET email = 'x@example.com' WHERE student_id = 1]');
    CS5322_P1.cs5322_test.expect_denied('alice cannot change a room allocation', q'[UPDATE CS5322_P1.room_allocation SET allocation_status = 'ENDED' WHERE allocation_id = 60001]');
    CS5322_P1.cs5322_test.summary('alice (writes)');
END;
/

PROMPT === prof_lee (professor): drafts of his own sections only ===
CONNECT prof_lee/"Lee#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    -- No application identity yet: the write policies fail closed even though the grants exist.
    CS5322_P1.cs5322_test.expect_rows('without identity prof_lee updates 0 grades', q'[UPDATE CS5322_P1.grade SET grade_value = 'B+' WHERE grade_id = 90004]', 0);
    CS5322_P1.cs5322_test.expect_error('without identity prof_lee cannot insert a grade', q'[INSERT INTO CS5322_P1.grade (grade_id, enrollment_id, grade_value, last_updated_by) VALUES (90099, 10005, 'A', 2001)]', -28115);
    CS5322_P1.cs5322_security_ctx.set_user('prof_lee');
    CS5322_P1.cs5322_test.expect_rows('prof_lee edits the draft grade of his own section', q'[UPDATE CS5322_P1.grade SET grade_value = 'B+' WHERE grade_id = 90004]', 1);
    CS5322_P1.cs5322_test.expect_rows('prof_lee cannot change a released grade', q'[UPDATE CS5322_P1.grade SET grade_value = 'A+' WHERE grade_id = 90001]', 0);
    CS5322_P1.cs5322_test.expect_error('prof_lee cannot publish a grade himself', q'[UPDATE CS5322_P1.grade SET released = 'Y' WHERE grade_id = 90004]', -28115);
    CS5322_P1.cs5322_test.expect_rows('prof_lee cannot touch the grade of another professor''s section', q'[UPDATE CS5322_P1.grade SET grade_value = 'A' WHERE grade_id = 90002]', 0);
    CS5322_P1.cs5322_test.expect_error('prof_lee cannot grade a student of another professor', q'[INSERT INTO CS5322_P1.grade (grade_id, enrollment_id, grade_value, last_updated_by) VALUES (90099, 10005, 'A', 2001)]', -28115);
    CS5322_P1.cs5322_test.expect_error('prof_lee cannot move his draft grade to another professor''s student', q'[UPDATE CS5322_P1.grade SET enrollment_id = 10005 WHERE grade_id = 90004]', -28115);
    CS5322_P1.cs5322_test.expect_value('prof_lee cannot spoof the recorded editor', q'[UPDATE CS5322_P1.grade SET grade_value = 'B+', last_updated_by = 2002 WHERE grade_id = 90004]', 'SELECT last_updated_by FROM CS5322_P1.grade WHERE grade_id = 90004', 2001);
    CS5322_P1.cs5322_test.expect_denied('prof_lee has no DELETE privilege on grades', q'[DELETE FROM CS5322_P1.grade WHERE grade_id = 90004]');
    CS5322_P1.cs5322_test.expect_denied('prof_lee cannot create a course', q'[INSERT INTO CS5322_P1.course VALUES (103, 10, 'CS3235', 'Computer Security')]');
    CS5322_P1.cs5322_test.expect_denied('prof_lee cannot change a section', q'[UPDATE CS5322_P1.section SET capacity = 99 WHERE section_id = 1001]');
    CS5322_P1.cs5322_test.expect_denied('a fellow cannot allocate rooms', q'[INSERT INTO CS5322_P1.room_allocation (allocation_id, room_id, student_id, allocation_status) VALUES (60099, 101, 2, 'PENDING')]');
    CS5322_P1.cs5322_test.summary('prof_lee (writes)');
END;
/

PROMPT === prof_wong (professor): grading a student of his own section ===
CONNECT prof_wong/"Wong#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('prof_wong');
    CS5322_P1.cs5322_test.expect_rows('prof_wong enters a draft grade for his CS5322 S2 student', q'[INSERT INTO CS5322_P1.grade (grade_id, enrollment_id, grade_value, last_updated_by) VALUES (90099, 10005, 'A-', 2002)]', 1);
    CS5322_P1.cs5322_test.expect_error('prof_wong cannot insert an already released grade', q'[INSERT INTO CS5322_P1.grade (grade_id, enrollment_id, grade_value, released, last_updated_by) VALUES (90099, 10005, 'A-', 'Y', 2002)]', -28115);
    CS5322_P1.cs5322_test.expect_rows('prof_wong cannot change the released grade of his Business student', q'[UPDATE CS5322_P1.grade SET grade_value = 'A' WHERE grade_id = 90002]', 0);
    CS5322_P1.cs5322_test.summary('prof_wong (writes)');
END;
/

PROMPT === admin_comp (Computing administrator): own department, publishes and corrects grades ===
CONNECT admin_comp/"Comp#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('admin_comp');
    CS5322_P1.cs5322_test.expect_rows('admin_comp publishes the draft grade', q'[UPDATE CS5322_P1.grade SET released = 'Y' WHERE grade_id = 90004]', 1);
    CS5322_P1.cs5322_test.expect_rows('admin_comp corrects a released grade of the department', q'[UPDATE CS5322_P1.grade SET grade_value = 'A+' WHERE grade_id = 90001]', 1);
    CS5322_P1.cs5322_test.expect_rows('admin_comp cannot touch a Business grade', q'[UPDATE CS5322_P1.grade SET grade_value = 'A' WHERE grade_id = 90002]', 0);
    CS5322_P1.cs5322_test.expect_rows('a released grade cannot be deleted', q'[DELETE FROM CS5322_P1.grade WHERE grade_id = 90001]', 0);
    CS5322_P1.cs5322_test.expect_rows('a draft grade of the department can be deleted', q'[DELETE FROM CS5322_P1.grade WHERE grade_id = 90004]', 1);
    CS5322_P1.cs5322_test.expect_rows('admin_comp creates a Computing course', q'[INSERT INTO CS5322_P1.course VALUES (103, 10, 'CS3235', 'Computer Security')]', 1);
    CS5322_P1.cs5322_test.expect_error('admin_comp cannot create a Business course', q'[INSERT INTO CS5322_P1.course VALUES (202, 20, 'BIZ2002', 'Marketing')]', -28115);
    CS5322_P1.cs5322_test.expect_rows('admin_comp creates a section of a Computing course', q'[INSERT INTO CS5322_P1.section VALUES (1004, 101, 1, 'S2', 2026, 'COM1-02-14', 30)]', 1);
    CS5322_P1.cs5322_test.expect_error('admin_comp cannot create a section of a Business course', q'[INSERT INTO CS5322_P1.section VALUES (2002, 201, 2, 'S2', 2026, 'BIZ2-01-02', 30)]', -28115);
    CS5322_P1.cs5322_test.expect_error('admin_comp cannot move a student to another department', q'[UPDATE CS5322_P1.student SET department_id = 20 WHERE student_id = 1]', -28115);
    CS5322_P1.cs5322_test.expect_rows('admin_comp cannot edit a Business student', q'[UPDATE CS5322_P1.student SET student_name = 'Robert Lim' WHERE student_id = 2]', 0);
    CS5322_P1.cs5322_test.expect_rows('admin_comp edits a Computing student', q'[UPDATE CS5322_P1.student SET student_name = 'Alice T. Tan' WHERE student_id = 1]', 1);
    CS5322_P1.cs5322_test.expect_rows('admin_comp withdraws an enrollment in a Computing section', q'[DELETE FROM CS5322_P1.enrollment WHERE enrollment_id = 10005]', 1);
    CS5322_P1.cs5322_test.expect_rows('admin_comp cannot delete an enrollment of a Business section', q'[DELETE FROM CS5322_P1.enrollment WHERE enrollment_id = 10002]', 0);
    CS5322_P1.cs5322_test.expect_error('admin_comp has no privilege on PAYMENT', q'[UPDATE CS5322_P1.payment SET payment_status = 'PAID']', -942);
    CS5322_P1.cs5322_test.expect_denied('admin_comp cannot modify professors', q'[UPDATE CS5322_P1.professor SET professor_name = 'X' WHERE professor_id = 1]');
    CS5322_P1.cs5322_test.summary('admin_comp (writes)');
END;
/

PROMPT === admin_bus (Business administrator) ===
CONNECT admin_bus/"Bus#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('admin_bus');
    CS5322_P1.cs5322_test.expect_rows('admin_bus cannot touch a Computing grade', q'[UPDATE CS5322_P1.grade SET grade_value = 'A+' WHERE grade_id = 90001]', 0);
    CS5322_P1.cs5322_test.expect_rows('admin_bus corrects a Business grade', q'[UPDATE CS5322_P1.grade SET grade_value = 'A-' WHERE grade_id = 90002]', 1);
    CS5322_P1.cs5322_test.summary('admin_bus (writes)');
END;
/

PROMPT === finance1 (finance officer): payments only ===
CONNECT finance1/"Finance#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('finance1');
    CS5322_P1.cs5322_test.expect_rows('finance marks a pending payment as paid', q'[UPDATE CS5322_P1.payment SET payment_status = 'PAID' WHERE payment_id = 70002]', 1);
    CS5322_P1.cs5322_test.expect_rows('finance records a new payment', q'[INSERT INTO CS5322_P1.payment VALUES (70099, 1, 50.00, 'PENDING', SYSDATE)]', 1);
    CS5322_P1.cs5322_test.expect_denied('finance cannot delete payments', q'[DELETE FROM CS5322_P1.payment WHERE payment_id = 70001]');
    CS5322_P1.cs5322_test.expect_denied('finance cannot edit students', q'[UPDATE CS5322_P1.student SET student_name = 'X' WHERE student_id = 1]');
    CS5322_P1.cs5322_test.expect_error('finance has no privilege on GRADE', q'[UPDATE CS5322_P1.grade SET grade_value = 'A' WHERE grade_id = 90001]', -942);
    CS5322_P1.cs5322_test.summary('finance1 (writes)');
END;
/

PROMPT === housing1 (housing officer): allocations only ===
CONNECT housing1/"Housing#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('housing1');
    CS5322_P1.cs5322_test.expect_rows('housing creates a pending allocation', q'[INSERT INTO CS5322_P1.room_allocation (allocation_id, room_id, student_id, allocation_status) VALUES (60099, 201, 1, 'PENDING')]', 1);
    CS5322_P1.cs5322_test.expect_rows('housing ends an allocation', q'[UPDATE CS5322_P1.room_allocation SET allocation_status = 'ENDED' WHERE allocation_id = 60002]', 1);
    CS5322_P1.cs5322_test.expect_denied('housing cannot change room data', q'[UPDATE CS5322_P1.residence_room SET capacity = 2 WHERE room_id = 101]');
    CS5322_P1.cs5322_test.expect_denied('housing cannot edit students', q'[UPDATE CS5322_P1.student SET student_name = 'X' WHERE student_id = 1]');
    CS5322_P1.cs5322_test.expect_error('housing has no privilege on PAYMENT', q'[UPDATE CS5322_P1.payment SET payment_status = 'PAID']', -942);
    CS5322_P1.cs5322_test.summary('housing1 (writes)');
END;
/

PROMPT === uni_admin (university administrator): oversight is read-only ===
CONNECT uni_admin/"Uni#5322"@&svc
SET SERVEROUTPUT ON SIZE UNLIMITED
BEGIN
    CS5322_P1.cs5322_test.reset;
    CS5322_P1.cs5322_security_ctx.set_user('uni_admin');
    CS5322_P1.cs5322_test.expect_denied('uni_admin cannot update grades', q'[UPDATE CS5322_P1.grade SET grade_value = 'A' WHERE grade_id = 90001]');
    CS5322_P1.cs5322_test.expect_denied('uni_admin cannot delete students', q'[DELETE FROM CS5322_P1.student WHERE student_id = 1]');
    CS5322_P1.cs5322_test.expect_denied('nobody can forge audit records', q'[INSERT INTO CS5322_P1.grade_audit (grade_id, action, db_user) VALUES (90001, 'U', 'UNI_ADMIN')]');
    CS5322_P1.cs5322_test.summary('uni_admin (writes)');
END;
/
