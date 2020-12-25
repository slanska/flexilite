--PRAGMA journal_mode = WAL; -- TODO run separately, not in transaction
PRAGMA foreign_keys = 1;
PRAGMA encoding = 'UTF-8';
PRAGMA recursive_triggers = 1;

------------------------------------------------------------------------------------------
-- .full_text_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.full_text_data] USING fts4 (

-- Class ID. 0 for .sym_names
  ClassID,

  /*
  Mapped columns. Mapping is different for different classes.
  There are following typical cases for full text search:
  - Search for text for all occurrences in all classes
  (ClassID is omitted)
  - Search for all occurrences in specific class
  - Search on certain indexed text properties in specific class
   */
  [X1], [X2], [X3], [X4], [X5],

  -- to allow case insensitive search for different languages
  tokenize=unicode61
);

------------------------------------------------------------------------------------------
-- .sym_names
------------------------------------------------------------------------------------------

/*
Symbolic names - pairs of ID and text Value
 */
CREATE TABLE IF NOT EXISTS [.sym_names]
(
  ID       INTEGER             NOT NULL PRIMARY KEY               AUTOINCREMENT,

  /*
  Flag indicating that record was deleted. Records from .sym_names table are never deleted to avoid problems with possible references
  Instead soft deleting is used. Such records are considered as source of NULL string during search. They are also deleted from full text
  index
   */
  Deleted  BOOLEAN             NOT NULL                           DEFAULT 0,

  /*
  Name specific columns
  */

  /* Case sensitive
  Used as Value for Name type and as a text value for related types (e.g. enum)
  For type = 0 this value is required and must be unique. It also gets indexed in full text search index
  to allow FTS on objects with properties with type = PROP_TYPE_NAME
  */

  [Value]  TEXT COLLATE BINARY NOT NULL CHECK (rtrim(ltrim([Value])) <> ''),

  /*
  These 2 columns are reserved for future to be used for semantic search.
  */
  PluralOf INTEGER             NULL
    CONSTRAINT [fkNamesByPluralOf]
    REFERENCES [.sym_names] ([ID])
      ON DELETE SET NULL
      ON UPDATE RESTRICT,
  AliasOf  INTEGER             NULL
    CONSTRAINT [fkNamesByAliasOf]
    REFERENCES [.sym_names] ([ID])
      ON DELETE SET NULL
      ON UPDATE RESTRICT

);

CREATE TRIGGER IF NOT EXISTS [sym_namesAfterInsert]
  AFTER INSERT
  ON [.sym_names]
  FOR EACH ROW
  WHEN new.Value IS NOT NULL
BEGIN
  INSERT INTO [.full_text_data] (docid, ClassID, X1) VALUES (-new.ID, 0, new.Value);
END;

CREATE TRIGGER IF NOT EXISTS [sym_namesAfterUpdate]
  AFTER UPDATE
  ON [.sym_names]
  FOR EACH ROW
  WHEN new.Value IS NOT NULL
BEGIN
  UPDATE [.full_text_data]
  SET X1 = new.Value
  WHERE docid = -new.ID;
END;

CREATE TRIGGER IF NOT EXISTS [sym_namesAfterDelete]
  AFTER DELETE
  ON [.sym_names]
  FOR EACH ROW
  WHEN old.Value IS NOT NULL
BEGIN
  DELETE FROM [.full_text_data]
  WHERE docid = -old.ID;
END;

CREATE UNIQUE INDEX IF NOT EXISTS [sym_namesByValue]
  ON [.sym_names] ([Value])
  WHERE [Value] IS NOT NULL;
CREATE INDEX IF NOT EXISTS [sym_namesByAliasOf]
  ON [.sym_names] ([AliasOf])
  WHERE AliasOf IS NOT NULL;
CREATE INDEX IF NOT EXISTS [sym_namesByPluralOf]
  ON [.sym_names] ([PluralOf])
  WHERE PluralOf IS NOT NULL;

--------------------------------------------------------------------------------
--  .names view
--------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.names] AS
  SELECT
    ID AS NameID,
    Value,
    AliasOf,
    PluralOf
  FROM [.sym_names];

CREATE TRIGGER IF NOT EXISTS [names_Insert]
  INSTEAD OF INSERT
  ON [.names]
  FOR EACH ROW
