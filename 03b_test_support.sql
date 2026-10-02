-- CS5322 Project I: small assertion helper used by the verification and real-user tests.
-- Run as CS5322_P1 after 03_vpd_policies.sql.
--
-- The package is AUTHID CURRENT_USER, so the statements it runs execute with the caller's
-- own privileges and the caller's application context.  That is what lets the real-user
-- scripts (07, 08) exercise object privileges and VPD together.
CREATE OR REPLACE PACKAGE cs5322_test AUTHID CURRENT_USER AS
    PROCEDURE reset;
    PROCEDURE check_true(p_label VARCHAR2, p_ok BOOLEAN, p_detail VARCHAR2 DEFAULT NULL);
    -- A SELECT COUNT(*) statement must return p_expected.
    PROCEDURE expect_count(p_label VARCHAR2, p_sql VARCHAR2, p_expected NUMBER);
    -- A DML statement must affect p_expected rows (it is rolled back afterwards).
    PROCEDURE expect_rows(p_label VARCHAR2, p_dml VARCHAR2, p_expected NUMBER);
    -- A statement must fail with Oracle error p_code, e.g. -28115 (it is rolled back).
    PROCEDURE expect_error(p_label VARCHAR2, p_sql VARCHAR2, p_code NUMBER);
    -- A statement must be refused by the privilege layer: ORA-01031 (ORA-41900 on Oracle
    -- 23ai and later, which names the missing privilege) or ORA-00942 (no grant at all).
    PROCEDURE expect_denied(p_label VARCHAR2, p_sql VARCHAR2);
    -- After running a DML statement, a single-number query must return p_expected.
    PROCEDURE expect_value(p_label VARCHAR2, p_dml VARCHAR2, p_query VARCHAR2, p_expected NUMBER);
    PROCEDURE summary(p_scope VARCHAR2);
END;
/

CREATE OR REPLACE PACKAGE BODY cs5322_test AS
    g_pass PLS_INTEGER := 0;
    g_fail PLS_INTEGER := 0;

    FUNCTION oneline(p_text VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN SUBSTR(REPLACE(REPLACE(p_text, CHR(10), ' '), CHR(13), ' '), 1, 110);
    END;

    FUNCTION ora_name(p_code NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN 'ORA-' || LPAD(ABS(p_code), 5, '0');
    END;

    PROCEDURE reset IS
    BEGIN
        g_pass := 0;
        g_fail := 0;
    END;

    PROCEDURE check_true(p_label VARCHAR2, p_ok BOOLEAN, p_detail VARCHAR2 DEFAULT NULL) IS
    BEGIN
        IF p_ok THEN g_pass := g_pass + 1; ELSE g_fail := g_fail + 1; END IF;
        DBMS_OUTPUT.PUT_LINE(CASE WHEN p_ok THEN 'PASS' ELSE 'FAIL' END || ' | ' || p_label
                             || CASE WHEN p_detail IS NOT NULL THEN ' | ' || p_detail END);
    END;

    PROCEDURE expect_count(p_label VARCHAR2, p_sql VARCHAR2, p_expected NUMBER) IS
        n NUMBER;
        v_err VARCHAR2(200);
    BEGIN
        EXECUTE IMMEDIATE p_sql INTO n;
        check_true(p_label, n = p_expected, 'expected=' || p_expected || ' actual=' || n);
    EXCEPTION
        WHEN OTHERS THEN
            v_err := oneline(SQLERRM);
            check_true(p_label, FALSE, 'expected=' || p_expected || ' error: ' || v_err);
    END;

    PROCEDURE expect_rows(p_label VARCHAR2, p_dml VARCHAR2, p_expected NUMBER) IS
        n NUMBER;
        v_err VARCHAR2(200);
    BEGIN
        EXECUTE IMMEDIATE p_dml;
        n := SQL%ROWCOUNT;
        ROLLBACK;
        check_true(p_label, n = p_expected, 'rows expected=' || p_expected || ' actual=' || n);
    EXCEPTION
        WHEN OTHERS THEN
            v_err := oneline(SQLERRM);
            ROLLBACK;
            check_true(p_label, FALSE, 'rows expected=' || p_expected || ' error: ' || v_err);
    END;

    PROCEDURE expect_error(p_label VARCHAR2, p_sql VARCHAR2, p_code NUMBER) IS
        v_ok BOOLEAN := FALSE;
        v_code NUMBER;
        v_err VARCHAR2(200);
    BEGIN
        BEGIN
            EXECUTE IMMEDIATE p_sql;
            v_code := 0;
            v_err := 'statement succeeded';
        EXCEPTION
            WHEN OTHERS THEN
                v_code := SQLCODE;
                v_err := oneline(SQLERRM);
        END;
        ROLLBACK;
        v_ok := (v_code = p_code);
        check_true(p_label, v_ok, CASE WHEN v_ok THEN 'raised ' || ora_name(p_code)
                                       ELSE 'expected ' || ora_name(p_code) || ' but ' || v_err END);
    END;

    PROCEDURE expect_denied(p_label VARCHAR2, p_sql VARCHAR2) IS
        v_code NUMBER;
        v_err VARCHAR2(200);
    BEGIN
        BEGIN
            EXECUTE IMMEDIATE p_sql;
            v_code := 0;
            v_err := 'statement succeeded';
        EXCEPTION
            WHEN OTHERS THEN
                v_code := SQLCODE;
                v_err := oneline(SQLERRM);
        END;
        ROLLBACK;
        check_true(p_label, v_code IN (-1031, -41900, -942),
                   CASE WHEN v_code IN (-1031, -41900, -942) THEN 'refused with ' || ora_name(v_code)
                        ELSE 'expected a privilege error but ' || v_err END);
    END;

    PROCEDURE expect_value(p_label VARCHAR2, p_dml VARCHAR2, p_query VARCHAR2, p_expected NUMBER) IS
        n NUMBER;
        v_err VARCHAR2(200);
    BEGIN
        EXECUTE IMMEDIATE p_dml;
        EXECUTE IMMEDIATE p_query INTO n;
        ROLLBACK;
        check_true(p_label, n = p_expected, 'expected=' || p_expected || ' actual=' || n);
    EXCEPTION
        WHEN OTHERS THEN
            v_err := oneline(SQLERRM);
            ROLLBACK;
            check_true(p_label, FALSE, 'expected=' || p_expected || ' error: ' || v_err);
    END;

    PROCEDURE summary(p_scope VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('=== ' || p_scope || ': ' || CASE WHEN g_fail = 0 THEN 'PASS' ELSE 'FAIL' END
                             || ' (' || g_pass || ' passed, ' || g_fail || ' failed) ===');
    END;
END;
/

GRANT EXECUTE ON cs5322_test TO PUBLIC;
