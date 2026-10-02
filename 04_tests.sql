-- Visibility matrix and sample result sets. Run as CS5322_P1 (never as SYS: SYS is exempt
-- from VPD and would see every row). Identities are simulated with the context package,
-- which the schema owner is allowed to call for any application user.
SET SERVEROUTPUT ON SIZE UNLIMITED
SET FEEDBACK OFF
SET VERIFY OFF
SET LINESIZE 200
SET PAGESIZE 100
COLUMN student_name FORMAT A14
COLUMN email FORMAT A18
COLUMN grade_value HEADING 'GRADE' FORMAT A5
COLUMN released FORMAT A8
COLUMN allocation_status FORMAT A17

PROMPT === Visible rows per table and application identity (0 = hidden) ===
DECLARE
    TYPE t_names IS TABLE OF VARCHAR2(30);
    v_users  t_names := t_names('alice','bob','carol','prof_lee','prof_wong','admin_comp','admin_bus',
                                'finance1','housing1','uni_admin','(no identity)');
    v_tables t_names := t_names('department','student','professor','course','section','enrollment','grade',
                                'payment','residence','residence_room','room_allocation','resident_fellow','grade_audit');
    v_labels t_names := t_names('dept','stud','prof','cours','sect','enrol','grade','pay',
                                'resid','room','alloc','fellow','audit');
    v_line VARCHAR2(400);
    n NUMBER;
BEGIN
    v_line := RPAD('MATRIX identity', 21);
    FOR j IN 1 .. v_labels.COUNT LOOP
        v_line := v_line || LPAD(v_labels(j), 7);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(v_line);
    FOR i IN 1 .. v_users.COUNT LOOP
        IF v_users(i) = '(no identity)' THEN
            cs5322_security_ctx.clear_user;
        ELSE
            cs5322_security_ctx.set_user(v_users(i));
        END IF;
        v_line := RPAD('MATRIX ' || v_users(i), 21);
        FOR j IN 1 .. v_tables.COUNT LOOP
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_tables(j) INTO n;
            v_line := v_line || LPAD(n, 7);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(v_line);
    END LOOP;
END;
/

PROMPT
PROMPT === Alice: the draft grade 90004 is hidden until it is released ===
EXEC cs5322_security_ctx.set_user('alice');
SELECT grade_id, enrollment_id, grade_value, released FROM grade ORDER BY grade_id;

PROMPT === Professor Lee: sees the draft too ===
EXEC cs5322_security_ctx.set_user('prof_lee');
SELECT grade_id, enrollment_id, grade_value, released FROM grade ORDER BY grade_id;

PROMPT === Professor Lee: his class list plus the residents of Kent Ridge Hall (Carol lives there) ===
SELECT student_id, student_name, email FROM student ORDER BY student_id;
PROMPT === Professor Lee as resident fellow: active allocations of Kent Ridge Hall only ===
SELECT allocation_id, room_id, student_id, professor_id, allocation_status FROM room_allocation ORDER BY allocation_id;

PROMPT === Professor Wong: Prince George's Park only; his ended Kent Ridge Hall fellowship grants nothing ===
EXEC cs5322_security_ctx.set_user('prof_wong');
SELECT allocation_id, room_id, student_id, professor_id, allocation_status FROM room_allocation ORDER BY allocation_id;

PROMPT === Computing department admin: Computing rows only ===
EXEC cs5322_security_ctx.set_user('admin_comp');
SELECT student_id, department_id, student_name FROM student ORDER BY student_id;
SELECT course_id, department_id, course_code FROM course ORDER BY course_id;
SELECT section_id, course_id, professor_id, semester, academic_year FROM section ORDER BY section_id;
SELECT grade_id, enrollment_id, grade_value, released FROM grade ORDER BY grade_id;

PROMPT === Finance: every student, but the e-mail column is masked; every payment; no grades ===
EXEC cs5322_security_ctx.set_user('finance1');
SELECT student_id, student_name, email FROM student ORDER BY student_id;
SELECT payment_id, student_id, amount, payment_status FROM payment ORDER BY payment_id;
SELECT COUNT(*) AS grades_visible_to_finance FROM grade;

PROMPT === Housing officer: all allocations ===
EXEC cs5322_security_ctx.set_user('housing1');
SELECT allocation_id, room_id, student_id, professor_id, allocation_status FROM room_allocation ORDER BY allocation_id;

PROMPT === No application identity: fail closed ===
EXEC cs5322_security_ctx.clear_user;
SELECT COUNT(*) AS students_without_identity FROM student;

PROMPT === Expected matrix: see 06_verification.sql ===
