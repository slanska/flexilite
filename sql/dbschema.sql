-- TODO Configurable page size?
-- PRAGMA page_size = 8192;
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = 1;
PRAGMA encoding = 'UTF-8';
PRAGMA recursive_triggers = 1;

------------------------------------------------------------------------------------------
-- .full_text_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.full_text_data] USING fts4 (

-- Class type. 0 for .names
  ClassID,

  -- Mapped columns. Mapping is different for different classes
  [X1], [X2], [X3], [X4], [X5],

-- to allow case insensitive search for different languages
  tokenize=unicode61
);

------------------------------------------------------------------------------------------
-- .names_props
------------------------------------------------------------------------------------------

/*
.names_props table has rows of 2 types - class properties and symbolic names. Column 'type' defines
which sort of entity it is: 0 - name, 1 - property name
The reason why 2 entities are combined into single table is to share IDs.
Objects may have attributes which are not defined in .classes.Data.properties
(if .classes.Data.allowNotDefinedProps = 1). Such attributes will be stored as IDs to .names table,
where ID will be for record with type = 0 (name). Normally, object properties defined in schema will be referencing
rows with type = 1 (property). Having both types of entities in one table allows shared space for names. Both types are exposed as
updatable views (.names and flexi_prop), so their exposition will not be much different from real table

When a new property is created, a new row gets inserted with Type = 1. Also, if needed row for Name (with Type = 0) gets inserted as well.

*/
CREATE TABLE IF NOT EXISTS [.names_props]
(
  ID           INTEGER             NOT NULL PRIMARY KEY               AUTOINCREMENT,

  /*
  0 - name
  1 - class property
   */
  Type         SMALLINT            NOT NULL CHECK (Type IN (0, 1)),

  /*
  Flag indicating that record was deleted. Records from .names table are never deleted to avoid problems with possible references
  Instead soft deleting is used. Such records are considered as source of NULL string during search. They are also deleted from
   */
  Deleted      BOOLEAN             NOT NULL                           DEFAULT 0,

  /*
Actual control flags (already applied).
These flags define indexing, logging and other property attributes
*/
  [ctlv]       INTEGER             NOT NULL                           DEFAULT 0,

  /*
  Planned/desired control flags which are not yet applied
  */
  [ctlvPlan]   INTEGER             NOT NULL                           DEFAULT 0,

  /*
  Name specific columns
  */

  /* Case sensitive
  Used as Value for Name type and as a text value for related types (e.g. enum)
  For type = 0 this value is required and must be unique. It also gets indexed in full text search index
  to allow FTS on objects with properties with type = PROP_TYPE_NAME
  */

  [Value]      TEXT COLLATE BINARY NULL CHECK (rtrim(ltrim([Value])) <> ''),

  /*
  These 2 columns are reserved for future to be used for semantic search.
 */
  PluralOf     INTEGER             NULL
    CONSTRAINT [fkNamesByPluralOf]
    REFERENCES [.names] ([ID]) ON DELETE SET NULL ON UPDATE RESTRICT,
  AliasOf      INTEGER             NULL
    CONSTRAINT [fkNamesByAliasOf]
    REFERENCES [.names] ([ID]) ON DELETE SET NULL ON UPDATE RESTRICT,

  /*
  Property specific columns
  */
  [ClassID]    INTEGER             NULL CONSTRAINT [fkClassPropertiesToClasses]
  REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE RESTRICT,

  /*
  ID of property name
  */
  [PropNameID] INTEGER             NULL CONSTRAINT [fkClassPropertiesToNames] REFERENCES [.names_props] ([NameID])
  ON DELETE RESTRICT ON UPDATE RESTRICT,

  /*
  Optional mapping for locked property (A-P)
   */
  [LockedCol]  CHAR                NULL CHECK ([LockedCol] IS NULL OR ([LockedCol] >= 'A' AND [LockedCol] <= 'P'))
);

CREATE TRIGGER IF NOT EXISTS [namesAfterInsert]
AFTER INSERT
  ON [.names_props]
FOR EACH ROW
  WHEN new.Value IS NOT NULL