BEGIN
  INSERT INTO [.sym_names] (Value, AliasOf, PluralOf) VALUES (new.Value, new.AliasOf, new.PluralOf);
END;

CREATE TRIGGER IF NOT EXISTS [names_Update]
  INSTEAD OF UPDATE
  ON [.names]
  FOR EACH ROW
BEGIN
  UPDATE [.sym_names]
  SET Value = new.Value, AliasOf = new.Value, PluralOf = new.PluralOf
  WHERE [.sym_names].ID = old.NameID;
END;

CREATE TRIGGER IF NOT EXISTS [names_Delete]
  INSTEAD OF DELETE
  ON [.names]
  FOR EACH ROW
BEGIN
  DELETE FROM [.sym_names]
  WHERE [.sym_names].ID = old.NameID;
END;

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
  REFERENCES [.sym_names] ([ID])
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,

  /*
  System class is used internally by the system and cannot be changed or deleted by end-user
   (via 'flexi' function)
   */
  [SystemClass] BOOL    NOT NULL             DEFAULT 0,

  -- Control bitmask for objects belonging to this class
  [ctloMask]    INTEGER NOT NULL             DEFAULT 0,

  /*
  Normalized IClassDefinition. Can be set to null for a newly created class.
  Properties and referenced classes are defined by IDs
  */
  Data          JSON1   NULL,

  /*
  Whether to create corresponding virtual table or not
   */
  VirtualTable  BOOL    NOT NULL             DEFAULT 0,

  /*
  Set to 1 when class uses column mapping (fields A-P in .objects table)
  Initially, columns are mapped but not activated.
  TODO config setting to set default value for ColMapActive for new classes
  */
  ColMapActive  BOOL    NOT NULL             DEFAULT 0,

  /*
  Class is marked as deleted
   */
  Deleted       BOOLEAN NOT NULL             DEFAULT 0,

  /*
  Pre-computed vtypes for mapped columns
   */
  vtypes        INTEGER NOT NULL             DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClasses_byNameID]
  ON [.classes] ([NameID])
  WHERE Deleted = 0;

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
             "$.ctloMask", new.ctloMask,
             "$.Data", new.Data,
             "$.VirtualTable", new.VirtualTable

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
                 "$.ctloMask", old.ctloMask,
                 "$.Data", old.Data,
                 "$.VirtualTable", old.VirtualTable


        )                                                     AS [OldValue],

        '@' || CAST(new.ClassID AS TEXT)                      AS [KEY],
        json_set('{}',
                 "$.NameID", new.NameID,
                 "$.SystemClass", new.SystemClass,
                 "$.ctloMask", new.ctloMask,
                 "$.Data", new.Data,
                 "$.VirtualTable", new.VirtualTable


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
             "$.ctloMask", old.ctloMask,
             "$.Data", old.Data,
             "$.VirtualTable", old.VirtualTable

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
     FROM [.sym_names]
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
-- [.class_props] table
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.class_props]
(
  [ID]           INTEGER NOT NULL PRIMARY KEY               AUTOINCREMENT,

  [ClassID]      INTEGER NOT NULL CONSTRAINT [fkClassPropertiesToClasses]
  REFERENCES [.classes] ([ClassID])
    ON DELETE CASCADE
    ON UPDATE RESTRICT,

  [NameID]       INTEGER NOT NULL CONSTRAINT [fkClassPropsNameID]
  REFERENCES [.sym_names] ([ID])
    ON DELETE RESTRICT
    ON UPDATE RESTRICT,

  /*
  Actual control flags (already applied).
  These flags define indexing, logging and other property attributes
  */
  [ctlv]         INTEGER NOT NULL                           DEFAULT 0,

  /*
  Planned/desired control flags which are not yet applied
  */
  [ctlvPlan]     INTEGER NOT NULL                           DEFAULT 0,

  /*
  Optional mapping for locked property (A-P)
   */
  [ColMap]       CHAR    NULL CHECK ([ColMap] IS NULL OR ([ColMap] >= 'A' AND [ColMap] <= 'P')),

  /*
  Property is marked as deleted
   */
  Deleted        BOOLEAN NOT NULL                           DEFAULT 0,

  /*
  Number of non null values. Gets updated during database statistic collection
   */
  NonNullCount   INTEGER NOT NULL                           DEFAULT 0,

  /*
  How many times this property was referenced in search criteria. Candidate for indexing
   */
  SearchHitCount INTEGER NOT NULL                           DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClassPropertiesByClassAndName]
  ON [.class_props]
  (ClassID, NameID)
  WHERE Deleted = 0;

