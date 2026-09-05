-- Re-apply object privileges after tables are recreated.
-- Run as SYSDBA against FREEPDB1.
GRANT SELECT ON CS5322_P1.student TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.course TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.enrollment TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.grade TO cs5322_student_role;
GRANT SELECT, INSERT, UPDATE ON CS5322_P1.grade TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.professor TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.course TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.enrollment TO cs5322_professor_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.student TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.course TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.enrollment TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.grade TO cs5322_dept_admin_role;
GRANT SELECT ON CS5322_P1.payment TO cs5322_finance_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_finance_role;
GRANT SELECT ON CS5322_P1.department TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.professor TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.course TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.enrollment TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.grade TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.payment TO cs5322_university_admin_role;
EXIT;

