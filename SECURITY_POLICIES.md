# Security policies

This catalogue describes what the scripts in this repository actually enforce (27 policies on
13 tables) and where each rule is tested.  Enforcement has three layers: **object privileges**
(roles, `02_regrant_object_privileges.sql`), **VPD row/column policies** (`03_vpd_policies.sql`)
and **triggers** (`01_schema_and_data.sql`).  Rows are never filtered by a value the caller
supplies: every predicate is built from the trusted application context.

## Roles and identity

| Application role | Accounts | Purpose |
|---|---|---|
| `STUDENT` | alice (Computing), bob (Business), carol (Medicine) | Read own academic, payment and housing records |
| `PROFESSOR` | prof_lee (Computing), prof_wong (Business) | Teach sections, grade students; also resident fellows |
| `DEPT_ADMIN` | admin_comp, admin_bus | Manage the records of one department; publish grades |
| `FINANCE` | finance1 | Process payments; never sees grades |
| `HOUSING_OFFICER` | housing1 | Allocate rooms; never sees academic or payment data |
| `UNIVERSITY_ADMIN` | uni_admin | Read-only oversight of everything, including the audit trail |

`CS5322_SECURITY_CTX.SET_USER(name)` looks the name up in `APP_USER` and stores `USERNAME`,
`USER_ID`, `ROLE`, `DEPARTMENT_ID` in `CS5322_APP_CTX`.  A database user can activate only its own
name (`ORA-20002` otherwise); `CS5322_P1`, `SYS`, `SYSTEM` may activate any (test convenience).
Without an identity the role is NULL and every policy returns `1=0`.

## Security requirements

