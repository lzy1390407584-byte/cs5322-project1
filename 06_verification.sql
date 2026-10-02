-- Automated acceptance check for Project I (policy inventory, visibility matrix, column
-- masking, grade audit). Run as CS5322_P1 after 03_vpd_policies.sql and 03b_test_support.sql.
-- Identities are simulated with the context package; 07 and 08 repeat the important
-- checks with real database logins.  The expected values below were derived by hand
-- from the dummy data and the policy rules, independently of the policy code.
SET SERVEROUTPUT ON SIZE UNLIMITED
SET VERIFY OFF
SET FEEDBACK OFF
SET LINESIZE 220
SET PAGESIZE 100
COLUMN object_name FORMAT A16
COLUMN policy_name FORMAT A26
COLUMN function FORMAT A24
COLUMN policy_type FORMAT A20

PROMPT === VPD OBJECT CHECK ===
SELECT object_name, policy_name, function, sel, ins, upd, del, chk_option, enable, policy_type
  FROM user_policies
 ORDER BY object_name, policy_name;

PROMPT
PROMPT === Checks (visibility columns: department, student, professor, course, section, enrollment, grade, payment, residence, residence_room, room_allocation, resident_fellow, grade_audit) ===
DECLARE
    TYPE t_names IS TABLE OF VARCHAR2(30);
    TYPE t_exp IS TABLE OF VARCHAR2(60) INDEX BY VARCHAR2(30);
    v_tables t_names := t_names('department','student','professor','course','section','enrollment','grade',
                                'payment','residence','residence_room','room_allocation','resident_fellow','grade_audit');
    v_users  t_names := t_names('alice','bob','carol','prof_lee','prof_wong','admin_comp','admin_bus',
                                'finance1','housing1','uni_admin','(no identity)');
    v_exp t_exp;
    v_actual VARCHAR2(200);
    n NUMBER;
    v_ins NUMBER;
    v_upd NUMBER;
    v_del NUMBER;
