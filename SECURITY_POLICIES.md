# Security policies for the revised academic schema

The policies below assume Oracle database accounts, role grants, the `login_name` mapping on `STUDENT` and `PROFESSOR`, and VPD predicates based on the trusted application context.  `app_user` is deliberately not used.

| ID | Object / operation | Policy |
|---|---|---|
| P1 | All protected tables | Deny by default. Grant only the smallest object privilege required, then enforce row scope with VPD. |
| P2 | Application context | Only the trusted context package sets identity attributes. A non-owner session may set context only for its own `SESSION_USER`. |
| P3 | Student profile | A student may read only their own record. They must not change `student_id`, `department_id`, or `login_name`; profile changes should be limited to approved contact fields. |
| P4 | Professor profile | A professor may read their own record; department administrators can manage records only in their department. |
| P5 | Department | Students and professors may read department reference data. Only university administration manages department master data. |
| P6 | Course | Students may see courses for sections in which they are enrolled (or the published catalogue, if that is a business requirement). Professors see courses for sections they teach. Department administrators manage only their department's courses. |
| P7 | Section | Students see their enrolled sections; professors see only sections assigned to them; department administrators manage sections only where both course and professor belong to their department. Enforce `capacity` on enrollment creation. |
| P8 | Enrollment read | A student sees only their own enrollments. A professor sees enrollments for sections they teach. A department administrator sees enrollments for students and sections in their department. |
| P9 | Enrollment write | Students may request an enrollment/drop only through a controlled procedure that checks term, capacity, prerequisite and duplicate rules. They should receive no direct INSERT/UPDATE/DELETE on `ENROLLMENT`. |
| P10 | Enrollment status | Only authorised registration staff or a controlled procedure may set `ENROLLED`, `DROPPED`, or `WAITLISTED`; status transitions must be validated and audited. |
| P11 | Grade read | A student sees only grades for their own enrollments. A professor sees grades only for sections they teach. Department administrators may read grades in scope; university administrators may read all. |
| P12 | Grade write | Only the section's assigned professor may insert or update a grade. No DELETE after release; corrections create an audit event with old/new value, actor and time. |
| P13 | Attendance read | A student sees only their own attendance. A professor sees attendance only for sections they teach. Department administrators have scoped read access. |
| P14 | Attendance write | Only the section's assigned professor (or explicitly authorised teaching staff, if modelled) may record or correct attendance. Prevent duplicate attendance per enrollment/date. |
| P15 | Cross-department integrity | A department administrator's VPD predicate must traverse `SECTION -> COURSE` and `SECTION -> PROFESSOR`, not merely trust a submitted foreign-key value. |
| P16 | Referential integrity | Foreign keys remain enabled; use `ON DELETE` only where the business rules explicitly permit it. Normally preserve academic history and use status changes instead of deletes. |
| P17 | Role separation | Keep student, professor, department-admin and university-admin roles separate. Department-admin roles should be department-specific, not a global `DEPT_ADMIN` role. |
| P18 | Sensitive identifiers | Restrict `login_name` to the security package and administrators. Avoid exposing it in student-facing views; preferably grant views rather than base tables. |
| P19 | Auditing | Audit failed context setup, privilege/role changes, and all INSERT/UPDATE/DELETE actions on enrollment, grade and attendance. Retain who, when, source IP/client identifier and before/after values. |
| P20 | Operational controls | Use named accounts, strong authentication, expiry/lockout policy, least-privilege grants, periodic role recertification and separate non-production data. Never use the demo passwords outside a local exercise. |

For the current project, implement P3 and P9 most safely with stored procedures/views, and use VPD for P3, P4, P6–P8, P11 and P13–P15.
