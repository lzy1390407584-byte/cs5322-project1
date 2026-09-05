-- End-to-end checks using real database users.
-- Run with: sqlplus /nolog @07_real_user_smoke_tests.sql
set heading on
set feedback on
set serveroutput on
prompt === Alice actual database user ===
connect alice/Alice#5322@FREEPDB1
exec CS5322_P1.cs5322_security_ctx.set_user('alice');
select count(*) as alice_students from CS5322_P1.student;
select count(*) as alice_grades from CS5322_P1.grade;
prompt === Finance actual database user ===
connect finance1/Finance#5322@FREEPDB1
exec CS5322_P1.cs5322_security_ctx.set_user('finance1');
select count(*) as finance_payments from CS5322_P1.payment;
declare
  n number;
begin
  begin
    execute immediate 'select count(*) from CS5322_P1.grade' into n;
    dbms_output.put_line('FAIL | Finance grades should be denied, but rows=' || n);
  exception
    when others then
      if sqlcode = -942 then
        dbms_output.put_line('PASS | Finance grades denied as expected');
      else
        raise;
      end if;
  end;
end;
/
prompt === University admin actual database user ===
connect uni_admin/Uni#5322@FREEPDB1
exec CS5322_P1.cs5322_security_ctx.set_user('uni_admin');
select count(*) as university_students from CS5322_P1.student;
select count(*) as university_grades from CS5322_P1.grade;
exit
