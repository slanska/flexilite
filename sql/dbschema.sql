
PRAGMA page_size = 8192;
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = 1;
PRAGMA encoding = 'UTF-8';
PRAGMA recursive_triggers = 1;

------------------------------------------------------------------------------------------
-- .names
------------------------------------------------------------------------------------------

/*
.names table has rows of 2 types - class properties and symbolic names. Column 'type' defines
which sort of entity it is: 1 - property, 2 - name, 3 - both name and property
The reason why 2 entities are combined into single table is to share IDs.
Objects may have attributes which are not defined in .classes.Data.properties
(if .classes.Data.allowNotDefinedProps = 1). Such attributes will be stored as IDs to .names table,
where ID will correspond to name subtype.

*/
create table if not exists [.names]
(
    NameID INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,

    Type INTEGER NOT NULL


    /*
    Name specific columns
    */

    -- Case sensitive
    [Value] TEXT COLLATE BINARY NOT NULL CHECK (rtrim(ltrim([Value])) <> ''),

    PluralOf integer null
            CONSTRAINT [fkNamesByPluralOf]
            REFERENCES [.names] ([NameID]) ON DELETE SET NULL ON UPDATE RESTRICT,
    AliasOf integer null
            CONSTRAINT [fkNamesByAliasOf]
            REFERENCES [.names] ([NameID]) ON DELETE SET NULL ON UPDATE RESTRICT,

    Data JSON1 null,

        [ClassID]  INTEGER NOT NULL CONSTRAINT [fkClassPropertiesToClasses]
        REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE RESTRICT,

/*
Property specific columns
*/
        /*
        Property name
        */
    [NameID] INTEGER NOT NULL constraint [fkClassPropertiesToNames] references [.names] ([NameID])
        on delete restrict on update restrict,

        /*
        Actual control flags
        */
    [ctlv] INTEGER NOT NULL DEFAULT 0,

    /*
    Planned/desired control flags
    */
    [ctlvPlan] INTEGER NOT NULL DEFAULT 0
);

create unique index if not exists [namesByValue] on [.names]([Value]);
create  index if not exists [namesByAliasOf] on [.names]([AliasOf]) where AliasOf is not null;
create  index if not exists [namesByPluralOf] on [.names]([PluralOf]) where PluralOf is not null;

------------------------------------------------------------------------------------------
-- .access_rules
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.access_rules] (
  [UserRoleID] GUID NOT NULL,

  /*
  C - Class
  O - Object
  P - Property
  */
  [ItemType]   CHAR NOT NULL,

    /*
    H - hidden
    R - read only
    U - updatable
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

CREATE INDEX IF NOT EXISTS [idxAccessRulesByItemID] ON [.access_rules] ([ItemID]);

------------------------------------------------------------------------------------------
-- .change_log
------------------------------------------------------------------------------------------
-- TODO will be implemented as LMDB database
CREATE TABLE IF NOT EXISTS [.change_log] (
  [ID]        INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [TimeStamp] DATETIME NOT NULL             DEFAULT (julianday('now')),
  [OldKey] TEXT NULL,
  [OldValue]  JSON1,

  -- Format for key and oldkey
  -- @ClassID.objectID#propertyID[propertyIndex]
  -- Example: @23.188374#345[11]
  [KEY] TEXT NULL,
  [Value]     JSON1,

  [ChangedBy] GUID  NULL
);

create trigger if not exists trigChangeLogAfterInsert
after insert
on [.change_log]
for each row
when new.ChangedBy is null
begin
    update [.change_log] set ChangedBy = var('CurrentUserID') where ID = new.ID;
end;

------------------------------------------------------------------------------------------
-- .classes
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.classes] (
  [ClassID]           INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [NameID]         INTEGER NOT NULL CONSTRAINT [fkClassesNameID]
                                         REFERENCES [.names] ([NameID]) ON DELETE RESTRICT ON UPDATE RESTRICT,
  [ViewOutdated] BOOL NOT NULL DEFAULT 1,

   -- System class is used internally by the system and cannot be changed or deleted by end-user

  [SystemClass] BOOL NOT NULL DEFAULT 0,

-- Optional mappings for JSON property shortcuts and/or indexing
-- Values are property IDs
  [A] INTEGER NULL,
  [B] INTEGER NULL,
  [C] INTEGER NULL,
  [D] INTEGER NULL,
  [E] INTEGER NULL,
  [F] INTEGER NULL,
  [G] INTEGER NULL,
  [H] INTEGER NULL,
  [I] INTEGER NULL,
  [J] INTEGER NULL,

  -- Control bitmask for objects belonging to this class
  [ctloMask] INTEGER NOT NULL DEFAULT 0,

  AccessRules JSON1 NULL,

  /*
  IClassDefinition. Can be set to null for a newly created class
  */
  Data JSON1 NULL,

  /*
  Class definition hash. Used for fast lookup for duplicated definitions and schema verification
  */
  Hash TEXT(40) NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClasses_byNameID] ON [.classes] ([NameID]);