CREATE UNIQUE INDEX IF NOT EXISTS [idxClassPropertiesByMap]
  ON [.class_props]
  (ClassID, ColMap)
  WHERE [ColMap] IS NOT NULL AND Deleted = 0;

------------------------------------------------------------------------------------------
-- [flexi_prop] view
------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [flexi_prop] AS
  SELECT
    cp.[ID]                                                            AS PropertyID,
    cp.ClassID                                                         AS ClassID,
    cp.Class                                                           AS Class,
    cp.[NameID]                                                        AS NameID,
    (SELECT n.[Value]
     FROM [.sym_names] n
     WHERE n.ID = cp.NameID
     LIMIT 1)                                                          AS Property,
    cp.ctlv                                                            AS ctlv,
    cp.ctlvPlan                                                        AS ctlvPlan,
    cp.Definition                                                      AS Definition,
    cp.Deleted                                                         AS Deleted,
    cp.SearchHitCount                                                  AS SearchHitCount,
    cp.NonNullCount                                                    AS NonNullCount,
    (json_extract(cp.Definition, '$.rules.type'))                      as Type,
    coalesce(json_extract(cp.Definition, '$.rules.minOccurrences'), 0) as minOccurrences,
    coalesce(json_extract(cp.Definition, '$.rules.maxOccurrences'), 1) as maxOccurrences,
    (json_extract(cp.Definition, '$.rules.maxLength'))                 as maxLength,
    (json_extract(cp.Definition, '$.index'))                           as IndexType
  FROM
    (select
       cp.*,
       c.Class,
       c.ClassID,
       (json_extract(Definition, printf('$.properties.%d', cp.[ID]))) AS Definition
     from [.class_props] cp
       JOIN
       [flexi_class] c ON cp.ClassID = c.ClassID
     WHERE cp.Deleted = 0) cp;

CREATE TRIGGER IF NOT EXISTS trigFlexi_Prop_Insert
  INSTEAD OF INSERT
  ON [flexi_prop]
  FOR EACH ROW
BEGIN
  --  TODO ??? SELECT flexi('create property', new.Class, new.Property, new.Definition);

  INSERT OR IGNORE INTO [.sym_names] ([Value]) VALUES (new.Property);
  INSERT INTO [.class_props] (NameID, ClassID, ctlv, ctlvPlan)
  VALUES (coalesce(new.NameID, (SELECT n.ID
                                FROM [.sym_names] n
                                WHERE n.[Value] = new.Property
                                LIMIT 1)),
          new.ClassID, new.ctlv, new.ctlvPlan);

  -- TODO Fix unresolved references??? (needed?)
END;

CREATE TRIGGER IF NOT EXISTS trigFlexi_Prop_Update
  INSTEAD OF UPDATE
  ON [flexi_prop]
  FOR EACH ROW
BEGIN
  --  SELECT flexi('rename property', new.Class, old.Property, new.Property);
  --  SELECT flexi('alter property', new.Class, new.Property, new.Definition);

  INSERT OR IGNORE INTO [.sym_names] (Value)
  VALUES (new.Property);

  UPDATE [.class_props]
  SET NameID = (SELECT ID
                FROM [.sym_names]
                WHERE Value = new.Property
                LIMIT 1),
    ClassID  = new.ClassID, ctlv = new.ctlv, ctlvPlan = new.ctlvPlan
  WHERE ID = old.PropertyID;
END;

CREATE TRIGGER IF NOT EXISTS trigFlexi_Prop_Delete
  INSTEAD OF DELETE
  ON [flexi_prop]
  FOR EACH ROW