BEGIN
  INSERT INTO [.full_text_data] (id, ClassID, X1) VALUES (-new.ID, 0, new.Value);
END;

CREATE TRIGGER IF NOT EXISTS [namesAfterUpdate]
AFTER UPDATE
  ON [.names_props]
FOR EACH ROW
  WHEN new.Value IS NOT NULL
BEGIN
  UPDATE [.full_text_data]
  SET X1 = new.Value
  WHERE id = -new.ID;
END;

CREATE TRIGGER IF NOT EXISTS [namesAfterDelete]
AFTER DELETE
  ON [.names_props]
FOR EACH ROW
  WHEN old.Value IS NOT NULL
BEGIN
  DELETE FROM [.full_text_data]
  WHERE id = -old.ID;
END;

-- .names specific indexes
CREATE UNIQUE INDEX IF NOT EXISTS [namesByValue]
  ON [.names_props] ([Value])
  WHERE [Value] IS NOT NULL;
CREATE INDEX IF NOT EXISTS [namesByAliasOf]
  ON [.names_props] ([AliasOf])
  WHERE AliasOf IS NOT NULL;
CREATE INDEX IF NOT EXISTS [namesByPluralOf]
  ON [.names_props] ([PluralOf])
  WHERE PluralOf IS NOT NULL;

-- flexi_prop specific indexes
CREATE UNIQUE INDEX IF NOT EXISTS [idxClassPropertiesByClassAndName]
  ON [.names_props]
  (ClassID, PropNameID)
  WHERE ClassID IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxClassPropertiesByMap]
  ON [.names_props]
  (ClassID, LockedCol)
  WHERE ClassID IS NOT NULL AND [LockedCol] IS NOT NULL;

/*
.names view
 */
CREATE VIEW IF NOT EXISTS [.names] AS
  SELECT
    ID AS NameID,
    Value,
    AliasOf,
    PluralOf
  FROM [.names_props]
  WHERE Type = 0;

CREATE TRIGGER IF NOT EXISTS [names_Insert]
INSTEAD OF INSERT
  ON [.names]
FOR EACH ROW
BEGIN
  INSERT INTO [.names_props] (Value, AliasOf, PluralOf, Type) VALUES (new.Value, new.AliasOf, new.PluralOf, 0);
END;

CREATE TRIGGER IF NOT EXISTS [names_Update]
INSTEAD OF UPDATE
  ON [.names]
FOR EACH ROW
BEGIN
  UPDATE [.names_props]
  SET Value = new.Value, AliasOf = new.Value, PluralOf = new.PluralOf
  WHERE ID = old.NameID;
END;

CREATE TRIGGER IF NOT EXISTS [names_Delete]
INSTEAD OF DELETE
  ON [.names]
FOR EACH ROW
BEGIN
  DELETE FROM [.names_props]
  WHERE ID = old.NameID;
END;

------------------------------------------------------------------------------------------
-- .access_rules
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.access_rules] (
  [UserRoleID] TEXT(32) NOT NULL,

  /*
  C - Class
  O - Object
  P - Property
  */
  [ItemType]   CHAR NOT NULL,

  /*
  H - hidden
  R - read only
  U - updateable
  A - can add
  D - can delete
  */
  [Access]     CHAR NOT NULL,

  /*
  ClassID or ObjectID or PropertyID
  */
  [ItemID]     INT  NOT NULL,
  CONSTRAINT [sqlite_autoindex_AccessRules_1] PRIMARY KEY ([UserRoleID], [ItemType], [ItemID])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxAccessRulesByItemID]
  ON [.access_rules] ([ItemID]);

------------------------------------------------------------------------------------------
-- .change_log
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.change_log] (
  [ID]        INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [TimeStamp] DATETIME NOT NULL             DEFAULT (julianday('now')),
  [OldKey]    TEXT     NULL,
  [OldValue]  JSON1,

  -- Format for key and oldkey
  -- @ClassID.objectID#propertyID[propertyIndex]
  -- Example: @23.188374#345[11]
  [KEY]       TEXT     NULL,
  [Value]     JSON1,

  [ChangedBy] GUID     NULL
);