create trigger if not exists [trigClassesAfterUpdateName]
after update of NameID
on [.classes]
for each row
begin
    update [.schemas] set NameID = new.NameID where NameID = old.NameID;
end;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterInsert]
AFTER INSERT
ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([KEY], [Value]) VALUES (
    printf('@%s', new.ClassID),
    json_set('{}',
             "$.NameID" , new.NameID,
             "$.SystemClass" , new.SystemClass,
             "$.ViewOutdated" , new.ViewOutdated,
             "$.ctloMask" , new.ctloMask,

            CASE WHEN new.AccessRules IS NULL
              THEN NULL
            ELSE "$.AccessRules" END, new.AccessRules,

             CASE WHEN new.A IS NULL
               THEN NULL
             ELSE "$.A" END, new.A,

             CASE WHEN new.B IS NULL
               THEN NULL
             ELSE "$.B" END, new.B,

            CASE WHEN new.C IS NULL
            THEN NULL
            ELSE "$.C" END, new.C,

            CASE WHEN new.D IS NULL
            THEN NULL
            ELSE "$.D" END, new.D,

            CASE WHEN new.E IS NULL
            THEN NULL
            ELSE "$.E" END, new.E,

            CASE WHEN new.F IS NULL
            THEN NULL
            ELSE "$.F" END, new.F,

            CASE WHEN new.G IS NULL
            THEN NULL
            ELSE "$.G" END, new.G,

            CASE WHEN new.H IS NULL
            THEN NULL
            ELSE "$.H" END, new.H,

            CASE WHEN new.I IS NULL
            THEN NULL
            ELSE "$.I" END, new.I,

            CASE WHEN new.J IS NULL
            THEN NULL
            ELSE "$.J" END, new.J
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
        '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT)                             AS [OldKey],

        json_set('{}',
             "$.NameID" , old.NameID,
             "$.SystemClass" , old.SystemClass,
             "$.ViewOutdated" , old.ViewOutdated,
             "$.ctloMask" , old.ctloMask,

            CASE WHEN old.AccessRules IS NULL
              THEN NULL
            ELSE "$.AccessRules" END, old.AccessRules,

             CASE WHEN old.A IS NULL
               THEN NULL
             ELSE "$.A" END, old.A,

             CASE WHEN old.B IS NULL
               THEN NULL
             ELSE "$.B" END, old.B,

            CASE WHEN old.C IS NULL
            THEN NULL
            ELSE "$.C" END, old.C,

            CASE WHEN old.D IS NULL
            THEN NULL
            ELSE "$.D" END, old.D,

            CASE WHEN old.E IS NULL
            THEN NULL
            ELSE "$.E" END, old.E,

            CASE WHEN old.F IS NULL
            THEN NULL
            ELSE "$.F" END, old.F,

            CASE WHEN old.G IS NULL
            THEN NULL
            ELSE "$.G" END, old.G,

            CASE WHEN old.H IS NULL
            THEN NULL
            ELSE "$.H" END, old.H,

            CASE WHEN old.I IS NULL
            THEN NULL
            ELSE "$.I" END, old.I,

            CASE WHEN old.J IS NULL
            THEN NULL
            ELSE "$.J" END, old.J
        ) AS [OldValue],

        '@' || CAST(new.ClassID AS TEXT)                                                  AS [KEY],
                json_set('{}',
             "$.NameID" , new.NameID,
             "$.SystemClass" , new.SystemClass,
             "$.ViewOutdated" , new.ViewOutdated,
             "$.ctloMask" , new.ctloMask,

            CASE WHEN new.AccessRules IS NULL
              THEN NULL
            ELSE "$.AccessRules" END, new.AccessRules,

             CASE WHEN new.A IS NULL
               THEN NULL
             ELSE "$.A" END, new.A,

             CASE WHEN new.B IS NULL
               THEN NULL
             ELSE "$.B" END, new.B,

            CASE WHEN new.C IS NULL
            THEN NULL
            ELSE "$.C" END, new.C,

            CASE WHEN new.D IS NULL
            THEN NULL
            ELSE "$.D" END, new.D,

            CASE WHEN new.E IS NULL
            THEN NULL
            ELSE "$.E" END, new.E,

            CASE WHEN new.F IS NULL
            THEN NULL
            ELSE "$.F" END, new.F,

            CASE WHEN new.G IS NULL
            THEN NULL
            ELSE "$.G" END, new.G,

            CASE WHEN new.H IS NULL
            THEN NULL
            ELSE "$.H" END, new.H,

            CASE WHEN new.I IS NULL
            THEN NULL
            ELSE "$.I" END, new.I,

            CASE WHEN new.J IS NULL
            THEN NULL
            ELSE "$.J" END, new.J
        )
        AS [Value]
    )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL;
END;

--CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdateOfctloMaskOrColumns]
--AFTER UPDATE OF [ctloMask], [A], [B], [C], [D], [E], [F], [G], [H], [I], [J]
--ON [.classes]
--FOR EACH ROW
--BEGIN
  -- Update objects with shortcuts if needed
