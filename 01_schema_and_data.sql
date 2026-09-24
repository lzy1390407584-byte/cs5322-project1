-- CS5322 Project I: schema, context package and dummy data
-- Run as the project schema owner.

SET DEFINE OFF;

CREATE TABLE department (
    department_id NUMBER PRIMARY KEY,
    department_name VARCHAR2(100) NOT NULL UNIQUE
);

CREATE TABLE app_user (
    user_id NUMBER PRIMARY KEY,
    username VARCHAR2(30) NOT NULL UNIQUE,
    full_name VARCHAR2(100) NOT NULL,
    user_role VARCHAR2(30) NOT NULL,
    department_id NUMBER REFERENCES department(department_id),
    CONSTRAINT app_user_role_ck CHECK (user_role IN ('STUDENT','PROFESSOR','DEPT_ADMIN','FINANCE','HOUSING_OFFICER','UNIVERSITY_ADMIN'))
);

CREATE TABLE student (
    student_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL UNIQUE REFERENCES app_user(user_id),
    department_id NUMBER NOT NULL REFERENCES department(department_id),
    student_name VARCHAR2(100) NOT NULL,
    email VARCHAR2(120) NOT NULL UNIQUE
);

CREATE TABLE professor (
    professor_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL UNIQUE REFERENCES app_user(user_id),
    department_id NUMBER NOT NULL REFERENCES department(department_id),
    professor_name VARCHAR2(100) NOT NULL
);

CREATE TABLE course (
    course_id NUMBER PRIMARY KEY,
    department_id NUMBER NOT NULL REFERENCES department(department_id),
    course_code VARCHAR2(20) NOT NULL UNIQUE,
    course_title VARCHAR2(120) NOT NULL
);

-- A section is one offering of a course in a particular term.  This is where
-- the teaching assignment belongs: the same course may therefore be offered
-- by different professors in different semesters (or in parallel sections).
CREATE TABLE section (
    section_id NUMBER PRIMARY KEY,
    course_id NUMBER NOT NULL REFERENCES course(course_id),
    professor_id NUMBER NOT NULL REFERENCES professor(professor_id),
    semester VARCHAR2(20) NOT NULL,
    academic_year NUMBER(4) NOT NULL CHECK (academic_year BETWEEN 2000 AND 2100),
    room VARCHAR2(30) NOT NULL,
    capacity NUMBER(5) NOT NULL CHECK (capacity > 0),
    CONSTRAINT section_uq UNIQUE (course_id, professor_id, semester, academic_year, room)
);

CREATE TABLE enrollment (
    enrollment_id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL REFERENCES student(student_id),
    section_id NUMBER NOT NULL REFERENCES section(section_id),
    status VARCHAR2(15) NOT NULL,
    enrolled_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT enrollment_status_ck CHECK (status IN ('ENROLLED','DROPPED','WAITLISTED')),
    CONSTRAINT enrollment_uq UNIQUE (student_id, section_id)
);

CREATE TABLE grade (
    grade_id NUMBER PRIMARY KEY,
    enrollment_id NUMBER NOT NULL UNIQUE REFERENCES enrollment(enrollment_id),
    grade_value VARCHAR2(2) NOT NULL,
    last_updated_by NUMBER NOT NULL REFERENCES app_user(user_id)
);

CREATE TABLE payment (
    payment_id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL REFERENCES student(student_id),
    amount NUMBER(10,2) NOT NULL,
    payment_status VARCHAR2(20) NOT NULL,
    payment_date DATE NOT NULL,
    CONSTRAINT payment_status_ck CHECK (payment_status IN ('PAID','PENDING','REFUNDED'))
);

CREATE TABLE residence (
    residence_id NUMBER PRIMARY KEY,
    residence_name VARCHAR2(100) NOT NULL UNIQUE,
    address VARCHAR2(200) NOT NULL
);

CREATE TABLE residence_room (
    room_id NUMBER PRIMARY KEY,
    residence_id NUMBER NOT NULL REFERENCES residence(residence_id),
    room_number VARCHAR2(20) NOT NULL,
    capacity NUMBER(3) NOT NULL CHECK (capacity > 0),
    CONSTRAINT residence_room_uq UNIQUE (residence_id, room_number)
);