CREATE TRIGGER IF NOT EXISTS trigChangeLogAfterInsert
AFTER INSERT
  ON [.change_log]
FOR EACH ROW
  WHEN new.ChangedBy IS NULL
BEGIN
  UPDATE [.change_log]
  SET ChangedBy = var('CurrentUserID')
  WHERE ID = new.ID;
END;

------------------------------------------------------------------------------------------
-- .classes
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.classes] (
  [ClassID]     INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  [NameID]      INTEGER NOT NULL CONSTRAINT [fkClassesNameID]
  REFERENCES [.names_props] ([ID]) ON DELETE RESTRICT ON UPDATE RESTRICT,

  -- System class is used internally by the system and cannot be changed or deleted by end-user
  [SystemClass] BOOL    NOT NULL             DEFAULT 0,

  -- Control bitmask for objects belonging to this class
  [ctloMask]    INTEGER NOT NULL             DEFAULT 0,

  AccessRules   JSON1   NULL,

  /*
  IClassDefinition. Can be set to null for a newly created class
  */
  Data          JSON1   NULL,

  /*
  Whether to create corresponding virtual table or not
   */
  VirtualTable  BOOL    NOT NULL             DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClasses_byNameID]
  ON [.classes] ([NameID]);

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterInsert]
AFTER INSERT
  ON [.classes]
FOR EACH ROW
BEGIN
  -- TODO Fix unresolved names : mixins and reference properties

  INSERT INTO [.change_log] ([KEY], [Value]) VALUES (
    printf('@%s', new.ClassID),
    json_set('{}',
             "$.NameID", new.NameID,
             "$.SystemClass", new.SystemClass,
             "$.ViewOutdated", new.ViewOutdated,
             "$.ctloMask", new.ctloMask,
             "$.Data", new.Data,
             "$.VirtualTable", new.VirtualTable,

             CASE WHEN new.AccessRules IS NULL
               THEN NULL
             ELSE "$.AccessRules" END, new.AccessRules
    )
  );
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdate]
AFTER UPDATE
  ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue], [KEY], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [KEY],
      [Value]
    FROM (
      SELECT
        '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT) AS [OldKey],

        json_set('{}',
                 "$.NameID", old.NameID,
                 "$.SystemClass", old.SystemClass,
                 "$.ViewOutdated", old.ViewOutdated,
                 "$.ctloMask", old.ctloMask,
                 "$.Data", old.Data,
                 "$.VirtualTable", old.VirtualTable,

                 CASE WHEN old.AccessRules IS NULL
                   THEN NULL
                 ELSE "$.AccessRules" END, old.AccessRules
        )                                                     AS [OldValue],

        '@' || CAST(new.ClassID AS TEXT)                      AS [KEY],
        json_set('{}',
                 "$.NameID", new.NameID,
                 "$.SystemClass", new.SystemClass,
                 "$.ViewOutdated", new.ViewOutdated,
                 "$.ctloMask", new.ctloMask,
                 "$.Data", new.Data,
                 "$.VirtualTable", new.VirtualTable,

                 CASE WHEN new.AccessRules IS NULL
                   THEN NULL
                 ELSE "$.AccessRules" END, new.AccessRules
        )
                                                              AS [Value]
    )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterDelete]
AFTER DELETE
  ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue]) VALUES (
    printf('@%s', old.ClassID),

    json_set('{}',
             "$.NameID", old.NameID,
             "$.SystemClass", old.SystemClass,
             "$.ViewOutdated", old.ViewOutdated,
             "$.ctloMask", old.ctloMask,
             "$.Data", old.Data,
             "$.VirtualTable", old.VirtualTable,

             CASE WHEN old.AccessRules IS NULL
               THEN NULL
             ELSE "$.AccessRules" END, old.AccessRules
    )
  );
END;

------------------------------------------------------------------------------------------
-- [flexi_class] view
------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [flexi_class] AS
  SELECT
    ClassID,
    (SELECT [Value]
     FROM [.names_props]
     WHERE ID = [.classes].NameID
     LIMIT 1)    AS Class,
    Data         AS Definition,
    VirtualTable AS AsTable
  FROM [.classes];