--  update [.objects] set
--        [ctlo] = new.[ctloMask],
--        [A] = flexi_get(new.A, ObjectID, SchemaID, [Data]),
--        [B] = flexi_get(new.B, ObjectID, SchemaID, [Data]),
--        [C] = flexi_get(new.C , ObjectID, SchemaID, [Data]),
--        [D] = flexi_get(new.D , ObjectID, SchemaID, [Data]),
--        [E] = flexi_get(new.E, ObjectID, SchemaID, [Data]),
--        [F] = flexi_get(new.F , ObjectID, SchemaID, [Data]),
--        [G] = flexi_get(new.G , ObjectID, SchemaID, [Data]),
--        [H] = flexi_get(new.H , ObjectID, SchemaID, [Data]),
--        [I] = flexi_get(new.I , ObjectID, SchemaID, [Data]),
--        [J] = flexi_get(new.J , ObjectID, SchemaID, [Data])
--
--        where [ClassID] = new.ClassID;
--END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterDelete]
AFTER DELETE
ON [.classes]
FOR EACH ROW
BEGIN
    delete from [.schemas] where NameID = old.NameID;

  INSERT INTO [.change_log] ([OldKey], [OldValue]) VALUES (
    printf('@%s', old.ClassID),

    json_set('{}',
              "$.NameID" , old.NameID,
              "$.SystemClass" , old.SystemClass,
              "$.ViewOutdated" , old.ViewOutdated,
              "$.ctloMask" , old.ctloMask,

            CASE WHEN old.AccessRules IS NULL
              THEN NULL
            ELSE "$.AccessRules" END, old.AccessRules,

              CASE WHEN old.A IS NULL
                THEN NULL
              ELSE "$.A" END, old.A,

              CASE WHEN old.B IS NULL
                THEN NULL
              ELSE "$.B" END, old.B,

             CASE WHEN old.C IS NULL
             THEN NULL
             ELSE "$.C" END, old.C,

             CASE WHEN old.D IS NULL
             THEN NULL
             ELSE "$.D" END, old.D,

             CASE WHEN old.E IS NULL
             THEN NULL
             ELSE "$.E" END, old.E,

             CASE WHEN old.F IS NULL
             THEN NULL
             ELSE "$.F" END, old.F,

             CASE WHEN old.G IS NULL
             THEN NULL
             ELSE "$.G" END, old.G,

             CASE WHEN old.H IS NULL
             THEN NULL
             ELSE "$.H" END, old.H,

             CASE WHEN old.I IS NULL
             THEN NULL
             ELSE "$.I" END, old.I,

             CASE WHEN old.J IS NULL
             THEN NULL
             ELSE "$.J" END, old.J
    )
  );
