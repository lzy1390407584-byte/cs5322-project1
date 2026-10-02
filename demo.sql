-- Live demonstration script (about 10 minutes).  Every part logs in as a REAL database user,
-- so object privileges and VPD act together.  Run on the VM:   sqlplus /nolog @demo.sql
-- Statements are echoed like an interactive session (use sqlplus without -s, which
-- silences the echo).  The data is restored at the end: the audit demo commits one grade
-- change and the last step reverts it.  Type EXIT when it has finished.
DEFINE svc = "localhost:1521/cs5322"
SET VERIFY OFF
SET FEEDBACK ON
SET LINESIZE 160
SET PAGESIZE 60
COLUMN student_name FORMAT A14
COLUMN email FORMAT A18
COLUMN grade_value HEADING 'GRADE' FORMAT A5
COLUMN released FORMAT A8
COLUMN allocation_status FORMAT A17
COLUMN course_title FORMAT A22
COLUMN professor_name FORMAT A16
COLUMN residence_name FORMAT A32
COLUMN db_user FORMAT A10
COLUMN action HEADING 'ACT' FORMAT A3
COLUMN old_grade_value HEADING 'OLD' FORMAT A3
COLUMN new_grade_value HEADING 'NEW' FORMAT A3

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 1. Alice, a student: the same tables, but only her own rows
PROMPT ======================================================================
CONNECT alice/"Alice#5322"@&svc
SET ECHO ON
REM Before an identity is activated the policies fail closed:
SELECT COUNT(*) AS students_visible FROM CS5322_P1.student;
REM The application activates alice's identity (it can only activate her own):
EXEC CS5322_P1.cs5322_security_ctx.set_user('alice')
SELECT student_id, student_name, email FROM CS5322_P1.student;
SELECT section_id, course_id, professor_id, semester FROM CS5322_P1.section;
REM She has 2 enrollments but sees only the released grade; the other one is still a draft:
SELECT enrollment_id, section_id FROM CS5322_P1.enrollment;
SELECT grade_id, enrollment_id, grade_value, released FROM CS5322_P1.grade;
SELECT payment_id, amount, payment_status FROM CS5322_P1.payment;
SELECT room_id, room_number FROM CS5322_P1.residence_room;
REM She cannot become somebody else, and she cannot write:
EXEC CS5322_P1.cs5322_security_ctx.set_user('bob')
UPDATE CS5322_P1.grade SET grade_value = 'A+' WHERE grade_id = 90001;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 2. Professor Lee: his own sections, the draft-grade workflow, and the
PROMPT    residents of the residence he looks after as fellow
PROMPT ======================================================================
CONNECT prof_lee/"Lee#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('prof_lee')
SELECT section_id, course_id, semester FROM CS5322_P1.section;
REM Class list (Alice) plus the residents of Kent Ridge Hall (Carol lives there, Bob does not):
SELECT student_id, student_name, email FROM CS5322_P1.student;
REM He sees the draft grade as well:
SELECT grade_id, enrollment_id, grade_value, released FROM CS5322_P1.grade;
REM He may edit a draft of his own section ...
UPDATE CS5322_P1.grade SET grade_value = 'B+' WHERE grade_id = 90004;
ROLLBACK;
REM ... but not a released grade, nor publish one himself, nor grade another professor's student:
UPDATE CS5322_P1.grade SET grade_value = 'A+' WHERE grade_id = 90001;
UPDATE CS5322_P1.grade SET released = 'Y' WHERE grade_id = 90004;
INSERT INTO CS5322_P1.grade (grade_id, enrollment_id, grade_value, last_updated_by) VALUES (90099, 10005, 'A', 2001);
ROLLBACK;
REM As resident fellow he sees the active allocations of his residence only:
SELECT residence_id, residence_name FROM CS5322_P1.residence;
SELECT allocation_id, room_id, student_id, professor_id, allocation_status FROM CS5322_P1.room_allocation;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 3. Professor Wong: another fellow, another residence
PROMPT ======================================================================
CONNECT prof_wong/"Wong#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('prof_wong')
REM CS5322 is offered twice: Wong teaches the S2 section and sees its enrollment:
SELECT section_id, course_id, semester FROM CS5322_P1.section;
SELECT residence_id, residence_name FROM CS5322_P1.residence;
SELECT allocation_id, room_id, student_id, professor_id, allocation_status FROM CS5322_P1.room_allocation;
REM His past fellowship of Kent Ridge Hall has ended and grants nothing:
SELECT professor_id, residence_id, status FROM CS5322_P1.resident_fellow;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 4. Computing department administrator: own department, publishes grades
PROMPT ======================================================================
CONNECT admin_comp/"Comp#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('admin_comp')
SELECT course_id, department_id, course_code FROM CS5322_P1.course;
SELECT student_id, department_id, student_name FROM CS5322_P1.student;
SELECT grade_id, enrollment_id, grade_value, released FROM CS5322_P1.grade;
REM Publishing the draft (rolled back here):
UPDATE CS5322_P1.grade SET released = 'Y' WHERE grade_id = 90004;
ROLLBACK;
REM Another department's data is out of reach:
INSERT INTO CS5322_P1.course VALUES (202, 20, 'BIZ2002', 'Marketing');
UPDATE CS5322_P1.student SET department_id = 20 WHERE student_id = 1;
UPDATE CS5322_P1.student SET student_name = 'Robert Lim' WHERE student_id = 2;
SELECT COUNT(*) FROM CS5322_P1.payment;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 5. Finance: all payments, student names but no e-mail, never grades
PROMPT ======================================================================
CONNECT finance1/"Finance#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('finance1')
REM Column-level VPD: the rows are visible, the e-mail column is masked:
SELECT student_id, student_name, email FROM CS5322_P1.student;
SELECT payment_id, student_id, amount, payment_status FROM CS5322_P1.payment;
UPDATE CS5322_P1.payment SET payment_status = 'PAID' WHERE payment_id = 70002;
ROLLBACK;
SELECT COUNT(*) FROM CS5322_P1.grade;
DELETE FROM CS5322_P1.payment WHERE payment_id = 70001;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 6. Housing officer: all allocations, no academic or payment data
PROMPT ======================================================================
CONNECT housing1/"Housing#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('housing1')
SELECT allocation_id, room_id, student_id, professor_id, allocation_status FROM CS5322_P1.room_allocation;
SELECT COUNT(*) FROM CS5322_P1.payment;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT 7. Audit trail: a grade change is recorded with the application identity
PROMPT ======================================================================
CONNECT prof_lee/"Lee#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('prof_lee')
REM Lee tries to forge the editor of the grade; the trigger overwrites it:
UPDATE CS5322_P1.grade SET grade_value = 'B+', last_updated_by = 2002 WHERE grade_id = 90004;
SELECT grade_id, grade_value, last_updated_by FROM CS5322_P1.grade WHERE grade_id = 90004;
COMMIT;
SET ECHO OFF
CONNECT uni_admin/"Uni#5322"@&svc
SET ECHO ON
EXEC CS5322_P1.cs5322_security_ctx.set_user('uni_admin')
REM The university administrator oversees everything, read-only, including the audit trail:
SELECT COUNT(*) AS students FROM CS5322_P1.student;
SELECT COUNT(*) AS grades FROM CS5322_P1.grade;
SELECT audit_id, grade_id, action, old_grade_value, new_grade_value, actor_user_id, db_user FROM CS5322_P1.grade_audit;
UPDATE CS5322_P1.grade SET grade_value = 'A' WHERE grade_id = 90001;

SET ECHO OFF
PROMPT
PROMPT ======================================================================
PROMPT Restoring the demo data (grade 90004 back to B, audit trail emptied)
PROMPT ======================================================================
CONNECT CS5322_P1/"CS5322#2026"@&svc
SET FEEDBACK OFF
EXEC cs5322_security_ctx.set_user('prof_lee')
UPDATE grade SET grade_value = 'B' WHERE grade_id = 90004;
DELETE FROM grade_audit;
COMMIT;
EXEC cs5322_security_ctx.clear_user
SET FEEDBACK ON
PROMPT Done.
