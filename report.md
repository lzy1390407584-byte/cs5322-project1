# CS5322 Database Security Project I
## Virtual Private Database for a University Information System

## 1. Introduction

This project implements Oracle Virtual Private Database (VPD) for a university information
system. The system stores students, professors, departments, courses, enrolments, grades and
payments. The same database is shared by several categories of users, so table-level grants
alone are insufficient: different users must see different rows of the same table.

## 2. Application and Users

The application supports five roles: students, professors, department administrators, finance
officers and university administrators. A student views personal academic and payment records.
A professor views courses taught by that professor and the associated enrolments and grades. A
department administrator manages records belonging to that department. A finance officer sees
payment records but not academic grades. A university administrator has institution-wide access.

## 3. Database Design

The schema contains DEPARTMENT, APP_USER, STUDENT, PROFESSOR, COURSE, ENROLLMENT, GRADE and
PAYMENT. APP_USER maps the authenticated application username to a role and department. Foreign
keys connect courses to professors, enrolments to students and courses, grades to enrolments,
and payments to students. The supplied script creates three departments, three students, two
professors, four courses, four enrolments, four grades and three payments.

## 4. Security Requirements

The important requirements are:

1. Students can read only their own student, enrolment, grade and payment rows.
2. Professors can read and update grades for enrolments in their own courses.
3. Department administrators can manage academic records within their own department.
4. Finance officers can read all payments but cannot read grades.
5. University administrators can read all project data.
6. A missing or invalid application identity must return no protected rows.
7. The policy must apply to SELECT, INSERT, UPDATE and DELETE so that write operations cannot
   bypass row filtering.

## 5. VPD Design

The trusted application calls `CS5322_SECURITY_CTX.SET_USER` after authentication. The package stores
the application username, user ID, role and department ID in `CS5322_APP_CTX`. Policy functions
read this trusted session context and return a SQL predicate. For example, the student policy
returns `user_id = current_user_id`; the department policy returns `department_id = current_department_id`.
Professor access is derived through the professor and course relationships. Grade access is
derived through enrolment and course relationships, preventing a professor from seeing another
professor's grades.

The policies are registered with `DBMS_RLS.ADD_POLICY` on STUDENT, COURSE, ENROLLMENT, GRADE and
PAYMENT. The policy functions return `1=0` for roles that should not access a table.

## 6. Implementation

The implementation is divided into schema/data, roles/grants and VPD policy scripts. This makes
the setup reproducible. The context package is executable by application users, while the
policy definitions require administrative privileges. Object privileges provide coarse-grained
access and VPD provides fine-grained row-level filtering.

After a table reset, Oracle removes grants on the old table objects. Therefore the reproducible
deployment includes `02_regrant_object_privileges.sql` for the reset-and-rebuild workflow. The
VPD policy script is intentionally executed as `CS5322_P1`, so policy functions and policies are
owned by the same schema.

## 7. Testing and Evaluation

The test script checks positive access and attempted cross-user access. Alice sees one student,
two enrolments, two grades and one payment. Bob sees only his own rows. The Computing department
administrator sees one student, two courses and two grades, while rows from other departments
are hidden. Professor Lee sees his two courses and their related grades. Finance sees three
payments and zero grades. The university administrator sees all three students, four grades and
three payments.

The tests also cover the absence of a valid role by making policy functions return `1=0`. The
policy is attached to write operations as well as reads, so an attacker cannot update or delete
rows outside the permitted predicate. In a production system, the context-setting package
checks that the database session user matches the requested application username, preventing a
normal user from impersonating another user. The schema-owner/DBA exception is used only for the
repeatable classroom tests.

The final WSL run produced five enabled policies and all automated verification checks passed.
An additional real-user smoke test confirmed that Alice can see one student and two grades,
Professor Lee can see two courses and two grades, Finance can see three payments but has no grade
privilege, and University Admin can see three students and four grades.

## 8. Demonstration Plan

The demonstration runs `demo.sql`. First Alice is selected and her two grades are displayed.
The context is changed to Bob and the result changes to Bob's single grade. The Computing admin
then sees only Computing rows. Finance sees payments but no grades. Finally, the university
administrator sees institution-wide counts. Each output is compared with the expected row-count
matrix in `04_tests.sql`.

## 9. Limitations and Future Work

The dummy project uses a small dataset and simulated application authentication. A deployed
system should use a secure login service, audit context changes, protect sensitive payment data
with encryption or tokenisation, and add automated regression tests for every policy and write
operation.

## 10. Conclusion

The project demonstrates that Oracle VPD can enforce different row-level views over shared tables.
The combination of ordinary roles and VPD predicates implements nontrivial policies for personal,
departmental, course-based and finance-specific access while keeping the database schema shared.