-- An allocation belongs to exactly one type of resident: a student or a
-- professor acting as a resident fellow.  Active fellow allocations establish
-- the residence scope used by the housing VPD policies.
CREATE TABLE room_allocation (
    allocation_id NUMBER PRIMARY KEY,
    room_id NUMBER NOT NULL REFERENCES residence_room(room_id),
    student_id NUMBER REFERENCES student(student_id),
    professor_id NUMBER REFERENCES professor(professor_id),
    allocation_status VARCHAR2(15) NOT NULL,
    allocated_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT allocation_occupant_ck CHECK (
        (student_id IS NOT NULL AND professor_id IS NULL) OR
        (student_id IS NULL AND professor_id IS NOT NULL)
    ),
    CONSTRAINT allocation_status_ck CHECK (allocation_status IN ('ACTIVE','ENDED','PENDING'))
);

CREATE INDEX student_department_ix ON student(department_id);
CREATE INDEX professor_department_ix ON professor(department_id);
CREATE INDEX section_course_ix ON section(course_id);
CREATE INDEX section_professor_ix ON section(professor_id);
CREATE INDEX enrollment_student_ix ON enrollment(student_id);
CREATE INDEX enrollment_section_ix ON enrollment(section_id);
-- No separate index is needed here: the UNIQUE constraint on enrollment_id
-- already creates an index in Oracle. Creating another one raises ORA-01408.
CREATE INDEX payment_student_ix ON payment(student_id);
CREATE INDEX residence_room_residence_ix ON residence_room(residence_id);
CREATE INDEX allocation_room_ix ON room_allocation(room_id);
CREATE INDEX allocation_student_ix ON room_allocation(student_id);
CREATE INDEX allocation_professor_ix ON room_allocation(professor_id);

CREATE OR REPLACE PACKAGE cs5322_security_ctx AS
    PROCEDURE set_user(p_username VARCHAR2);
    PROCEDURE clear_user;
END;
/

-- Application context stores the authenticated application identity.
CREATE OR REPLACE CONTEXT cs5322_app_ctx USING cs5322_security_ctx;
/

CREATE OR REPLACE PACKAGE BODY cs5322_security_ctx AS
    PROCEDURE set_user(p_username VARCHAR2) IS
        v_role app_user.user_role%TYPE;
        v_user_id app_user.user_id%TYPE;
        v_department_id app_user.department_id%TYPE;
        v_session_user VARCHAR2(128) := UPPER(SYS_CONTEXT('USERENV','SESSION_USER'));
    BEGIN
        -- A normal database user may only activate its own application identity.
        -- The schema owner/DBA exception exists solely for repeatable classroom tests.
        IF v_session_user NOT IN ('CS5322_P1','SYS','SYSTEM')
           AND v_session_user <> UPPER(p_username) THEN
            RAISE_APPLICATION_ERROR(-20002, 'Session user cannot impersonate another application user');
        END IF;
        SELECT user_id, user_role, department_id
          INTO v_user_id, v_role, v_department_id
          FROM app_user
         WHERE UPPER(username) = UPPER(p_username);
        DBMS_SESSION.SET_CONTEXT('CS5322_APP_CTX', 'USERNAME', UPPER(p_username));
        DBMS_SESSION.SET_CONTEXT('CS5322_APP_CTX', 'USER_ID', TO_CHAR(v_user_id));
        DBMS_SESSION.SET_CONTEXT('CS5322_APP_CTX', 'ROLE', v_role);
        DBMS_SESSION.SET_CONTEXT('CS5322_APP_CTX', 'DEPARTMENT_ID', TO_CHAR(v_department_id));
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            clear_user;
            RAISE_APPLICATION_ERROR(-20001, 'Unknown application user');
    END;

    PROCEDURE clear_user IS
    BEGIN
        DBMS_SESSION.CLEAR_CONTEXT('CS5322_APP_CTX');
    END;
END;
/

INSERT INTO department VALUES (10, 'Computing');
INSERT INTO department VALUES (20, 'Business');
INSERT INTO department VALUES (30, 'Medicine');

INSERT INTO app_user VALUES (1001, 'alice', 'Alice Tan', 'STUDENT', 10);
INSERT INTO app_user VALUES (1002, 'bob', 'Bob Lim', 'STUDENT', 20);
INSERT INTO app_user VALUES (1003, 'carol', 'Carol Ong', 'STUDENT', 30);
INSERT INTO app_user VALUES (2001, 'prof_lee', 'Professor Lee', 'PROFESSOR', 10);
INSERT INTO app_user VALUES (2002, 'prof_wong', 'Professor Wong', 'PROFESSOR', 20);
INSERT INTO app_user VALUES (3001, 'admin_comp', 'Computing Admin', 'DEPT_ADMIN', 10);
INSERT INTO app_user VALUES (3002, 'admin_bus', 'Business Admin', 'DEPT_ADMIN', 20);
INSERT INTO app_user VALUES (4001, 'finance1', 'Finance Officer', 'FINANCE', NULL);
INSERT INTO app_user VALUES (4002, 'housing1', 'Housing Officer', 'HOUSING_OFFICER', NULL);
INSERT INTO app_user VALUES (5001, 'uni_admin', 'University Administrator', 'UNIVERSITY_ADMIN', NULL);