CREATE TRIGGER IF NOT EXISTS [trig_Flexi_Class_Insert]
INSTEAD OF INSERT
  ON [flexi_class]
FOR EACH ROW
BEGIN
  SELECT flexi('create class', new.Class, new.Definition, new.AsTable);
END;

CREATE TRIGGER IF NOT EXISTS [trig_Flexi_Class_Update]
INSTEAD OF UPDATE
  ON [flexi_class]

FOR EACH ROW
BEGIN
  SELECT flexi('rename class', old.Class, new.Class);
  SELECT flexi('alter class', new.Class, new.Definition, new.AsTable);
END;

CREATE TRIGGER IF NOT EXISTS [trig_Flexi_Class_Delete]
INSTEAD OF DELETE
  ON [flexi_class]
FOR EACH ROW
BEGIN
  SELECT flexi('drop class', old.Class);
END;

------------------------------------------------------------------------------------------
-- [flexi_prop] view
------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [flexi_prop] AS
  SELECT
    cp.[ID]                                                          AS PropertyID,
    c.ClassID                                                        AS ClassID,
    c.Class                                                          AS Class,
    cp.[PropNameID]                                                  AS NameID,
    (SELECT [Value]
     FROM [.names_props] n
     WHERE n.ID = PropNameID
     LIMIT 1)                                                        AS Property,
    cp.ctlv                                                          AS ctlv,
    -- TODO Needed
    cp.ctlvPlan                                                      AS ctlvPlan,
    -- TODO Needed
    (json_extract(c.Definition, printf('$.properties.%d', cp.[ID]))) AS Definition,
    cp.RefClassID                                                    AS RefClassID,
    -- TODO Needed
    cp.RefPropID                                                     AS RefPropID -- TODO Needed

  FROM [.names_props] cp
    JOIN [flexi_class] c ON cp.ClassID = c.ClassID
  WHERE cp.Type = 1 AND cp.Deleted = 0;

CREATE TRIGGER IF NOT EXISTS trigFlexi_Prop_Insert
INSTEAD OF INSERT
  ON [flexi_prop]
FOR EACH ROW
BEGIN
  SELECT flexi('create property', new.Class, new.Property, new.Definition);

  INSERT OR IGNORE INTO [.names_props] (Value, Type) VALUES (new.Name, 0);
  INSERT INTO [.names_props] (Type, PropNameID, ClassID, ctlv, ctlvPlan, RefClassID, RefPropID)
  VALUES (1, (SELECT ID
              FROM [.names_props]
              WHERE Value = new.Name
              LIMIT 1),
          new.ClassID, new.ctlv, new.ctlvPlan, new.RefClassID, new.RefPropID);

  -- TODO Fix unresolved references

  --   select * from [.classes] where json_extract(Data, '$.properties')
  --   update [.classes] set Data = json_set(Data, ) where json_extract(Data, '$.properties').
END;

CREATE TRIGGER IF NOT EXISTS trigFlexi_Prop_Update
INSTEAD OF UPDATE
  ON [flexi_prop]
FOR EACH ROW
BEGIN
  SELECT flexi('rename property', new.Class, old.Property, new.Property);
  SELECT flexi('alter property', new.Class, new.Property, new.Definition);

  INSERT OR IGNORE INTO [.names_props] (Value, Type, RefClassID, RefPropID)
  VALUES (new.Name, 0, new.RefClassID, new.RefPropID);
  UPDATE [.names_props]
  SET PropNameID = (SELECT ID
                    FROM [.names_props]
                    WHERE Value = new.Name
                    LIMIT 1),
    ClassID      = new.ClassID, ctlv = new.ctlv, ctlvPlan = new.ctlvPlan
  WHERE ID = old.PropertyID;
END;

CREATE TRIGGER IF NOT EXISTS trigFlexi_Prop_Delete
INSTEAD OF DELETE
  ON [flexi_prop]