END;

------------------------------------------------------------------------------------------
-- .class_properties
------------------------------------------------------------------------------------------
create table if not exists [.class_properties]
 (
    [PropertyID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
    [ClassID]  INTEGER NOT NULL CONSTRAINT [fkClassPropertiesToClasses]
        REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE RESTRICT,

        /*
        Property name
        */
    [NameID] INTEGER NOT NULL constraint [fkClassPropertiesToNames] references [.names] ([NameID])
        on delete restrict on update restrict,

        /*
        Actual control flags
        */
    [ctlv] INTEGER NOT NULL DEFAULT 0,

    /*
    Planned/desired control flags
    */
    [ctlvPlan] INTEGER NOT NULL DEFAULT 0
 );

 create unique index if not exists [idxClassPropertiesByClassAndName] on [.class_properties]
 (ClassID, NameID);

 create view if not exists [.vw_class_properties] as
 select
    [PropertyID],
    cp.[ClassID],
    cp.[NameID],
    (select [Value] from [.names] n where n.NameID = NameID limit 1) as Name,
    case
        when c.A = PropertyID then 'A'
        when c.B = PropertyID then 'B'
        when c.C = PropertyID then 'C'
        when c.D = PropertyID then 'D'
        when c.E = PropertyID then 'E'
        when c.F = PropertyID then 'F'
        when c.G = PropertyID then 'G'
        when c.H = PropertyID then 'H'
        when c.I = PropertyID then 'I'
        when c.J = PropertyID then 'J'
        else null
    end as [ColumnAssigned],
    ctlv,
    (json_extract(c.Data, printf('$.properties.%d', [PropertyID]))) as Data

 from [.class_properties] cp join [.classes] c on cp.ClassID = c.ClassID;

 /*
 TODO Triggers on insert, update, delete
 */

------------------------------------------------------------------------------------------
-- .full_text_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.full_text_data] USING fts4 (

  [PropertyID],
  [ClassID],
  [ObjectID],
  [PropertyIndex],
  [Value],

-- to allow case insensitive search for different languages
  tokenize=unicode61
);

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
   Bits 1-10: columns A-J should be indexed and be unique
  Bits 13-22: columns A-J should be indexed for fast lookup. These bits are checked by partial indexes
  Bits 25-34: columns A-J should be indexed for full text search
  Bits 37-46: columns A-J should be treated as range values and indexed for range (spatial search) search

  Bit 49: DON'T track changes
  Bit 50: Schema is not validated. Normally, this bit is set when object was referenced in other object
  but it was not defined in the schema

  */
  [ctlo] INTEGER,

  -- Remove A-J columns
  [A],
  [B],
  [C],
  [D],
  [E],
  [F],
  [G],
  [H],
  [I],
  [J],
 [Data] JSON1 NULL,

 /*
 Optional data for object/row (font/color etc. customization)
 */
 [ExtData] JSON1 NULL
);

CREATE INDEX IF NOT EXISTS [idxObjectsByClassSchema] ON [.objects] ([ClassID]);

