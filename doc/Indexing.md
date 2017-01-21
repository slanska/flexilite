Flexilite utilizes all available SQLite indexing features for better performance.
Indexing is per property and can be activated at any time.
The following indexing techniques are used:

* regular b-tree index. This is implemented via SQLite conditional index by setting a bit in **[.values].ctlv** field.
 If the bit is set, corresponding record is indexed.

* full text search index (FTS). This is enabled by another bit in **[.values].ctlv** field and handled by triggers.

* range index (using RTree). There is one RTree index per object. This index may include up to five pairs of Number, Integer or Date/Time properties.