FOR EACH ROW
BEGIN
  SELECT flexi('drop property', old.Class, old.Property);

  DELETE FROM [.names_props]
  WHERE ID = old.PropertyID;

  DELETE FROM [.ref-values]
  WHERE [PropertyID] = old.PropertyID;
END;

------------------------------------------------------------------------------------------
-- [.objects]
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.objects] (
  [ObjectID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassID]  INTEGER NOT NULL CONSTRAINT [fkObjectsClassIDToClasses]
  REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE CASCADE,

  /*
  This is bit mask which regulates index storage.
  Bit 0: this object is a WEAK object and must be auto deleted after last reference to this object gets deleted.
  Bit 49: DON'T track changes

  */
  [ctlo]     INTEGER,

  /*
  Reserved for future use. Will be used tp store certain property values directly with object
   */
  [Data]     JSON1   NULL,

  /*
  Optional data for object/row (font/color/formulas etc. customization)
  */
  [ExtData]  JSON1   NULL
);

CREATE INDEX IF NOT EXISTS [idxObjectsByClassSchema]
  ON [.objects] ([ClassID]);

-- Triggers
CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterInsert]
AFTER INSERT
  ON [.objects]
FOR EACH ROW
BEGIN
  -- TODO force ctlo. Will it work?
  UPDATE [.objects]
  SET ctlo = coalesce(new.ctlo, (SELECT [ctlo]
                                 FROM [.classes]
                                 WHERE [ClassID] = new.[ClassID]))
  WHERE ObjectID = new.[ObjectID];

  INSERT INTO [.change_log] ([KEY], [Value])
    SELECT
      printf('@%s.%s', new.[ClassID], new.[ObjectID]),
      json_set('{}',
               CASE WHEN new.Data IS NULL
                 THEN NULL
               ELSE '$.Data' END, new.Data,

               CASE WHEN new.ExtData IS NULL
                 THEN NULL
               ELSE '$.ExtData' END, new.ExtData,

               CASE WHEN new.ctlo IS NULL
                 THEN NULL
               ELSE '$.ctlo' END, new.ctlo
      )
    WHERE new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49);
END;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdate]
AFTER UPDATE
  ON [.objects]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue], [KEY], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [KEY],
      [Value]
    FROM
      (SELECT
         '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT)
         || '.' || CAST(nullif(old.ObjectID, new.[ObjectID]) AS TEXT) AS [OldKey],

         json_set('{}',

                  CASE WHEN new.Data IS NULL
                    THEN NULL
                  ELSE '$.Data' END, new.Data,

                  CASE WHEN new.ExtData IS NULL
                    THEN NULL
                  ELSE '$.ExtData' END, new.ExtData,

                  CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL
                    THEN NULL
                  ELSE '$.ctlo' END, new.ctlo
         )                                                            AS [OldValue],
         printf('@%s.%s', new.[ClassID], new.[ObjectID])              AS [KEY],
         json_set('{}',
                  CASE WHEN nullif(new.Data, old.Data) IS NULL
                    THEN NULL
                  ELSE '$.Data' END, old.Data,

                  CASE WHEN nullif(new.ExtData, old.ExtData) IS NULL
                    THEN NULL
                  ELSE '$.ExtData' END, new.ExtData,

                  CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL
                    THEN NULL
                  ELSE '$.ctlo' END, old.ctlo
         )
                                                                      AS [Value]
      )
    WHERE (new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49))
          AND ([OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL);
END;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdateOfClassID_ObjectID]
AFTER UPDATE OF [ClassID], [ObjectID]
  ON [.objects]
FOR EACH ROW
BEGIN
  -- Force updating indexes for direct columns
  UPDATE [.objects]
  SET ctlo = new.ctlo
  WHERE ObjectID = new.[ObjectID];

  -- Cascade update values
  UPDATE [.ref-values]
  SET ObjectID = new.[ObjectID]
  WHERE ObjectID = old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID);

  -- and shifted values
  UPDATE [.ref-values]
  SET ObjectID = (1 << 62) | new.[ObjectID]
  WHERE ObjectID = (1 << 62) | old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID);

  -- Update back references
  UPDATE [.ref-values]
  SET [Value] = new.[ObjectID]
  WHERE [Value] = old.ObjectID AND ctlv IN (0, 10) AND new.[ObjectID] <> old.ObjectID;