INSERT INTO student VALUES (1, 1001, 10, 'Alice Tan', 'alice@nus.edu.sg');
INSERT INTO student VALUES (2, 1002, 20, 'Bob Lim', 'bob@nus.edu.sg');
INSERT INTO student VALUES (3, 1003, 30, 'Carol Ong', 'carol@nus.edu.sg');
INSERT INTO professor VALUES (1, 2001, 10, 'Professor Lee');
INSERT INTO professor VALUES (2, 2002, 20, 'Professor Wong');

INSERT INTO course VALUES (101, 10, 'CS5322', 'Database Security');
INSERT INTO course VALUES (102, 10, 'CS2103', 'Software Engineering');
INSERT INTO course VALUES (201, 20, 'BIZ1001', 'Business Analytics');
INSERT INTO course VALUES (301, 30, 'MED1001', 'Health Informatics');

-- CS5322 is deliberately offered twice by different professors/terms.
INSERT INTO section VALUES (1001, 101, 1, 'S1', 2026, 'COM1-02-12', 40);
INSERT INTO section VALUES (1002, 101, 2, 'S2', 2026, 'BIZ2-01-03', 35);
INSERT INTO section VALUES (1003, 102, 1, 'S1', 2026, 'COM1-02-13', 40);
INSERT INTO section VALUES (2001, 201, 2, 'S1', 2026, 'BIZ2-01-01', 35);
INSERT INTO section VALUES (3001, 301, 2, 'S1', 2026, 'MD1-01-02', 30);

INSERT INTO enrollment VALUES (10001, 1, 1001, 'ENROLLED', TIMESTAMP '2026-01-05 09:00:00');
INSERT INTO enrollment VALUES (10002, 2, 2001, 'ENROLLED', TIMESTAMP '2026-01-05 09:05:00');
INSERT INTO enrollment VALUES (10003, 3, 3001, 'ENROLLED', TIMESTAMP '2026-01-05 09:10:00');
INSERT INTO enrollment VALUES (10004, 1, 1003, 'ENROLLED', TIMESTAMP '2026-01-06 09:00:00');
INSERT INTO grade VALUES (90001, 10001, 'A', 2001);
INSERT INTO grade VALUES (90002, 10002, 'B+', 2002);
INSERT INTO grade VALUES (90003, 10003, 'A-', 2002);
INSERT INTO grade VALUES (90004, 10004, 'B', 2001);

INSERT INTO payment VALUES (70001, 1, 1200.00, 'PAID', DATE '2026-01-10');
INSERT INTO payment VALUES (70002, 2, 1100.00, 'PENDING', DATE '2026-01-11');
INSERT INTO payment VALUES (70003, 3, 1300.00, 'PAID', DATE '2026-01-12');

INSERT INTO residence VALUES (1, 'Kent Ridge Hall', '10 Kent Ridge Drive');
INSERT INTO residence VALUES (2, 'Prince George''s Park Residences', '30 Lower Kent Ridge Road');
INSERT INTO residence_room VALUES (101, 1, 'A101', 1);
INSERT INTO residence_room VALUES (102, 1, 'A102', 1);
INSERT INTO residence_room VALUES (103, 1, 'RF01', 1);
INSERT INTO residence_room VALUES (201, 2, 'B201', 1);
INSERT INTO residence_room VALUES (202, 2, 'RF01', 1);
INSERT INTO room_allocation VALUES (60001, 101, 1, NULL, 'ACTIVE', TIMESTAMP '2026-01-02 09:00:00');
INSERT INTO room_allocation VALUES (60002, 102, 3, NULL, 'ACTIVE', TIMESTAMP '2026-01-02 09:00:00');
INSERT INTO room_allocation VALUES (60003, 103, NULL, 1, 'ACTIVE', TIMESTAMP '2026-01-02 09:00:00');
INSERT INTO room_allocation VALUES (60004, 201, 2, NULL, 'ACTIVE', TIMESTAMP '2026-01-02 09:00:00');
INSERT INTO room_allocation VALUES (60005, 202, NULL, 2, 'ACTIVE', TIMESTAMP '2026-01-02 09:00:00');
COMMIT;
