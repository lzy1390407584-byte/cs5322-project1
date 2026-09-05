-- VPD test matrix. Run as schema owner/DBA in SQL*Plus or SQLcl.
SET SERVEROUTPUT ON;

PROMPT === Alice: only her student, enrolment, grade and payment ===
EXEC cs5322_security_ctx.set_user('alice');
SELECT student_id, student_name FROM student ORDER BY student_id;
SELECT enrollment_id, student_id FROM enrollment ORDER BY enrollment_id;
SELECT grade_id, enrollment_id, grade_value FROM grade ORDER BY grade_id;
SELECT payment_id, student_id, amount FROM payment ORDER BY payment_id;

PROMPT === Bob: only Bob's rows ===
EXEC cs5322_security_ctx.set_user('bob');
SELECT student_id, student_name FROM student ORDER BY student_id;
SELECT grade_id, enrollment_id, grade_value FROM grade ORDER BY grade_id;

PROMPT === Computing department admin: Computing rows, not Business/Medicine ===
EXEC cs5322_security_ctx.set_user('admin_comp');
SELECT student_id, department_id, student_name FROM student ORDER BY student_id;
SELECT course_id, department_id, course_code FROM course ORDER BY course_id;
SELECT grade_id, enrollment_id, grade_value FROM grade ORDER BY grade_id;

PROMPT === Professor Lee: only Lee's courses and their enrolments/grades ===
EXEC cs5322_security_ctx.set_user('prof_lee');
SELECT course_id, course_code FROM course ORDER BY course_id;
SELECT enrollment_id, course_id FROM enrollment ORDER BY enrollment_id;
SELECT grade_id, enrollment_id, grade_value FROM grade ORDER BY grade_id;

PROMPT === Finance: all payments, no student grades ===
EXEC cs5322_security_ctx.set_user('finance1');
SELECT payment_id, student_id, amount FROM payment ORDER BY payment_id;
SELECT COUNT(*) AS visible_grades_to_finance FROM grade;

PROMPT === University admin: all rows ===
EXEC cs5322_security_ctx.set_user('uni_admin');
SELECT COUNT(*) AS students_visible FROM student;
SELECT COUNT(*) AS grades_visible FROM grade;
SELECT COUNT(*) AS payments_visible FROM payment;

PROMPT === Expected row counts ===
PROMPT Alice: student=1, enrollment=2, grade=2, payment=1
PROMPT Bob: student=1, grade=1
PROMPT Computing admin: students=1, courses=2, grades=2
PROMPT Professor Lee: courses=2, enrollments=2, grades=2
PROMPT Finance: payments=3, grades=0
PROMPT University admin: students=3, grades=4, payments=3