END;


CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterDelete]
AFTER DELETE
  ON [.objects]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s', old.[ClassID], old.[ObjectID]),
      json_set('{}',
               CASE WHEN old.Data IS NULL
                 THEN NULL
               ELSE '$.Data' END, old.Data,

               CASE WHEN old.ExtData IS NULL
                 THEN NULL
               ELSE '$.ExtData' END, old.ExtData,

               CASE WHEN old.ctlo IS NULL
                 THEN NULL
               ELSE '$.ctlo' END, old.ctlo
      )

    WHERE old.[ctlo] IS NULL OR old.[ctlo] & (1 << 49);

  -- Delete all objects that are referenced from this object and marked for cascade delete (ctlv = 10)
  DELETE FROM [.objects]
  WHERE ObjectID IN (SELECT Value
                     FROM [.ref-values]
                     WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID) AND ctlv = 10);

  -- Delete all reversed references
  DELETE FROM [.ref-values]
  WHERE [Value] = ObjectID AND [ctlv] IN (0, 10);

  -- Delete all Values
  DELETE FROM [.ref-values]
  WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID);
END;

------------------------------------------------------------------------------------------
-- .range_data
------------------------------------------------------------------------------------------

CREATE VIRTUAL TABLE IF NOT EXISTS [.range_data] USING rtree (
  [ObjectID],

  [ClassID0], [ClassID1],

  [A0], [A1],
  [B0], [B1],
  [C0], [C1],
  [D0], [D1]
);

------------------------------------------------------------------------------------------
-- Values
-- This table stores EAV individual values in a canonical form - one DB row per value
-- Also, this table keeps list of object-to-object references. Direct reference is ObjectID.PropertyID -> Value
-- where Value is ID of referenced object.
-- Reversed reference is from Value -> ObjectID.PropertyID
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.ref-values] (
  [ObjectID]   INTEGER NOT NULL,
  [PropertyID] INTEGER NOT NULL,
  [PropIndex]  INTEGER NOT NULL DEFAULT 0,
  [Value]              NOT NULL,

  /*
  ctlv is used for index control. Possible values:
      bit 0 - Index
      bits 1-3 - reference
          2(3 as bit 0 is set) - regular ref
          4(5) - ref: A -> B. When A deleted, delete B
          6(7) - when B deleted, delete A
          8(9) - when A or B deleted, delete counterpart
          10(11) - cannot delete A until this reference exists
          12(13) - cannot delete B until this reference exists
          14(15) - cannot delete A nor B until this reference exist

      bit 4 (16) - full text data
      bit 5 (32) - range data
      bit 6 (64) - DON'T track changes
      bit 7 (128) - unique index
  */
  [ctlv]       INTEGER,
  /*
Optional data for cell (font/color/format etc. customization)
*/
  [ExtData]    JSON1   NULL,

  CONSTRAINT [] PRIMARY KEY ([ObjectID], [PropertyID], [PropIndex])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxClassReversedRefs]
  ON [.ref-values] ([Value], [PropertyID])
  WHERE [ctlv] & 14;

CREATE INDEX IF NOT EXISTS [idxValuesByPropValue]
  ON [.ref-values] ([PropertyID], [Value])
  WHERE ([ctlv] & 1);

