# Runbook: deploying, verifying and demonstrating on the group VM

Host `cs5322-5-i.comp.nus.edu.sg` (reachable only through the NUS jump host `stujump`),
Oracle AI Database 26ai Free, pluggable database / service **`CS5322`** (`cs5322`).
The `oracle` OS password and the `SYSTEM` password are in the group's Oracle information
sheet; **never put them in this repository**.  Change both as that sheet describes.

## 1. Log in

```bash
ssh -J <SoC ID>@stujump.comp.nus.edu.sg oracle@cs5322-5-i.comp.nus.edu.sg
```

Add `-L 1521:cs5322-5-i.comp.nus.edu.sg:1521` if you also want to connect from SQL Developer on
your own computer (host `localhost`, port `1521`, service name `cs5322`).

## 2. Start the database (after every VM restart)

Nothing starts automatically.  Check first:

```bash
ps -ef | grep -E 'ora_pmon|tnslsnr' | grep -v grep
```

If nothing is listed:

```bash
sqlplus / as sysdba <<'EOF'
startup
alter pluggable database CS5322 open;
show pdbs
exit
EOF
lsnrctl start
```

* `show pdbs` must list `CS5322` as `READ WRITE`.  A PDB opens by itself after `startup` only if its
  state was saved.  On the group VM the state of `CS5322` is saved as `OPEN` (check with
  `select con_name, state from dba_pdb_saved_states;`; `alter pluggable database CS5322 save state;`
  was run again on 2026-10-02), so the explicit `open` above is only a safeguard; an
  `ORA-65019: pluggable database already open` can be ignored.  Connections fail while the PDB is
  closed.
* The service registers with the listener within about a minute.  Check with
  `lsnrctl status | grep -i -A1 'service "cs5322"'` (expect `status READY`).

## 3. Copy the scripts to the VM

From the repository folder on your computer (the target directory must exist):

```bash
ssh -J <SoC ID>@stujump.comp.nus.edu.sg oracle@cs5322-5-i.comp.nus.edu.sg "mkdir -p ~/p1_v3"
scp -J <SoC ID>@stujump.comp.nus.edu.sg [0-9]*.sql demo.sql oracle@cs5322-5-i.comp.nus.edu.sg:p1_v3/
```

The `scp` destination needs the `host:path` form; without the colon it creates a *local* file
named like the host.

## 4. Deploy and verify (a few seconds)

```bash
cd ~/p1_v3 && mkdir -p logs && sqlplus /nolog @00_run_all.sql
grep -h "^===" logs/*.log
```

Expected: every `=== ... ===` line says `PASS`, `0 failed` (190 checks in total).  `00_run_all.sql`
drops and recreates all project tables; accounts and roles are kept.  Individual steps can be run
by hand in the order given in the README.  `04b_show_predicates.sql` prints the predicate each
policy generates; `10_mutation_check.sql` (optional) switches two policies off to prove that the
tests fail, then restores them.

## 5. Demonstration (Week 9)

Run `sqlplus /nolog @demo.sql` (without `-s`, so statements are echoed).  The script logs in as
real users, shows the effect of the policies, and restores the data at its end.  Suggested
commentary, in order:

1. **alice** - fail closed before an identity is set; own rows only; draft grade hidden; cannot
   become `bob` (`ORA-20002`); cannot write.
2. **prof_lee** - class list plus residents of his residence (Carol); draft vs released grade;
   `ORA-28115` when publishing or grading another professor's student; fellow view.
3. **prof_wong** - another residence; his ended fellowship grants nothing.
4. **admin_comp** - own department; publishes a grade; `ORA-28115` on a Business course.
5. **finance1** - e-mail column masked (column-level VPD); no grades (`ORA-00942`).
6. **housing1** - all allocations, nothing academic.
7. **uni_admin** - read-only oversight; audit trail shows the grade change with the real actor.

Extra, if asked what a DBA mistake would do: `sqlplus /nolog @09_defense_in_depth.sql`.
To show that SYS is exempt (a limitation): `sqlplus / as sysdba`, `alter session set container =
CS5322;`, `select count(*) from CS5322_P1.student;` returns 3 without any identity.

## 6. Copy the evidence back

```bash
scp -J <SoC ID>@stujump.comp.nus.edu.sg oracle@cs5322-5-i.comp.nus.edu.sg:p1_v3/logs/*.log ./logs/
```

## 7. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `ORA-12541: no listener` | `lsnrctl start` |
| `ORA-12514` / `ORA-12154` to `cs5322` | PDB closed (step 2) or service not registered yet - wait a minute |
| `ORA-01109: database not open` / `ORA-01034` | `sqlplus / as sysdba` then `startup` |
| `ORA-28000: account is locked` | re-run `02_users_roles.sql` as SYSDBA (resets and unlocks) |
| `ORA-01017` on a demo user | re-run `02_users_roles.sql` |
| `ORA-28113` | a policy predicate is invalid; run `06_verification.sql` and read the first failure |
| `ORA-00942` for a table you expect to see | the role has no grant (by design) or `02` was not re-run after a rebuild |
| Every count equals the full table | you are SYS (exempt from VPD); connect as `CS5322_P1` or a demo user |
| `SP2-0310: unable to open file` | start `sqlplus` in the folder that holds the scripts |
| Policies missing after a rebuild | `03_vpd_policies.sql` was not run as `CS5322_P1` |

## 8. Demo-day checklist

- [ ] Log in through `stujump` once the day before (VPN or campus network if required).
- [ ] Instance, PDB (`READ WRITE`) and listener running; `lsnrctl status` shows `cs5322`.
- [ ] `00_run_all.sql` run within the last day; all `=== ... ===` lines PASS.
- [ ] `demo.sql` rehearsed once; data restored (re-run 06 to be sure).
- [ ] Printed/PDF copy of the logs and the report in case the network fails.
