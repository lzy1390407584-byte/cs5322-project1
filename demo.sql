-- Five-minute demonstration script. Run as schema owner/DBA.
SET SERVEROUTPUT ON;
PROMPT 1. Alice logs in through the application context.
EXEC cs5322_security_ctx.set_user('alice');
SELECT student_id, student_name FROM student;
SELECT grade_id, enrollment_id, grade_value FROM grade;

PROMPT 2. Change only the application identity to Bob.
EXEC cs5322_security_ctx.set_user('bob');
SELECT student_id, student_name FROM student;
SELECT grade_id, enrollment_id, grade_value FROM grade;

PROMPT 3. Department admin sees only Computing rows.
EXEC cs5322_security_ctx.set_user('admin_comp');
SELECT student_id, department_id, student_name FROM student;

PROMPT 4. Finance sees payments but no grades.
EXEC cs5322_security_ctx.set_user('finance1');
SELECT payment_id, student_id, amount FROM payment;
SELECT COUNT(*) AS grades_visible_to_finance FROM grade;

PROMPT 5. University administrator sees all rows.
EXEC cs5322_security_ctx.set_user('uni_admin');
SELECT COUNT(*) AS all_students FROM student;
SELECT COUNT(*) AS all_grades FROM grade;
SELECT COUNT(*) AS all_payments FROM payment;

