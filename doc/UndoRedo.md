Flexilite tracks all changes made to both schema and data
in the [.change_log] table. This features is enabled by default for all kind of changes,
but can be turned off, entirely or per-class or per-property basis.
All changes are recorded with monotonically increasing IDs and timestamp.

This information can be used for multiple purposes:

- track change history and find who changed when and what
- undo database to the previous state 
- redo database from previous to a newer state ("re-play")
- get object state from "archive" on a certain date 