-- Conditional indexes
CREATE INDEX IF NOT EXISTS [idxObjectsByA] ON [.objects] ([ClassID], [A]) WHERE (ctlo AND (1 << 13)) <> 0 AND [A] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByB] ON [.objects] ([ClassID], [B]) WHERE (ctlo AND (1 << 14)) <> 0 AND [B] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByC] ON [.objects] ([ClassID], [C]) WHERE (ctlo AND (1 << 15)) <> 0 AND [C] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByD] ON [.objects] ([ClassID], [D]) WHERE (ctlo AND (1 << 16)) <> 0 AND [D] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByE] ON [.objects] ([ClassID], [E]) WHERE (ctlo AND (1 << 17)) <> 0 AND [E] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByF] ON [.objects] ([ClassID], [F]) WHERE (ctlo AND (1 << 18)) <> 0 AND [F] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByG] ON [.objects] ([ClassID], [G]) WHERE (ctlo AND (1 << 19)) <> 0 AND [G] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByH] ON [.objects] ([ClassID], [H]) WHERE (ctlo AND (1 << 20)) <> 0 AND [H] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByI] ON [.objects] ([ClassID], [I]) WHERE (ctlo AND (1 << 21)) <> 0 AND [I] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByJ] ON [.objects] ([ClassID], [J]) WHERE (ctlo AND (1 << 22)) <> 0 AND [J] IS NOT NULL;

