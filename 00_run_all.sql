-- Master checklist. Run each section separately because DBA and schema-owner privileges differ.
-- 1) As project schema owner: @01_schema_and_data.sql
-- 2) As DBA: @02_users_roles.sql (change CS5322_P1 if needed)
-- 3) As DBA/schema owner: @03_vpd_policies.sql
-- 4) As schema owner/DBA: @04_tests.sql
-- 5) During presentation: @demo.sql
PROMPT Project I scripts are intentionally separated by privilege boundary.
PROMPT Run the five commands documented above in order.

