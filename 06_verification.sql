-- Automated acceptance check for Project I.
-- Run as CS5322_P1 against FREEPDB1.
SET SERVEROUTPUT ON;
SET VERIFY OFF;
WHENEVER SQLERROR EXIT SQL.SQLCODE;

PROMPT === VPD OBJECT CHECK ===
SELECT object_name, policy_name, sel, ins, upd, del, enable
  FROM user_policies
 ORDER BY object_name;

DECLARE
    v_count NUMBER;
    v_fail NUMBER := 0;
    PROCEDURE check_count(p_label VARCHAR2, p_actual NUMBER, p_expected NUMBER) IS
    BEGIN
        IF p_actual = p_expected THEN
            DBMS_OUTPUT.PUT_LINE('PASS | ' || p_label || ' | expected=' || p_expected || ' actual=' || p_actual);
        ELSE
            DBMS_OUTPUT.PUT_LINE('FAIL | ' || p_label || ' | expected=' || p_expected || ' actual=' || p_actual);
            v_fail := v_fail + 1;
        END IF;
    END;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_policies
     WHERE policy_name IN ('STUDENT_VPD','COURSE_VPD','ENROLLMENT_VPD','GRADE_VPD','PAYMENT_VPD')
       AND enable = 'YES';
    check_count('enabled VPD policies', v_count, 5);

    cs5322_security_ctx.set_user('alice');
    SELECT COUNT(*) INTO v_count FROM student; check_count('Alice students', v_count, 1);
    SELECT COUNT(*) INTO v_count FROM enrollment; check_count('Alice enrollments', v_count, 2);
    SELECT COUNT(*) INTO v_count FROM grade; check_count('Alice grades', v_count, 2);
    SELECT COUNT(*) INTO v_count FROM payment; check_count('Alice payments', v_count, 1);

    cs5322_security_ctx.set_user('admin_comp');
    SELECT COUNT(*) INTO v_count FROM student; check_count('Computing admin students', v_count, 1);
    SELECT COUNT(*) INTO v_count FROM course; check_count('Computing admin courses', v_count, 2);
    SELECT COUNT(*) INTO v_count FROM grade; check_count('Computing admin grades', v_count, 2);

    cs5322_security_ctx.set_user('prof_lee');
    SELECT COUNT(*) INTO v_count FROM course; check_count('Professor Lee courses', v_count, 2);
    SELECT COUNT(*) INTO v_count FROM grade; check_count('Professor Lee grades', v_count, 2);

    cs5322_security_ctx.set_user('finance1');
    SELECT COUNT(*) INTO v_count FROM payment; check_count('Finance payments', v_count, 3);
    SELECT COUNT(*) INTO v_count FROM grade; check_count('Finance grades', v_count, 0);

    cs5322_security_ctx.set_user('uni_admin');
    SELECT COUNT(*) INTO v_count FROM student; check_count('University admin students', v_count, 3);
    SELECT COUNT(*) INTO v_count FROM grade; check_count('University admin grades', v_count, 4);
    SELECT COUNT(*) INTO v_count FROM payment; check_count('University admin payments', v_count, 3);

    IF v_fail = 0 THEN
        DBMS_OUTPUT.PUT_LINE('=== PROJECT I VERIFICATION: PASS ===');
    ELSE
        DBMS_OUTPUT.PUT_LINE('=== PROJECT I VERIFICATION: FAIL (' || v_fail || ' checks) ===');
        RAISE_APPLICATION_ERROR(-20999, 'Verification failed');
    END IF;
END;
/
EXIT;