-- Unique conditional indexes
CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByA] ON [.objects] ([ClassID], [A]) WHERE (ctlo AND (1 << 1)) <> 0 AND [A] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByB] ON [.objects] ([ClassID], [B]) WHERE (ctlo AND (1 << 2)) <> 0 AND [B] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByC] ON [.objects] ([ClassID], [C]) WHERE (ctlo AND (1 << 3)) <> 0 AND [C] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByD] ON [.objects] ([ClassID], [D]) WHERE (ctlo AND (1 << 4)) <> 0 AND [D] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByE] ON [.objects] ([ClassID], [E]) WHERE (ctlo AND (1 << 5)) <> 0 AND [E] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByF] ON [.objects] ([ClassID], [F]) WHERE (ctlo AND (1 << 6)) <> 0 AND [F] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByG] ON [.objects] ([ClassID], [G]) WHERE (ctlo AND (1 << 7)) <> 0 AND [G] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByH] ON [.objects] ([ClassID], [H]) WHERE (ctlo AND (1 << 8)) <> 0 AND [H] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByI] ON [.objects] ([ClassID], [I]) WHERE (ctlo AND (1 << 9)) <> 0 AND [I] IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS [idxObjectsByJ] ON [.objects] ([ClassID], [J]) WHERE (ctlo AND (1 << 10)) <> 0 AND [J] IS NOT NULL;

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
      '$.Data', new.Data,
        CASE WHEN new.A IS NULL THEN NULL ELSE '$.A' END, new.A,
        CASE WHEN new.B IS NULL THEN NULL ELSE '$.B' END, new.B,
        CASE WHEN new.C IS NULL THEN NULL ELSE '$.C' END, new.C,
        CASE WHEN new.D IS NULL THEN NULL ELSE '$.D' END, new.D,
        CASE WHEN new.E IS NULL THEN NULL ELSE '$.E' END, new.E,
        CASE WHEN new.F IS NULL THEN NULL ELSE '$.F' END, new.F,
        CASE WHEN new.G IS NULL THEN NULL ELSE '$.G' END, new.G,
        CASE WHEN new.H IS NULL THEN NULL ELSE '$.H' END, new.H,
        CASE WHEN new.I IS NULL THEN NULL ELSE '$.I' END, new.I,
        CASE WHEN new.J IS NULL THEN NULL ELSE '$.J' END, new.J,
        CASE WHEN new.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, new.ctlo
   )
    WHERE new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49);

  -- Full text and range data using INSTEAD OF triggers of dummy view
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'A', new.[A]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'B', new.[B]
    );

  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'C', new.[C]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'D', new.[D]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'E', new.[E]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'F', new.[F]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'G', new.[G]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'H', new.[H]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'I', new.[I]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'J', new.[J]
    );

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
         || '.' ||  CAST(nullif(old.ObjectID, new.[ObjectID]) AS TEXT) AS [OldKey],

        json_set('{}',
              '$.Data', new.Data,
          CASE WHEN nullif(new.A, old.A) IS NULL THEN NULL ELSE '$.A' END, new.A,
            CASE WHEN nullif(new.B, old.B) IS NULL THEN NULL ELSE '$.B' END, new.B,
          CASE WHEN nullif(new.C, old.C) IS NULL THEN NULL ELSE '$.C' END, new.C,
            CASE WHEN nullif(new.D, old.D) IS NULL THEN NULL ELSE '$.D' END, new.D,
          CASE WHEN nullif(new.E, old.E) IS NULL THEN NULL ELSE '$.E' END, new.E,
            CASE WHEN nullif(new.F, old.F) IS NULL THEN NULL ELSE '$.F' END, new.F,
          CASE WHEN nullif(new.G, old.G) IS NULL THEN NULL ELSE '$.G' END, new.G,
            CASE WHEN nullif(new.H, old.H) IS NULL THEN NULL ELSE '$.H' END, new.H,
          CASE WHEN nullif(new.I, old.I) IS NULL THEN NULL ELSE '$.I' END, new.I,
            CASE WHEN nullif(new.J, old.J) IS NULL THEN NULL ELSE '$.J' END, new.J,

          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, new.ctlo
         )                                                  AS [OldValue],
         printf('@%s.%s', new.[ClassID], new.[ObjectID])  AS [KEY],
         json_set('{}',
               CASE WHEN nullif(new.Data, old.Data) IS NULL THEN NULL ELSE '$.Data' END, old.Data,
          CASE WHEN nullif(new.A, old.A) IS NULL THEN NULL ELSE '$.A' END, old.A,
            CASE WHEN nullif(new.B, old.B) IS NULL THEN NULL ELSE '$.B' END, old.B,
          CASE WHEN nullif(new.C, old.C) IS NULL THEN NULL ELSE '$.C' END, old.C,
            CASE WHEN nullif(new.D, old.D) IS NULL THEN NULL ELSE '$.D' END, old.D,
          CASE WHEN nullif(new.E, old.E) IS NULL THEN NULL ELSE '$.E' END, old.E,
            CASE WHEN nullif(new.F, old.F) IS NULL THEN NULL ELSE '$.F' END, old.F,
          CASE WHEN nullif(new.G, old.G) IS NULL THEN NULL ELSE '$.G' END, old.G,
            CASE WHEN nullif(new.H, old.H) IS NULL THEN NULL ELSE '$.H' END, old.H,
          CASE WHEN nullif(new.I, old.I) IS NULL THEN NULL ELSE '$.I' END, old.I,
            CASE WHEN nullif(new.J, old.J) IS NULL THEN NULL ELSE '$.J' END, old.J,

          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo
         )
                                                         AS [Value]
      )
    WHERE (new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49))
          AND ([OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL);

  -- Update columns' full text and range data using dummy view with INSTEAD OF triggers
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'A', [oldValue] = old.[A],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'A', [Value] = new.[A],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'B', [oldValue] = old.[B],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'B', [Value] = new.[B],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'C', [oldValue] = old.[C],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'C', [Value] = new.[C],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'D', [oldValue] = old.[D],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'D', [Value] = new.[D],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'E', [oldValue] = old.[E],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'E', [Value] = new.[E],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'F', [oldValue] = old.[F],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'F', [Value] = new.[F],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'G', [oldValue] = old.[G],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'G', [Value] = new.[G],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'H', [oldValue] = old.[H],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'H', [Value] = new.[H],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'I', [oldValue] = old.[I],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'I', [Value] = new.[I],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'J', [oldValue] = old.[J],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'J', [Value] = new.[J],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];

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
                     CASE WHEN old.Data IS NULL THEN NULL ELSE '$.Data' END, old.Data,
        CASE WHEN old.A IS NULL THEN NULL ELSE '$.A' END, old.A,
          CASE WHEN old.B IS NULL THEN NULL ELSE '$.B' END, old.B,
        CASE WHEN old.C IS NULL THEN NULL ELSE '$.C' END, old.C,
          CASE WHEN old.D IS NULL THEN NULL ELSE '$.D' END, old.D,
        CASE WHEN old.E IS NULL THEN NULL ELSE '$.E' END, old.E,
          CASE WHEN old.F IS NULL THEN NULL ELSE '$.F' END, old.F,
        CASE WHEN old.G IS NULL THEN NULL ELSE '$.G' END, old.G,
          CASE WHEN old.H IS NULL THEN NULL ELSE '$.H' END, old.H,
        CASE WHEN old.I IS NULL THEN NULL ELSE '$.I' END, old.I,
          CASE WHEN old.J IS NULL THEN NULL ELSE '$.J' END, old.J,

        CASE WHEN old.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo
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

  -- Delete full text and range data using dummy view with INSTEAD OF triggers
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'A';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'B';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'C';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'D';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'E';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'F';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'G';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'H';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'I';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'J';
END;