BEGIN
    v_exp('alice')         := '3,1,1,2,2,2,1,1,1,1,1,0,0';
    v_exp('bob')           := '3,1,1,2,2,2,1,1,1,1,2,0,0';
    v_exp('carol')         := '3,1,1,1,1,1,1,1,1,1,1,0,0';
    v_exp('prof_lee')      := '3,2,1,2,2,2,2,0,1,3,3,1,0';
    v_exp('prof_wong')     := '3,2,1,3,3,3,2,0,1,2,2,2,0';
    v_exp('admin_comp')    := '3,1,1,2,3,3,2,0,0,0,0,0,0';
    v_exp('admin_bus')     := '3,1,1,1,1,1,1,0,0,0,0,0,0';
    v_exp('finance1')      := '3,3,0,0,0,0,0,3,0,0,0,0,0';
    v_exp('housing1')      := '3,3,0,0,0,0,0,0,2,5,6,3,0';
    v_exp('uni_admin')     := '3,3,2,4,5,5,4,3,2,5,6,3,0';
    v_exp('(no identity)') := '0,0,0,0,0,0,0,0,0,0,0,0,0';

    cs5322_test.reset;

    -- 1. Policy inventory
    SELECT COUNT(*) INTO n FROM user_policies WHERE enable = 'YES';
    cs5322_test.check_true('27 VPD policies enabled', n = 27, 'actual=' || n);
    SELECT COUNT(*) INTO n FROM user_objects WHERE status <> 'VALID';
    cs5322_test.check_true('all PL/SQL objects valid (policy functions, packages, triggers)', n = 0, 'invalid=' || n);
    FOR j IN 1 .. v_tables.COUNT LOOP
        SELECT COUNT(*) INTO n FROM user_policies
         WHERE object_name = UPPER(v_tables(j)) AND sel = 'YES' AND enable = 'YES';
        cs5322_test.check_true('SELECT policy on ' || UPPER(v_tables(j)), n >= 1);
        -- GRADE_AUDIT is written only by a trigger, so it has no DML policy.
        IF v_tables(j) <> 'grade_audit' THEN
            SELECT COUNT(CASE WHEN ins = 'YES' THEN 1 END), COUNT(CASE WHEN upd = 'YES' THEN 1 END),
                   COUNT(CASE WHEN del = 'YES' THEN 1 END)
              INTO v_ins, v_upd, v_del
              FROM user_policies WHERE object_name = UPPER(v_tables(j)) AND enable = 'YES';
            cs5322_test.check_true('INSERT/UPDATE/DELETE policy on ' || UPPER(v_tables(j)),
                                   v_ins >= 1 AND v_upd >= 1 AND v_del >= 1);
        END IF;
    END LOOP;

    -- 2. Visibility matrix: rows each identity sees in each table
    FOR i IN 1 .. v_users.COUNT LOOP
        IF v_users(i) = '(no identity)' THEN
            cs5322_security_ctx.clear_user;
        ELSE
            cs5322_security_ctx.set_user(v_users(i));
        END IF;
        v_actual := NULL;
        FOR j IN 1 .. v_tables.COUNT LOOP
            EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || v_tables(j) INTO n;
            v_actual := v_actual || CASE WHEN j > 1 THEN ',' END || n;
        END LOOP;
        cs5322_test.check_true('visibility of ' || RPAD(v_users(i), 13), v_actual = v_exp(v_users(i)),
            CASE WHEN v_actual = v_exp(v_users(i)) THEN v_actual
                 ELSE 'expected ' || v_exp(v_users(i)) || ' actual ' || v_actual END);
    END LOOP;

    -- 3. Column masking and draft grades
    cs5322_security_ctx.set_user('finance1');
    cs5322_test.expect_count('finance sees 3 students but no e-mail address (column masking)',
                             'SELECT COUNT(email) FROM student', 0);
    cs5322_test.expect_count('finance still sees the student rows', 'SELECT COUNT(student_name) FROM student', 3);
    cs5322_security_ctx.set_user('alice');
    cs5322_test.expect_count('alice reads her own e-mail address', 'SELECT COUNT(email) FROM student', 1);
    cs5322_test.expect_count('alice cannot see the draft grade', 'SELECT COUNT(*) FROM grade WHERE released = ''N''', 0);
    cs5322_security_ctx.set_user('housing1');
    cs5322_test.expect_count('housing officer reads resident e-mail addresses', 'SELECT COUNT(email) FROM student', 3);
    cs5322_security_ctx.set_user('prof_lee');
    cs5322_test.expect_count('prof_lee reads the e-mail of the 2 students he may see', 'SELECT COUNT(email) FROM student', 2);
    cs5322_test.expect_count('prof_lee sees the draft grade', 'SELECT COUNT(*) FROM grade WHERE released = ''N''', 1);

    -- 4. The editor of a grade is the authenticated user, whatever the statement says
    cs5322_test.expect_value('grade editor forced to the authenticated user (spoof attempt)',
        'UPDATE grade SET grade_value = ''B+'', last_updated_by = 2002 WHERE grade_id = 90004',
        'SELECT last_updated_by FROM grade WHERE grade_id = 90004', 2001);

    -- 5. Grade changes are audited with the application identity; the audit trail is
    --    readable only by the university administrator
    UPDATE grade SET grade_value = 'B+' WHERE grade_id = 90004;
    cs5322_security_ctx.set_user('prof_lee');
    cs5322_test.expect_count('prof_lee cannot read the audit trail', 'SELECT COUNT(*) FROM grade_audit', 0);
    cs5322_security_ctx.set_user('uni_admin');
    SELECT COUNT(*) INTO n FROM grade_audit
     WHERE grade_id = 90004 AND action = 'U' AND actor_user_id = 2001
       AND old_grade_value = 'B' AND new_grade_value = 'B+' AND old_released = 'N' AND new_released = 'N';
    cs5322_test.check_true('grade update audited with actor 2001 (prof_lee), old B, new B+', n = 1, 'rows=' || n);
    ROLLBACK;
    cs5322_test.expect_count('audit rows rolled back with the transaction', 'SELECT COUNT(*) FROM grade_audit', 0);

    cs5322_security_ctx.clear_user;
    cs5322_test.summary('PROJECT I VERIFICATION');
END;
/
