Normally (and by default), property values are stored in [.ref-values]
table, one row per value. This is what makes Flexilite very powerful
and flexible in a sense of data schema refactoring.

But this type of storage has 2 major drawbacks (and that's why EAV model
is heavily criticized):

- slow insert and delete, slower update and select
- disk space usage

To provide ultimate flexibility, Flexilite offers alternative to canonical EAV
and allows to store certain selected properties within object, as normal record fields.
This concept is called ****. 