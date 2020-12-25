Flexilite utilizes all available SQLite indexing features for better performance.
Indexing is per property and can be activated at any time.
The following indexing techniques are used:

* regular b-tree index. This is implemented via SQLite conditional index by setting a bit in **[.values].ctlv** field.
 If the bit is set, corresponding record is indexed.

* full text search index (FTS). This is enabled by another bit in **[.values].ctlv** field and handled by triggers.
Flexilite support full text indexing and search ("fuzzy search"), using
SQLite [FTS4 module](https://sqlite.org/fts3.html).

* range index (using RTree). There is one RTree index per object. This index may include up to five pairs of Number, Integer or Date/Time properties.
For more details refer to SQLite documentation on [RTree indexes](https://sqlite.org/rtree.html).

Indexes are defined in class definition, either for individual properties, or in indexes attributes of ClassDef.
When class definition is being processed, index definitions are analyzed and optimized.
Result of indexes optimization gets always stored in ClassDef.indexes, which is served as the only source
of truth for all index definitions for the given class.

During optimization phase, Flexilite may decide to convert one index type to another, 
for better performance and storage.

For example, non-unique indexes on numeric and date/time columns highly likely will be converted to
RTREE index. Another example, non-unique indexes on long text properties (> 255) will be converted to
full text indexes.

Both rtree and full text indexes has limits on maximum number of properties to be included - 5 dimensions for
RTREE and 5 properties for full text. In case of rtree, it means that for single property indexing, where
the same property is used for low and high boundaries, maximum 5 properties can be used for indexing.

Example of defining index on property level:

```json
			{
				"rules": {
					"minOccurrences": 1,
					"maxOccurrences": 1,
					"type": "integer"
				},
				"index": "unique"
			}
``` 

"index" attribute may be any of the following:

- **unique**
Unique index on the given property will be created. If property is nullable (i.e. _rules.minOccurrences_ = 0)
this index will be partial, and non-existing (_null_) values will be excluded from indexing.

- **index**
This is an ordinary, non-unique index. Similarly to unique index, nullable properties will be excluded from 
indexing. Numeric and date/time properties may be converted to range index (if capacity RTREE dimension
capacity allows). Long text properties (with _rules.maxLength_ > 255) may be converted to ful text index (if full'
text index capacity allows)

- **fulltext**
This is applicable to text properties only. For other property types it will be treated as regular index.

- **range**
This is applicable to only numeric and date/time properties and only if range index capacity allows.
For other cases it works as a regular index. Also, note that when defined on individual property
both low and high bounds of rtree dimension will be set to the same property value. To define pure dimension 
(with 2 different properties, for example LowLatitude and HighAttitude), use _indexes.rangeIndex_



