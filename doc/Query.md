Querying is implemented as 2 custom SQLite functions (in 3 variations)

###### flexi_query(queryOptions)

**queryOptions**
* select
* from - class name.
* where
* skip
* limit
* orderBy

**where**

**Example**:

```` json
{
    "select":
    {
        "lines":
        {
            "$out": "auto" | "embed" | "peer" | "merge"
             ... other query settings (select, where, limit etc.)
        },
        "customerId": "Customer ID",
        "customerId":
        {
            "$as": "Customer ID"
        }
    },
    "from": "Orders",
    "where" : {
        "id": 100500,
        "$or":
        {
            "status": { "$in": ['A', 'B']},
            "createDate": { "$ge": "2012-04-23T18:25:43.511Z"}
        },
        "lines":
        {
            "product":
            {
                "name": { "$like", "%chair%"}
            }
        }
    },
    "skip": 0,
    "limit": 100,
    "orderBy":
    {
        "createDate": "DESC"
    }
    // or
    "orderBy": "createDate"
    // or
    "orderBy": ["customerId", "createDate"]
}
````

For references and nested objects it is possible to specify

###### flexi_query(from, where, orderBy?)
###### flexi_query_batch(queryOptions[])
