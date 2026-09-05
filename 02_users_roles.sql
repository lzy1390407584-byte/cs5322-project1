-- Run as DBA. Change CS5322_P1 if your schema has another name.

CREATE USER alice IDENTIFIED BY "Alice#5322";
CREATE USER bob IDENTIFIED BY "Bob#5322";
CREATE USER carol IDENTIFIED BY "Carol#5322";
CREATE USER prof_lee IDENTIFIED BY "Lee#5322";
CREATE USER prof_wong IDENTIFIED BY "Wong#5322";
CREATE USER admin_comp IDENTIFIED BY "Comp#5322";
CREATE USER admin_bus IDENTIFIED BY "Bus#5322";
CREATE USER finance1 IDENTIFIED BY "Finance#5322";
CREATE USER uni_admin IDENTIFIED BY "Uni#5322";

CREATE ROLE cs5322_student_role;
CREATE ROLE cs5322_professor_role;
CREATE ROLE cs5322_dept_admin_role;
CREATE ROLE cs5322_finance_role;
CREATE ROLE cs5322_university_admin_role;

GRANT CREATE SESSION TO alice, bob, carol, prof_lee, prof_wong, admin_comp, admin_bus, finance1, uni_admin;
GRANT cs5322_student_role TO alice, bob, carol;
GRANT cs5322_professor_role TO prof_lee, prof_wong;
GRANT cs5322_dept_admin_role TO admin_comp, admin_bus;
GRANT cs5322_finance_role TO finance1;
GRANT cs5322_university_admin_role TO uni_admin;

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

-- Demo-only passwords. Change them in a real environment.
ALTER USER alice IDENTIFIED BY "Alice#5322";
ALTER USER bob IDENTIFIED BY "Bob#5322";
ALTER USER carol IDENTIFIED BY "Carol#5322";
ALTER USER prof_lee IDENTIFIED BY "Lee#5322";
ALTER USER prof_wong IDENTIFIED BY "Wong#5322";
ALTER USER admin_comp IDENTIFIED BY "Comp#5322";
ALTER USER admin_bus IDENTIFIED BY "Bus#5322";
ALTER USER finance1 IDENTIFIED BY "Finance#5322";
ALTER USER uni_admin IDENTIFIED BY "Uni#5322";