BEGIN
  --  SELECT flexi('drop property', old.Class, old.Property);

  -- TODO Soft delete?

  DELETE FROM [.class_props]
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
  REFERENCES [.classes] ([ClassID])
    ON DELETE CASCADE
    ON UPDATE CASCADE,

  /*
  Direct column mapping for property values (.class_props.ColMap)
  Values in these columns are treated as records in [.ref-values] with
  pre-set PropertyID (as it is known by column mapping), ObjectID (as it is shared by [.objects].ObjectID),
  PropIndex = 0. ctlv flags are stored in ctlo and vtypes fields.
  Only scalar short properties can be mapped to these columns. E.g. all reference properties,
  long text properties (maxLength > 255), binary (maxLength > 255) cannot be mapped

  Columns A-P are defined as INT to help SQLite with type inferring. Lua does not distinct between float and
  integer types, and thus lsqlite3 always uses REAL for all numeric values.

   */
  A          INT     NULL,
  B          INT     NULL,
  C          INT     NULL,
  D          INT     NULL,
  E          INT     NULL,
  F          INT     NULL,
  G          INT     NULL,
  H          INT     NULL,
  I          INT     NULL,
  J          INT     NULL,
  K          INT     NULL,
  L          INT     NULL,
  M          INT     NULL,
  N          INT     NULL,
  O          INT     NULL,
  P          INT     NULL,

  /*
      -- bits 0 - 15 - unique indexes for A - P
    -- bits 16 - 31 - non unique indexes for A - P
    -- bit 32 - deleted
    -- bit 33 - invalid data
    -- bit 34 - has accessRules in MetaData
    -- bit 35 - has colsMetaData in MetaData
    -- bit 36 - has formulas in MetaData
    -- bit 37 - WEAK object - and must be auto deleted after last reference to this object gets deleted.
    -- bit 38 - don't track changes
    -- ... ?
*/
  [ctlo]     INTEGER,

  /*
  16 groups, 3 bit each. For storing actual value type (
    0 - default
    1 - datetime (for FLOAT),
    2 - timespan (for FLOAT),
    3 - symbol (for INT)
    4 - money (for INT) - as integer value with fixed 4 decimal points (exact value for +-1844 trillions)
    5 - json (for TEXT)
    6 - enum (for INT or TEXT)
    7 - reference (used only in .ref-values.ctlv, not applicable for .objects.vtypes])
    )
   */
  [vtypes]   INTEGER,

  /*
  Optional data for object/row (font/color/formulas etc. customization)
  */
  [MetaData] JSON1   NULL
);

CREATE INDEX IF NOT EXISTS [idxObjectsByClass]
  ON [.objects] ([ClassID]);

-- Conditional indexes
CREATE INDEX IF NOT EXISTS [idxObjectsByA]
  ON [.objects] ([ClassID], [A])
  WHERE (ctlo AND (1 << 16)) <> 0 AND [A] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByB]
  ON [.objects] ([ClassID], [B])
  WHERE (ctlo AND (1 << 17)) <> 0 AND [B] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByC]
  ON [.objects] ([ClassID], [C])
  WHERE (ctlo AND (1 << 18)) <> 0 AND [C] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByD]
  ON [.objects] ([ClassID], [D])
  WHERE (ctlo AND (1 << 19)) <> 0 AND [D] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByE]
  ON [.objects] ([ClassID], [E])
  WHERE (ctlo AND (1 << 20)) <> 0 AND [E] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByF]
  ON [.objects] ([ClassID], [F])
  WHERE (ctlo AND (1 << 21)) <> 0 AND [F] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByG]
  ON [.objects] ([ClassID], [G])
  WHERE (ctlo AND (1 << 22)) <> 0 AND [G] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByH]
  ON [.objects] ([ClassID], [H])
  WHERE (ctlo AND (1 << 23)) <> 0 AND [H] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByI]
  ON [.objects] ([ClassID], [I])
  WHERE (ctlo AND (1 << 24)) <> 0 AND [I] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByJ]
  ON [.objects] ([ClassID], [J])
  WHERE (ctlo AND (1 << 25)) <> 0 AND [J] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByE]
  ON [.objects] ([ClassID], [K])
  WHERE (ctlo AND (1 << 26)) <> 0 AND [K] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByF]
  ON [.objects] ([ClassID], [L])
  WHERE (ctlo AND (1 << 27)) <> 0 AND [L] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByG]
  ON [.objects] ([ClassID], [M])
  WHERE (ctlo AND (1 << 28)) <> 0 AND [M] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByH]
  ON [.objects] ([ClassID], [N])
  WHERE (ctlo AND (1 << 29)) <> 0 AND [N] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByI]
  ON [.objects] ([ClassID], [O])
  WHERE (ctlo AND (1 << 30)) <> 0 AND [O] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByJ]
  ON [.objects] ([ClassID], [P])
  WHERE (ctlo AND (1 << 31)) <> 0 AND [P] IS NOT NULL;

