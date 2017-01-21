#### Text -> Symbol -> Enum -> Reference -> Enum -> Symbol -> Text

Generate new symbols for existing text values. Do not change existing text values
When value changes, replace it with symbol ID



#### Merge properties: many properties -> one property

Add computed property with expression
Preserve this property
Remove old properties

#### Split properties: one property -> many properties

Update properties
Remove old property

#### Scalar property -> array -> scalar property

Update property definition

#### Properties -> Nested object -> Reference -> Collection of references -> Reference -> Nested object -> Properties

#### Move selected objects to another class, with property mapping

#### Structurally split: one object -> many objects from different classes, referencing each other

#### Structurally merge: many objects, with join criteria (reference or value) -> one object

#### Change property: type, validation rules

#### Add computed property: expression

Existing data is not changed. Read returns result of expression, update deletes old value

#### Preserve computed property
flexi_prop_preserve

#### Save object graph (using JSON)

#### Retrieve object graph: collection, by filter and sorting criteria