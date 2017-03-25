All data and schema changes are always recorded in **[.change_log]** table. This table serves few purposes:

* traceability - who did what and when

* undo - any operation can be undone (rolled back). Schema undo can be processed separately from data updates

* TODO use attached database for .change_log table (up to 9 databases?), 1 database per year 