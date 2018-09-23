Enums in Flexilite are at first sight similar to references. They are also implemented via classes and objects.
Difference is in point of focus - enums are focused on _value_, treating referenced class as source collection
for that value, while reference is focused on referenced _object_. At this point enums in Flexilite are pretty
much the same as regular relations in RDBMS. That's why 'enums' and 'foreign keys' are interchangeable terms 
in Flexilite. 

Any class can serve as a source for enum. It just needs to have at least one special property - 'text'.
If 'uid' special property is defined, it will be used as enum value, otherwise value of 'text'
property will be used.
Also, if special property 'pos' is defined, it will be used to sort list items in specific order.

Usually, when converting from standard database to Flexilite, foreign key definitions become enums on the first
step of conversion. On the next step, if needed, enums can be seamlessly converted to references.

Enum properties are defined using the following minimal JSON definition for class Orders:

```json
{
    "Status": {
      "rules": { 
        "type": "enum"},
       "enumDef": {
        "items": ["Completed", "Shipped", "Pending", "Processed", "BackOrdered", "Canceled"]
       }
    } 
}
```

This will result in creating a new class "Orders_Status", with special property 'text',
type of _SymName_. IDs of symname values will be used as enum values. Note that automatically created 
enum classes will be using global configuration to create corresponding virtual tables. 

Modified version of the same property:

```json
{
    "Status": {
      "rules": { 
        "type": "enum"},
       "enumDef": {
        "items": [{"id": "C", "text": "Completed"}, 
        {"id": "S", "text": "Shipped"}, 
        {"id": "G", "text": "Pending"}, 
        {"id": "P", "text": "Processed"},
         {"id": "B", "text": "BackOrdered"}, 
         {"id": "D", "text": "Canceled"}]
       }
    } 
}
```
In this case "id" property will use values "C", "S", "G" and so on instead of automatically 
generated name IDs.

Same enum class can be shared between multiple enum properties in different classes:

```json
{
    "PurchaseStatus": {
      "rules": { 
        "type": "enum"},
       "enumDef": {
        "classRef": "Order_Status"
       }
    } 
}
```
In this case "Order_Status" class should exist and should match requirement for enum class (i.e.
have at least special property "text"). Since this class was created automatically during "Status" property
processing, it matches all requirements.

To extend list of items use _flexi_data_ or direct:

```sqlite
insert into flexi_data () values ()
```
