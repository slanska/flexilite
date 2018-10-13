Flexilite supports both scalar (individual) and vector (array) values.
This is defined by **rules.maxOccurrences** attribute of property definition.
**rules.maxOccurrences** = 1 corresponds to a scalar value. 
**rules.maxOccurrences** > 1 corresponds to a vector value, i.e. array (or list) of values.

**rules.minOccurrences** defines low bound. 0 is used for nullable (or optional)
values. For vector properties, it can be used to define specific low bound value.

Both scalar and vector values are treated almost identically, with few subtle differences.