-- Unique conditional indexes
CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqA]
  ON [.objects] ([ClassID], [A])
  WHERE (ctlo AND (1 << 0)) <> 0 AND [A] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqB]
  ON [.objects] ([ClassID], [B])
  WHERE (ctlo AND (1 << 1)) <> 0 AND [B] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqC]
  ON [.objects] ([ClassID], [C])
  WHERE (ctlo AND (1 << 2)) <> 0 AND [C] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqD]
  ON [.objects] ([ClassID], [D])
  WHERE (ctlo AND (1 << 3)) <> 0 AND [D] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqE]
  ON [.objects] ([ClassID], [E])
  WHERE (ctlo AND (1 << 4)) <> 0 AND [E] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqF]
  ON [.objects] ([ClassID], [F])
  WHERE (ctlo AND (1 << 5)) <> 0 AND [F] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqG]
  ON [.objects] ([ClassID], [G])
  WHERE (ctlo AND (1 << 6)) <> 0 AND [G] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqH]
  ON [.objects] ([ClassID], [H])
  WHERE (ctlo AND (1 << 7)) <> 0 AND [H] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqI]
  ON [.objects] ([ClassID], [I])
  WHERE (ctlo AND (1 << 8)) <> 0 AND [I] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqJ]
  ON [.objects] ([ClassID], [J])
  WHERE (ctlo AND (1 << 9)) <> 0 AND [J] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqE]
  ON [.objects] ([ClassID], [K])
  WHERE (ctlo AND (1 << 10)) <> 0 AND [K] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqF]
  ON [.objects] ([ClassID], [L])
  WHERE (ctlo AND (1 << 11)) <> 0 AND [L] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqG]
  ON [.objects] ([ClassID], [M])
  WHERE (ctlo AND (1 << 12)) <> 0 AND [M] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqH]
  ON [.objects] ([ClassID], [N])
  WHERE (ctlo AND (1 << 13)) <> 0 AND [N] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqI]
  ON [.objects] ([ClassID], [O])
  WHERE (ctlo AND (1 << 14)) <> 0 AND [O] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByUniqJ]
  ON [.objects] ([ClassID], [P])
  WHERE (ctlo AND (1 << 15)) <> 0 AND [P] IS NOT NULL;

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
               CASE WHEN new.MetaData IS NULL
                 THEN NULL
               ELSE '$.ExtData' END, new.MetaData,

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

                  CASE WHEN new.MetaData IS NULL
                    THEN NULL
                  ELSE '$.MetaData' END, new.MetaData,

                  CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL
                    THEN NULL
                  ELSE '$.ctlo' END, new.ctlo
         )                                                            AS [OldValue],
         printf('@%s.%s', new.[ClassID], new.[ObjectID])              AS [KEY],
         json_set('{}',
                  CASE WHEN nullif(new.MetaData, old.MetaData) IS NULL
                    THEN NULL
                  ELSE '$.MetaData' END, old.MetaData,

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
               CASE WHEN old.MetaData IS NULL
                 THEN NULL
               ELSE '$.MetaData' END, old.MetaData,

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
-- .range_data_<ClassID>
------------------------------------------------------------------------------------------

/*
This table is used as geospatial or general multi-dimensional index. It utilizes all 5 available
dimensions that SQLite provides. A - E dimensions are available for indexing.
Number, integer, SymName, DateTime, Enum types can be indexed.
Every dimension can be associated with one column on both bounds, or 2 columns can form a range (
like StartTime - EndTime, or LatitudeLo - LatitudeHi), so with 4 dimensions it is possible to
define 3D space plus time range. This type of index can be also used for efficient finding results
for queries like "find all orders created within last month with expected shipping date next week".

Note that dimension definition for DateTime (for low bound) and TimeSpan (for high bound) are not allowed.
DateTime + TimeSpan must be used for high bound in this case. Indexing on the same TimeSpan column
for both low and high bounds is OK.

Every class that has definitions for range indexes will have its own .range_data table named
as [.range_data_<ClassID>], e.g. [.range_data_123]. This table gets created when range indexing is requested
by class definition, and gets removed on class destroy.
 */
/*
CREATE VIRTUAL TABLE IF NOT EXISTS [.range_data_<ClassID>] USING rtree (
 [ObjectID],

 [A0], [A1],
 [B0], [B1],
 [C0], [C1],
 [D0], [D1],
 [E0], [E1]
);
*/

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
  [Value]      INTEGER NOT NULL,

  /*
  ctlv - value bit flags (indexing etc). Possible values:
    bits: 0-2 - specific value type (vtypes)
    bit 3: unique index
    bit 4: non-unique index
    bits: 5-7 - reference
    bit 8 - invalid value
    bit 9 - deleted
    bit 10 - no track changes
  */
  [ctlv]       INTEGER NOT NULL DEFAULT 0,
  /*
Optional data for cell (font/color/format etc. customization)
*/
  [MetaData]   JSON1   NULL,

  CONSTRAINT [] PRIMARY KEY ([ObjectID], [PropertyID], [PropIndex])
)
  WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxClassReversedRefs]
  ON [.ref-values] ([Value], [PropertyID])
  WHERE [ctlv] & 0xE0;