CREATE UNIQUE INDEX IF NOT EXISTS [idxValuesByPropUniqueValue]
  ON [.ref-values] ([PropertyID], [Value])
  WHERE ([ctlv] & 128);

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterInsert]
AFTER INSERT
  ON [.ref-values]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([KEY], [Value])
    SELECT
      printf('.%s/%s[%s]#%s',
             new.[ObjectID], new.[PropertyID], new.PropIndex,
             new.ctlv),
      new.[Value]
    WHERE (new.[ctlv] & 64) <> 64;

  INSERT INTO [.full_text_data] ([PropertyID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[PropertyID]),
      printf('#%s#', new.[ObjectID]),
      printf('#%s#', new.[PropIndex]),
      new.[Value]
    WHERE new.ctlv & 16 AND typeof(new.[Value]) = 'text';
END;

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterUpdate]
AFTER UPDATE
  ON [.ref-values]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue], [KEY], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [KEY],
      [Value]
    FROM
      (SELECT
         /* Each piece of old key is formatted independently so that for cases when old and new value is the same,
         result will be null and will be placed to OldKey as empty string */
         printf('%s%s%s%s',
                '.' || CAST(nullif(old.[ObjectID], new.[ObjectID]) AS TEXT),
                '/' || CAST(nullif(old.[PropertyID], new.[PropertyID]) AS TEXT),
                '[' || CAST(nullif(old.[PropIndex], new.[PropIndex]) AS TEXT) || ']',
                '#' || CAST(nullif(old.[ctlv], new.[ctlv]) AS TEXT)
         )                                                         AS [OldKey],
         old.[Value]                                               AS [OldValue],
         printf('.%s/%s[%s]%s',
                new.[ObjectID], new.[PropertyID], new.PropIndex,
                '#' || CAST(nullif(new.ctlv, old.[ctlv]) AS TEXT)) AS [KEY],
         new.[Value]                                               AS [Value])
    WHERE (new.[ctlv] & 64) <> 64 AND ([OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL);

  -- Process full text data based on ctlv
  DELETE FROM [.full_text_data]
  WHERE
    old.ctlv & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ClassID] MATCH printf('#%s#', old.[ClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);

  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[PropertyID]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      printf('#%s#', new.[PropIndex]),
      new.[Value]
    WHERE new.ctlv & 16 AND typeof(new.[Value]) = 'text';
END;

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterDelete]
AFTER DELETE
  ON [.ref-values]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue])
    SELECT
      printf('.%s/%s[%s]',
             old.[ObjectID], old.[PropertyID],
             old.PropIndex),
      old.[Value]
    WHERE (old.[ctlv] & 64) <> 64;

  -- Delete weak referenced object in case this Value record was last reference to that object
  DELETE FROM [.objects]
  WHERE old.ctlv IN (3) AND ObjectID = old.Value AND
        (ctlo & 1) = 1 AND (SELECT count(*)
                            FROM [.ref-values]
                            WHERE [Value] = ObjectID AND ctlv IN (3)) = 0;

  -- Process full text data based on ctlv
  DELETE FROM [.full_text_data]
  WHERE
    old.[ctlv] & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);
END;

--------------------------------------------------------------------------------------------
-- .ValuesEasy
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.ValuesEasy] AS
  SELECT
    NULL AS [NameID],
    NULL AS [ObjectID],
    NULL AS [PropertyName],
    NULL AS [PropertyIndex],
    NULL AS [Value],
    NULL AS [ExtData];

CREATE TRIGGER IF NOT EXISTS trigValuesEasy_Insert
INSTEAD OF INSERT
  ON [.ValuesEasy]
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO [.objects] (ClassID, ObjectID, ctlo)
    SELECT
      c.ClassID,
      new.ObjectID,
      ctlo = c.ctloMask

    FROM [.classes] c, [flexi_prop] p
    WHERE new.ObjectID IS NOT NULL AND c.[ClassID] = p.[ClassID] AND c.NameID = new.NameID AND p.Name = new.PropertyName
          AND (p.[ctlv] & 14) = 0 AND p.ColumnAssigned IS NOT NULL AND new.PropertyIndex = 0;

  INSERT OR REPLACE INTO [.ref-values] (ObjectID, PropertyID, PropIndex, [Value], ctlv, RefValueID)
    SELECT
      CASE WHEN new.PropertyIndex > 20
        THEN new.[ObjectID] | (1 << 62)
      ELSE new.[ObjectID] END,
      p.PropertyID,
      new.PropertyIndex,
      new.[Value],
      p.[ctlv],
      new.ExtData
    FROM [.classes] c, [.vw_class_properties] p
    WHERE c.[ClassID] = p.[ClassID] AND c.NameID = new.NameID AND p.PropertyName = new.PropertyName AND
          p.ColumnAssigned IS NULL;
END;

-- END --