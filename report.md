# CS5322 Database Security Project I
## Virtual Private Database for a University Information System

## 1. Introduction

This project implements Oracle Virtual Private Database (VPD) for a university information
system. The system stores students, professors, departments, course catalogues, course sections,
enrolments, grades, payments and student housing. The same database is shared by several categories of users, so table-level grants
alone are insufficient: different users must see different rows of the same table.

## 2. Application and Users

The application supports six roles: students, professors, department administrators, finance
officers, housing officers and university administrators. A student views personal academic,
payment and housing-allocation records.
A professor views sections assigned to that professor and the associated enrolments and grades. A
department administrator manages records belonging to that department. A finance officer sees
payment records but not academic grades. A university administrator has institution-wide access.

## 3. Database Design

The schema contains DEPARTMENT, APP_USER, STUDENT, PROFESSOR, COURSE, SECTION, ENROLLMENT, GRADE,
PAYMENT, RESIDENCE, RESIDENCE_ROOM and ROOM_ALLOCATION. APP_USER maps the authenticated application
username to a role and department.
COURSE is the catalogue-level definition, identified by its code and owned by a department. It
does not contain a professor or semester because a course can be offered repeatedly and taught by
different professors. SECTION represents one concrete offering of a course and stores the course,
assigned professor, semester, academic year, room and capacity. ENROLLMENT references a student
and a section, rather than a course, and records enrolment status and time. GRADE references an
enrolment; PAYMENT references a student. The supplied script creates three departments, three
students, two professors, four courses, five sections, four enrolments, four grades and three
payments. In particular, CS5322 has an S1 2026 section taught by Professor Lee and an S2 2026
section taught by Professor Wong.

The housing domain models residences containing rooms. ROOM_ALLOCATION assigns a room to either a
student or a professor acting as a resident fellow; a check constraint requires exactly one
occupant type. An active resident-fellow allocation is also the trusted basis for determining the
residence whose allocations that fellow may view.

## 4. Security Requirements

The important requirements are:

1. Students can read only their own student, enrolment, grade and payment rows, and only the
   sections in which they are enrolled.
2. Professors can read their assigned sections and can read and update grades only for enrolments
   in those sections.
3. Department administrators can manage courses, sections and associated academic records within
   their own department.
4. Finance officers can read all payments but cannot read grades.
5. Housing officers can view all residences, rooms and allocations.
6. Students can view only their own allocation and its associated room/residence.
7. A resident fellow can view every allocation for rooms in the residence where the fellow has an
   active allocation, but cannot view another residence's allocations.
8. University administrators can read all project data.
9. A missing or invalid application identity must return no protected rows.
10. The policy must apply to SELECT, INSERT, UPDATE and DELETE so that write operations cannot
   bypass row filtering.

## 5. VPD Design

The trusted application calls `CS5322_SECURITY_CTX.SET_USER` after authentication. The package stores
the application username, user ID, role and department ID in `CS5322_APP_CTX`. Policy functions
read this trusted session context and return a SQL predicate. For example, the student policy
returns `user_id = current_user_id`; the department policy returns `department_id = current_department_id`.
Professor access is derived through the `SECTION.professor_id` relationship. Student course
visibility is derived through `ENROLLMENT -> SECTION -> COURSE`, so a student sees catalogue
information only for enrolled offerings. Grade access is derived through `GRADE -> ENROLLMENT ->
SECTION`, preventing a professor from seeing another professor's grades even where both teach the
same course in different terms. Department administrator scope is derived through
`SECTION -> COURSE.department_id`, rather than from a user-supplied section value.

The policies are registered with `DBMS_RLS.ADD_POLICY` on STUDENT, COURSE, SECTION, ENROLLMENT,
GRADE and PAYMENT. The SECTION policy permits a professor only where the assigned
`professor_id` matches the session identity; it permits a student only where an enrolment exists.
The policy functions return `1=0` for roles that should not access a table.

Housing VPD policies are registered on RESIDENCE, RESIDENCE_ROOM and ROOM_ALLOCATION. Housing
officers receive unrestricted housing visibility. A student's predicate resolves that student's
record from the trusted context. A resident fellow's allocation predicate finds the residence of
the fellow's active allocation, then permits allocations for every room in that residence. This
scope is inferred from database relationships and is never accepted from an application parameter.

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
two enrolments, two enrolled sections, two grades and one payment. Bob sees only his own rows.
The Computing department administrator sees one student, two courses, three Computing sections
and two grades, while rows from other departments are hidden. Professor Lee sees two assigned
sections, their two distinct courses and their related grades. Finance sees three payments and
zero grades. The university administrator sees all three students, four grades and three
payments. Housing verification expects Alice to see one allocation, Professor Lee to see all
three allocations in Kent Ridge Hall where he lives as resident fellow, and the housing officer
to see all five allocations.

The tests also cover the absence of a valid role by making policy functions return `1=0`. The
policy is attached to write operations as well as reads, so an attacker cannot update or delete
rows outside the permitted predicate. In a production system, the context-setting package
checks that the database session user matches the requested application username, preventing a
normal user from impersonating another user. The schema-owner/DBA exception is used only for the
repeatable classroom tests.

The revised verification script expects nine enabled policies, including `SECTION_VPD` and the
three housing policies. After the
schema is rebuilt, it should confirm that Alice sees one student, two grades and two enrolled
sections; Professor Lee sees two assigned sections, two courses and two grades; Finance sees
three payments but has no grade privilege; and University Admin sees three students and four
grades.

## 8. Demonstration Plan

The demonstration runs `demo.sql`. First Alice is selected and her two grades and enrolled
sections are displayed. The context is changed to Bob and the result changes to Bob's single
grade and section. The Computing admin then sees only Computing courses and their sections.
Professor Lee's result demonstrates that assignment is made at section level rather than course
level. Finance sees payments but no grades. Finally, the university administrator sees
institution-wide counts. Each output is compared with the expected row-count matrix in
`04_tests.sql`.

## 9. Limitations and Future Work

The dummy project uses a small dataset and simulated application authentication. A deployed
system should use a secure login service, audit context changes, protect sensitive payment data
with encryption or tokenisation, enforce capacity and valid status transitions through controlled
enrolment procedures, and add automated regression tests for every policy and write operation.

## 10. Conclusion

The project demonstrates that Oracle VPD can enforce different row-level views over shared tables.
The combination of ordinary roles and VPD predicates implements nontrivial policies for personal,
departmental, section-based, housing-specific and finance-specific access while keeping the database schema shared.