-- Mask 0xF0 covers all references and non-unique index
CREATE INDEX IF NOT EXISTS [idxValuesByPropValue]
  ON [.ref-values] ([PropertyID], [Value])
  WHERE ([ctlv] & 0xF0);

CREATE UNIQUE INDEX IF NOT EXISTS [idxValuesByPropUniqueValue]
  ON [.ref-values] ([PropertyID], [Value])
  WHERE ([ctlv] & 8);

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterDelete]
  AFTER DELETE
  ON [.ref-values]
  FOR EACH ROW
BEGIN
  -- Delete weak referenced object in case this Value record was last reference to that object
  DELETE FROM [.objects]
  WHERE old.ctlv IN (3) AND ObjectID = old.Value AND
        (ctlo & 1) = 1 AND (SELECT count(*)
                            FROM [.ref-values]
                            WHERE [Value] = ObjectID AND ctlv IN (3)) = 0;
END;

------------------------------------------------------------------------------------------
-- .multi_key2, .multi_key3, .multi_key4
-- Clustered (without rowid), single-index tables used as external index for .ref-values
-- to support multi key unique indexes (2-3-4 columns)
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.multi_key2] (
  ClassID  INTEGER NOT NULL,
  Z1               NOT NULL,
  Z2               NOT NULL,
  ObjectID INTEGER NOT NULL,
  CONSTRAINT [] PRIMARY KEY ([ClassID], [Z1], [Z2])
)
  WITHOUT ROWID;
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.multi_key3] (
  ClassID  INTEGER NOT NULL,
  Z1               NOT NULL,
  Z2               NOT NULL,
  Z3               NOT NULL,
  ObjectID INTEGER NOT NULL,
  CONSTRAINT [] PRIMARY KEY ([ClassID], [Z1], [Z2], [Z3])
)
  WITHOUT ROWID;
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.multi_key4] (
  ClassID  INTEGER NOT NULL,
  Z1               NOT NULL,
  Z2               NOT NULL,
  Z3               NOT NULL,
  Z4               NOT NULL,
  ObjectID INTEGER NOT NULL,
  CONSTRAINT [] PRIMARY KEY ([ClassID], [Z1], [Z2], [Z3], [Z4])
)
  WITHOUT ROWID;

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

-- Added: 2018-06-10
/* Dependencies for computed properties

Used for tracking affected properties

Property IDs can be:
> 0 - regular properties. ChangedClassID/CalcClassID = 0
0 - all properties. ChangedClassID/CalcClassID > 0
< 0 special property ($uid, $text etc.). ChangedClassID/CalcClassID > 0

ChangedPropID -
CalcPropID -
 */
create table if not exists [.prop-deps]
(
  -- When MasterPropID, changed
  ChangedClassID INT NOT NULL,
  ChangedPropID INT NOT NULL,
  CalcClassID INT NOT NULL,
  CalcPropID  INT NOT NULL,
  CONSTRAINT [] PRIMARY KEY (ChangedPropID, CalcPropID)
);

create index if not exists idxCalcDepsByCalcProp on [.prop-deps] (CalcPropID, ChangedPropID);

-- TODO triggers
-- TODO Finalize design and implementation

-- END --