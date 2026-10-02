-- Object privileges for the six application roles (single source of truth).
-- Run as SYSDBA against CS5322 after 01_schema_and_data.sql. Oracle drops object
-- grants when their table is dropped, so re-run this after every rebuild.
-- Privileges are the coarse layer; the VPD policies in 03 are the row-level layer.
ALTER SESSION SET CONTAINER = CS5322;

-- Students: read-only access to their own records (rows limited by VPD).
GRANT SELECT ON CS5322_P1.department TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.professor TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.course TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.section TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.enrollment TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.grade TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.payment TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.residence TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.residence_room TO cs5322_student_role;
GRANT SELECT ON CS5322_P1.room_allocation TO cs5322_student_role;

-- Professors: read their classes; enter and edit draft grades (INSERT/UPDATE, no DELETE).
GRANT SELECT ON CS5322_P1.department TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.professor TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.course TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.section TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.enrollment TO cs5322_professor_role;
GRANT SELECT, INSERT, UPDATE ON CS5322_P1.grade TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.residence TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.residence_room TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.room_allocation TO cs5322_professor_role;
GRANT SELECT ON CS5322_P1.resident_fellow TO cs5322_professor_role;

-- Department administrators: manage academic records of their own department.
GRANT SELECT ON CS5322_P1.department TO cs5322_dept_admin_role;
GRANT SELECT ON CS5322_P1.professor TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.student TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.course TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.section TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.enrollment TO cs5322_dept_admin_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON CS5322_P1.grade TO cs5322_dept_admin_role;

-- Finance: processes payments (no DELETE); sees students but never grades.
GRANT SELECT ON CS5322_P1.department TO cs5322_finance_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_finance_role;
GRANT SELECT, INSERT, UPDATE ON CS5322_P1.payment TO cs5322_finance_role;

-- Housing officers: allocate rooms; never see academic or payment data.
GRANT SELECT ON CS5322_P1.department TO cs5322_housing_officer_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_housing_officer_role;
GRANT SELECT ON CS5322_P1.residence TO cs5322_housing_officer_role;
GRANT SELECT ON CS5322_P1.residence_room TO cs5322_housing_officer_role;
GRANT SELECT, INSERT, UPDATE ON CS5322_P1.room_allocation TO cs5322_housing_officer_role;
GRANT SELECT ON CS5322_P1.resident_fellow TO cs5322_housing_officer_role;

-- University administrators: read-only oversight of everything, including the audit trail.
GRANT SELECT ON CS5322_P1.department TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.student TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.professor TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.course TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.section TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.enrollment TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.grade TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.payment TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.residence TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.residence_room TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.room_allocation TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.resident_fellow TO cs5322_university_admin_role;
GRANT SELECT ON CS5322_P1.grade_audit TO cs5322_university_admin_role;
