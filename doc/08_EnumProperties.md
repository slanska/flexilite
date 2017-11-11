Enums in Flexilite are at first sight similar to references. They are also implemented via classes and objects.
Difference is in point of focus - enums are focused on _value_, treating referenced class as source collection
for that value, while reference is focused on referenced _object_. At this point enums in Flexilite are pretty
much the same as regular relations in RDBMS. That's why 'enums' and 'foreign keys' are interchangeable terms 
in Flexilite. 

Usually, when converting from standard database to Flexilite, foreign key definitions become enums on the first
step of conversion. On the next step, if needed, enums can be seamlessly converted to references.