------------------------------------------------------------------------------------------
-- .vw_object_column_data
------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.vw_object_column_data]
AS
  SELECT
    NULL AS [oldClassID],
    NULL AS [oldObjectID],
    NULL AS [oldctlo],
    NULL AS [oldValue],
    NULL AS [ClassID],
    NULL AS [ObjectID],
    NULL AS [ctlo],
    NULL AS [ColumnAssigned],
    NULL AS [Value];

CREATE TRIGGER IF NOT EXISTS [trigDummyObjectColumnDataInsert]
INSTEAD OF INSERT ON [.vw_object_column_data]
FOR EACH ROW
BEGIN
  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[ColumnAssigned]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      '#0#',
      new.[Value]
    WHERE new.[ColumnAssigned] IS NOT NULL AND new.ctlo & (1 << (25 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND
          typeof(new.[Value]) = 'text';
END;

CREATE TRIGGER IF NOT EXISTS [trigDummyObjectColumnDataUpdate]
INSTEAD OF UPDATE ON [.vw_object_column_data]
FOR EACH ROW
BEGIN
  -- Process full text data based on ctlo
  DELETE FROM [.full_text_data]
  WHERE
    new.[ColumnAssigned] IS NOT NULL AND
    new.oldctlo & (1 << (25 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND typeof(new.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', new.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', new.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', new.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';

  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[ColumnAssigned]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      '#0#',
      new.[Value]
    WHERE new.[ColumnAssigned] IS NOT NULL AND new.ctlo & (1 << (25 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND
          typeof(new.[Value]) = 'text';
END;

CREATE TRIGGER IF NOT EXISTS [trigDummyObjectColumnDataDelete]
INSTEAD OF DELETE ON [.vw_object_column_data]
FOR EACH ROW
BEGIN
  -- Process full text data based on ctlo
  DELETE FROM [.full_text_data]
  WHERE
    old.[ColumnAssigned] IS NOT NULL AND
    old.oldctlo & (1 << (25 + unicode(old.[ColumnAssigned]) - unicode('A'))) AND typeof(old.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', old.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';
END;


------------------------------------------------------------------------------------------
-- .range_data
------------------------------------------------------------------------------------------

CREATE VIRTUAL TABLE IF NOT EXISTS [.range_data] USING rtree (
  [ObjectID],
  [ClassID], [ClassID_1],
  [A], [A_1],
  [B], [B_1],
  [C], [C_1],
  [D], [D_1]
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
 [ExtData] JSON1 NULL,

  CONSTRAINT [] PRIMARY KEY ([ObjectID], [PropertyID], [PropIndex])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxClassReversedRefs] ON [.ref-values] ([Value], [PropertyID]) WHERE [ctlv] & 14;

CREATE INDEX IF NOT EXISTS [idxValuesByPropValue] ON [.ref-values] ([PropertyID], [Value]) WHERE ([ctlv] & 1);

CREATE UNIQUE INDEX IF NOT EXISTS [idxValuesByPropUniqueValue] ON [.ref-values] ([PropertyID], [Value]) WHERE ([ctlv] & 128);

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

  -- process range data
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

  -- Process range data based on ctlv
-- TODO
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

  -- TODO Process range data based on ctlv
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
    NULL as [ExtData];

CREATE TRIGGER IF NOT EXISTS trigValuesEasy_Insert INSTEAD OF INSERT
ON [.ValuesEasy]
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO [.objects] (ClassID, ObjectID, ctlo, A, B, C, D, E, F, G, H, I, J)
    SELECT
      c.ClassID,

      ctlo = c.ctloMask,

      A = (CASE WHEN p.[ColumnAssigned] = 'A'
        THEN new.[Value]
           ELSE A END),

      B = (CASE WHEN p.[ColumnAssigned] = 'B'
        THEN new.[Value]
           ELSE B END),

      C = (CASE WHEN p.[ColumnAssigned] = 'C'
        THEN new.[Value]
           ELSE C END),

      D = (CASE WHEN p.[ColumnAssigned] = 'D'
        THEN new.[Value]
           ELSE D END),

      E = (CASE WHEN p.[ColumnAssigned] = 'E'
        THEN new.[Value]
           ELSE E END),

      F = (CASE WHEN p.[ColumnAssigned] = 'F'
        THEN new.[Value]
           ELSE F END),

      G = (CASE WHEN p.[ColumnAssigned] = 'G'
        THEN new.[Value]
           ELSE G END),

      H = (CASE WHEN p.[ColumnAssigned] = 'H'
        THEN new.[Value]
           ELSE H END),

      I = (CASE WHEN p.[ColumnAssigned] = 'I'
        THEN new.[Value]
           ELSE I END),

      J = (CASE WHEN p.[ColumnAssigned] = 'J'
        THEN new.[Value]
           ELSE J END)

    FROM [.classes] c, [.vw_class_properties] p
    WHERE c.[ClassID] = p.[ClassID] AND c.NameID = new.NameID AND p.PropertyName = new.PropertyName
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

--------------------------------------------------------------------------------------------
-- .values_view - wraps access to .values table by providing separate ObjectID columns
--------------------------------------------------------------------------------------------
create view if not exists [.ref-values_view] as
select [ObjectID], ctlv, PropertyID, PropIndex, [Value], ExtData
from [.ref-values];

create trigger if not exists values_view_Insert instead of insert on [.ref-values_view]
for each row
begin
    insert into [.ref-values]
    (
     [ObjectID], ctlv, PropertyID, PropIndex, [Value], ExtData
    )
    values (
     new.[ObjectID], new.ctlv,
    new.PropertyID, new.PropIndex, new.[Value], new.ExtData);
end;

create trigger if not exists values_view_Update instead of update on [.ref-values_view]
for each row
begin
    update [.ref-values] set
     [ObjectID] = new.[ObjectID] ,
     ctlv = new.ctlv,
    PropertyID = new.PropertyID, PropIndex = new.PropIndex, [Value] = new.[Value],
    ExtData = new.ExtData
    where [ObjectID] = old.[ObjectID] and [PropertyID] = old.[PropertyID] and [PropIndex] = old.[PropIndex];
end;

create trigger if not exists values_view_Delete instead of delete on [.ref-values_view]
for each row
begin
    delete from [.ref-values]
   where [ObjectID] = old.[ObjectID]
       and [PropertyID] = old.[PropertyID] and [PropIndex] = old.[PropIndex];
end;


-- END --