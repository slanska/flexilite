SQLite has amongst others the following powerful features:

* Triggers 
* Views
* Updateable views
* Partial indexes (indexes by expression)
* Dynamic data types 

These features were used to design first, prototypal, version of Flexilite,
version based on updateable views. We will call that version of Flexilite **view-based** 
Current, actual implementation is based on virtual tables and custom functions, 
so it is called **vtable-based**.  
Note: this document describes discontinued design and serves
sole purpose of introduction to Flexilite concept. Actual implementation
of Flexilite as of current design is based on virtual tables, though
many internal tables and other object keep their names and purpose.

To demonstrate how it was working, assume the following (simplified) database structure:

Short annotation:
* Names for internal Flexilite tables start from dot. This is to reduce chance of conflict 
 with user names
* [.classes] contains list of user defined classes. Class in Flexilite is,
in general, an equivalent of table in RDBMS.
* [.names_props] contains class properties and other *names* (explained here TODO)
* [.classes] and [.names_props] are used to generate views. One view corresponds to one class.
* Views are re-generated every time when class definition changes
* Views have INSTEAD OF triggers, i.e. allow all CRUD operations (create, read, update, delete)
* User can create, alter and drop classes and their properties. This will automatically regenerate related views.
* Properties have rules (e.g. type, nullability, max length etc.). These rules are defined
in class definition JSON and used as source to generate conditions in view's triggers

Let's consider the following simplified example.
There is class Contact, with the following properties (**bold properties** are mandatory):
* **Name** 
* **Phone**
* BirthDate
* Address 
* Email

For this class the following view would be generated:

```sqlite-sql
CREATE VIEW IF NOT EXISTS [ContactInfo] AS
SELECT id as id,
A as Name,
B as Phone,
C as BirthDate,
D as Address,
E as Email
from [.objects]
where ClassID = 1;

```