| ID | Requirement | Enforced by | Tested in |
|---|---|---|---|
| SR1 | A student reads only his own student, enrolment, payment and housing rows | `STUDENT_VPD`, `ENROLLMENT_VPD`, `PAYMENT_VPD`, `ROOM_ALLOCATION_VPD` | 06 matrix, 07 |
| SR2 | A student sees only the sections he is enrolled in, their courses and instructors | `SECTION_VPD`, `COURSE_VPD`, `PROFESSOR_VPD` | 06, 07 |
| SR3 | A student sees a grade only after it has been released | `GRADE_VPD` (`released = 'Y'`) | 06, 07 |
| SR4 | A professor sees the sections he teaches (not other offerings of the same course), their enrolments, grades (drafts included) and class list | `SECTION_VPD`, `ENROLLMENT_VPD`, `GRADE_VPD`, `STUDENT_VPD` | 06, 07 |
| SR5 | A professor may only create/edit *draft* grades of his own sections; he cannot publish a grade, change a published one, or delete | `GRADE_WRITE_VPD`, no DELETE grant | 08 |
| SR6 | A department administrator manages courses, sections, enrolments, students and grades of his department only, cannot move a record out of it, publishes and corrects grades, and deletes only drafts | `*_WRITE_VPD`, `GRADE_DELETE_VPD` | 08 |
| SR7 | Finance reads all payments and student names (not e-mail), records payments, never sees grades | `PAYMENT_*`, `STUDENT_VPD`, `STUDENT_EMAIL_MASK_VPD`, no grant on `GRADE` | 06, 07, 08 |
| SR8 | Housing officers read and manage all housing data, nothing academic or financial | `RESIDENCE*_VPD`, `ROOM_ALLOCATION_*`, grants | 07, 08 |
| SR9 | A resident fellow sees the residence he *currently* looks after (rooms, active allocations, residents' names); an ended assignment grants nothing | `RESIDENT_FELLOW`, `RESIDENCE_*_VPD`, `ROOM_ALLOCATION_VPD`, `STUDENT_VPD` | 06, 07 |
| SR10 | A student sees only his current residence and room and his own allocation history | `RESIDENCE_VPD`, `RESIDENCE_ROOM_VPD`, `ROOM_ALLOCATION_VPD` | 06, 07 |
| SR11 | University administrators read everything, including the audit trail, and write nothing | grants, `GRADE_AUDIT_VPD` | 07, 08 |
| SR12 | A missing or invalid identity returns no rows and permits no write | every policy function returns `1=0` | 06, 07, 08 |
| SR13 | A database user cannot act as another application user | `CS5322_SECURITY_CTX.SET_USER` | 07 |
| SR14 | Write policies are independent of privileges (defense in depth) and validate the new row | `*_WRITE_VPD` with `update_check` | 08, 09 |
| SR15 | The editor recorded on a grade cannot be spoofed; every grade change is audited with the application identity | `GRADE_EDITOR_TRG`, `GRADE_AUDIT_TRG`, `GRADE_AUDIT` | 06, 08 |
| SR16 | Contact data (e-mail) is hidden from roles without a need for it | `STUDENT_EMAIL_MASK_VPD` (column-level, `ALL_ROWS`) | 06, 07 |

## Read policies (`<TABLE>_VPD`, `SELECT`)

| Table | Student | Professor | Dept admin | Finance | Housing | University admin |
|---|---|---|---|---|---|---|
| `DEPARTMENT` | all | all | all | all | all | all |
| `STUDENT` | own row | students of his sections + residents of his residence (as fellow) | own department | all rows, e-mail masked | students with a room allocation | all |
| `PROFESSOR` | instructors of his sections | own row | own department | - | - | all |
| `COURSE` | courses of his sections | courses of his sections | own department | - | - | all |
| `SECTION` | his sections | his sections | sections of own department's courses | - | - | all |
| `ENROLLMENT` | own | his sections | own department's sections | - | - | all |
| `GRADE` | own, **released only** | his sections, drafts included | own department's | - | - | all |
| `PAYMENT` | own | - | - | all | - | all |
| `RESIDENCE` | current residence | residences he looks after | - | - | all | all |
| `RESIDENCE_ROOM` | current room | rooms of his residence | - | - | all | all |
| `ROOM_ALLOCATION` | own (history included) | active allocations of his residence | - | - | all | all |
| `RESIDENT_FELLOW` | - | own assignments | - | - | all | all |
| `GRADE_AUDIT` | - | - | - | - | - | all |

`-` = `1=0`.  `APP_USER` has no policy: it is protected by privileges (no role has any grant) and
is read only by the definer-rights context package.

## Write policies (`<TABLE>_WRITE_VPD`, `INSERT/UPDATE/DELETE`, `update_check`)

| Table | Who may write | Row scope |
|---|---|---|
| `STUDENT`, `COURSE` | dept admin (privileges: S/I/U/D) | own department; a row cannot be moved to another department |
| `SECTION`, `ENROLLMENT` | dept admin | course / section belongs to own department |
| `GRADE` | professor (INSERT/UPDATE) | draft (`released = 'N'`) of his own section; must remain a draft of his own section |
| `GRADE` | dept admin (INSERT/UPDATE) | any grade of his department (publishes, corrects) |
| `GRADE` `DELETE` (`GRADE_DELETE_VPD`) | dept admin | drafts of his department only; a released grade is permanent |
| `PAYMENT` | finance (INSERT/UPDATE, no DELETE) | all |
| `ROOM_ALLOCATION` | housing (INSERT/UPDATE) | all |
| `DEPARTMENT`, `PROFESSOR`, `RESIDENCE`, `RESIDENCE_ROOM`, `RESIDENT_FELLOW` | nobody (`DENY_WRITE_FN`) | - |
| `GRADE_AUDIT` | nobody; filled by `GRADE_AUDIT_TRG` | - |

## Design decisions worth knowing

* **Why `RESIDENT_FELLOW`.**  The first design derived a fellow's residence from his own row in
  `ROOM_ALLOCATION`.  A policy on `ROOM_ALLOCATION` then queried `ROOM_ALLOCATION`, and Oracle
  rejects such self-referencing predicates with `ORA-28113`.  The fellowship is now a table of
  its own; no policy queries the table it protects.
* **Policy type.**  Predicates depend only on the application context, so the policies are
  `CONTEXT_SENSITIVE`: Oracle re-evaluates a policy function only when the context changes.
* **Column masking.**  `STUDENT_EMAIL_MASK_VPD` uses `sec_relevant_cols => 'EMAIL'` with
  `ALL_ROWS`: finance still sees the student rows, the column is returned as NULL.
* **Error codes.**  VPD denies silently (0 rows) for reads and for rows outside the predicate,
  and raises `ORA-28115` when an inserted/updated row would violate the policy.

## Attacks on the mechanism that were tested

* **Forging the context.** `DBMS_SESSION.SET_CONTEXT('CS5322_APP_CTX', ...)` called directly by a
  user fails with `ORA-01031`: the namespace is bound to `CS5322_SECURITY_CTX` (script 07).
* **Name-resolution hijack.** Predicates use unqualified table names.  A user who may create tables
  cannot redirect them by creating a look-alike `ENROLLMENT` table in his own schema; Oracle resolves
  the names in the schema of the protected table (script 09, scenario B).
* **Mistaken grant.** A role granted `INSERT/UPDATE/DELETE` on `GRADE` by mistake still cannot change
  a row, because the write policy denies by default (script 09, scenario A).

## Known limitations

* `SYS`/`SYSDBA` and any account with `EXEMPT ACCESS POLICY` are not subject to VPD (verified:
  SYS sees all rows without an identity).  Protecting against a DBA needs Database Vault or
  auditing, which are out of scope.
* `CS5322_P1`, `SYS` and `SYSTEM` can impersonate any application user in `SET_USER`.  That
  exists so the test scripts can simulate users; a real deployment would set the context from a
  logon trigger or a trusted login service.
* Constraint checks ignore VPD and can reveal that a hidden row exists.  Verified: when
  `admin_comp` enrols student 2 (Business, invisible to him) the insert succeeds, while enrolling
  the non-existent student 99 fails with `ORA-02291`, so he can probe which student ids exist.
  VPD filters rows, not the outcome of integrity checks.  (It also means a department
  administrator can enrol a student of another department into a section of his own, which is
  intended: the enrolment row belongs to his department's section.)
* Demo passwords are in the scripts; no encryption of data at rest or in transit is configured.
