

PRAGMA page_size = 8192;
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = 1;
PRAGMA encoding = 'UTF-8';
PRAGMA recursive_triggers = 1;

------------------------------------------------------------------------------------------
-- .generators
------------------------------------------------------------------------------------------
create table [.generators] (name TEXT primary key, seq integer) without rowid;

/* -- Sample of generating ID
  insert or replace into [.generators] (name, seq) select '.objects',
  coalesce((select seq from [.generators] where name = '.objects') , 0) + 1 ;
*/

------------------------------------------------------------------------------------------
-- .access_rules
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.access_rules] (
  [UserRoleID] GUID NOT NULL,
  [ItemType]   CHAR NOT NULL,
  [Access]     CHAR NOT NULL,
  [ItemID]     INT  NOT NULL,
  CONSTRAINT [sqlite_autoindex_AccessRules_1] PRIMARY KEY ([UserRoleID], [ItemType], [ItemID])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxAccessRulesByItemID] ON [.access_rules] ([ItemID]);

------------------------------------------------------------------------------------------
-- .change_log
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.change_log] (
  [ID]        INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [TimeStamp] DATETIME NOT NULL             DEFAULT (julianday('now')),
  [OldKey],
  [OldValue]  JSON1,
  [KEY],
  [Value]     JSON1,

  -- TODO Implement function
  [ChangedBy] GUID              -- DEFAULT (GetCurrentUserID())
);


-- TODO Check if these indexes are needed?
-- CREATE INDEX IF NOT EXISTS [idxChangeLogByNew] ON [.change_log] ([Key]) WHERE [Key] IS NOT NULL;
--
-- CREATE INDEX IF NOT EXISTS [idxChangeLogByOld] ON [.change_log] ([OldKey]) WHERE [OldKey] IS NOT NULL;
--
-- CREATE INDEX IF NOT EXISTS [idxChangeLogByChangedBy] ON [.change_log] ([ChangedBy], [TimeStamp]) WHERE ChangedBy IS NOT NULL;

------------------------------------------------------------------------------------------
-- .classes
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.classes] (
  [ClassID]           INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassName]         TEXT(64) NOT NULL,
  -- [ClassTitle] TEXT NOT NULL,
  [SchemaID]          GUID     NOT NULL             DEFAULT (randomblob(16)),
  [SystemClass]       BOOL     NOT NULL             DEFAULT 0,
  [DefaultScalarType] TEXT     NOT NULL             DEFAULT 'text',
  [TitlePropertyID]   INTEGER CONSTRAINT [fkClassesTitleToClasses] REFERENCES [.classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE RESTRICT,
  [SubTitleProperty]  INTEGER CONSTRAINT [fkClassesSubTitleToClasses] REFERENCES [.classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE RESTRICT,
  [SchemaXML]         TEXT,
  [SchemaOutdated]    BOOLEAN  NOT NULL             DEFAULT 0,
  [MinOccurences]     INTEGER  NOT NULL             DEFAULT 0,
  [MaxOccurences]     INTEGER  NOT NULL             DEFAULT ((1 << 32) - 1),
  [DBViewName]        TEXT,
  [ctloMask]          INTEGER  NOT NULL             DEFAULT (0), -- Aggregated value for all indexing for assigned columns (A-P). Updated by trigger on ClassProperty update
  /* Additional custom data*/
  [ExtData]           JSON1,
  [ValidateRegex]     TEXT NULL,
  [MaxLength]         INT      NOT NULL             DEFAULT -1,

  CONSTRAINT [chkClasses_DefaultScalarType] CHECK (DefaultScalarType IN
                                                   ('text', 'integer', 'number', 'boolean', 'date', 'datetime', 'time', 'guid', 'enum', 'point', 'binary', 'serial', 'object',
                                                              'blob', 'timespan', 'integer-range', 
                                                              'number-range', 'datetime-range'))
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClasses_byClassName] ON [.classes] ([ClassName]);

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterInsert]
AFTER INSERT
ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([KEY], [Value]) VALUES (
    printf('@%s', new.ClassID),
    json_set('{}',
             CASE WHEN new.ClassName IS NULL
               THEN NULL
             ELSE "$.ClassName" END, new.ClassName,
             CASE WHEN new.SystemClass IS NULL
               THEN NULL
             ELSE "$.SystemClass" END, new.SystemClass,
             CASE WHEN new.DefaultScalarType IS NULL
               THEN NULL
             ELSE "$.DefaultScalarType" END, new.DefaultScalarType,
             CASE WHEN new.TitlePropertyID IS NULL
               THEN NULL
             ELSE "$.TitlePropertyID" END, new.TitlePropertyID,
             CASE WHEN new.SubTitleProperty IS NULL
               THEN NULL
             ELSE "$.SubTitleProperty" END, new.ClassName,
             CASE WHEN new.SchemaOutdated IS NULL
               THEN NULL
             ELSE "$.SchemaOutdated" END, new.SchemaOutdated,
             CASE WHEN new.MinOccurences IS NULL
               THEN NULL
             ELSE "$.MinOccurences" END, new.MinOccurences,
             CASE WHEN new.MaxOccurences IS NULL
               THEN NULL
             ELSE "$.MaxOccurences" END, new.MaxOccurences,
             CASE WHEN new.DBViewName IS NULL
               THEN NULL
             ELSE "$.DBViewName" END, new.DBViewName,
             CASE WHEN new.ctloMask IS NULL
               THEN NULL
             ELSE "$.ctloMask" END, new.ctloMask,
             CASE WHEN new.SchemaXML IS NULL
               THEN NULL
             ELSE "$.SchemaXML" END, new.SchemaXML,
             CASE WHEN new.SchemaID IS NULL
               THEN NULL
             ELSE "$.SchemaID" END, hex(new.SchemaID),
             CASE WHEN new.ValidateRegex IS NULL
               THEN NULL
             ELSE "$.ValidateRegex" END, new.ValidateRegex,
             CASE WHEN new.MaxLength IS NULL
               THEN NULL
             ELSE "$.MaxLength" END, new.MaxLength,
             CASE WHEN new.ExtData IS NULL
               THEN NULL
             ELSE "$.ExtData" END, new.ExtData
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
        CASE WHEN nullif(new.ClassName, old.ClassName) IS NULL
          THEN NULL
        ELSE "$.ClassName" END,
        new.ClassName,
        CASE WHEN nullif(new.SystemClass, old.SystemClass) IS NULL
          THEN NULL
        ELSE "$.SystemClass" END,
        new.SystemClass,
        CASE WHEN nullif(new.DefaultScalarType, old.DefaultScalarType) IS NULL
          THEN NULL
        ELSE "$.DefaultScalarType" END,
        new.DefaultScalarType,
        CASE WHEN nullif(new.TitlePropertyID,old.TitlePropertyID) IS NULL
          THEN NULL
        ELSE "$.TitlePropertyID" END,
        new.TitlePropertyID,
        CASE WHEN nullif(new.SubTitleProperty, old.SubTitleProperty) IS NULL
          THEN NULL
        ELSE "$.SubTitleProperty" END,
        new.ClassName,
        CASE WHEN nullif(new.SchemaOutdated,old.SchemaOutdated) IS NULL
          THEN NULL
        ELSE "$.SchemaOutdated" END,
        new.SchemaOutdated,
        CASE WHEN nullif(new.MinOccurences, old.MinOccurences) IS NULL
          THEN NULL
        ELSE "$.MinOccurences" END,
        new.MinOccurences,
        CASE WHEN nullif(new.MaxOccurences,old.MaxOccurences) IS NULL
          THEN NULL
        ELSE "$.MaxOccurences" END,
        new.MaxOccurences,
        CASE WHEN nullif(new.DBViewName, old.DBViewName) IS NULL
          THEN NULL
        ELSE "$.DBViewName" END,
        new.DBViewName,
        CASE WHEN new.ctloMask IS NULL
          THEN NULL
        ELSE "$.ctloMask" END,
        new.ctloMask,
        CASE WHEN nullif(new.SchemaXML,old.SchemaXML) IS NULL
          THEN NULL
        ELSE "$.SchemaXML" END,
        new.SchemaXML,
        CASE WHEN nullif(new.SchemaID,old.SchemaID) IS NULL
          THEN NULL
        ELSE "$.SchemaID" END,
        hex(new.SchemaID),
        CASE WHEN nullif(new.ValidateRegex, old.ValidateRegex) IS NULL
          THEN NULL
        ELSE "$.ValidateRegex" END,
        new.ValidateRegex,
        CASE WHEN nullif(new.MaxLength, old.MaxLength) IS NULL
          THEN NULL
        ELSE "$.MaxLength" END,
        new.MaxLength,
        CASE WHEN nullif(new.ExtData, old.ExtData) IS NULL
          THEN NULL
        ELSE "$.ExtData" END,
        new.ExtData
        ) AS [OldValue],

        '@' || CAST(new.ClassID AS TEXT)                                                  AS [KEY],


                json_set('{}',
        CASE WHEN nullif(new.ClassName, old.ClassName) IS NULL
          THEN NULL
        ELSE "$.ClassName" END,
        old.ClassName,
        CASE WHEN nullif(new.SystemClass, old.SystemClass) IS NULL
          THEN NULL
        ELSE "$.SystemClass" END,
        old.SystemClass,
        CASE WHEN nullif(new.DefaultScalarType, old.DefaultScalarType) IS NULL
          THEN NULL
        ELSE "$.DefaultScalarType" END,
        old.DefaultScalarType,
        CASE WHEN nullif(new.TitlePropertyID,old.TitlePropertyID) IS NULL
          THEN NULL
        ELSE "$.TitlePropertyID" END,
        old.TitlePropertyID,
        CASE WHEN nullif(new.SubTitleProperty, old.SubTitleProperty) IS NULL
          THEN NULL
        ELSE "$.SubTitleProperty" END,
        old.ClassName,
        CASE WHEN nullif(new.SchemaOutdated,old.SchemaOutdated) IS NULL
          THEN NULL
        ELSE "$.SchemaOutdated" END,
        old.SchemaOutdated,
        CASE WHEN nullif(new.MinOccurences, old.MinOccurences) IS NULL
          THEN NULL
        ELSE "$.MinOccurences" END,
        old.MinOccurences,
        CASE WHEN nullif(new.MaxOccurences,old.MaxOccurences) IS NULL
          THEN NULL
        ELSE "$.MaxOccurences" END,
        old.MaxOccurences,
        CASE WHEN nullif(new.DBViewName, old.DBViewName) IS NULL
          THEN NULL
        ELSE "$.DBViewName" END,
        old.DBViewName,
        CASE WHEN new.ctloMask IS NULL
          THEN NULL
        ELSE "$.ctloMask" END,
        old.ctloMask,
        CASE WHEN nullif(new.SchemaXML,old.SchemaXML) IS NULL
          THEN NULL
        ELSE "$.SchemaXML" END,
        old.SchemaXML,
        CASE WHEN nullif(new.SchemaID,old.SchemaID) IS NULL
          THEN NULL
        ELSE "$.SchemaID" END,
        hex(old.SchemaID),
        CASE WHEN nullif(new.ValidateRegex, old.ValidateRegex) IS NULL
          THEN NULL
        ELSE "$.ValidateRegex" END,
        old.ValidateRegex,
        CASE WHEN nullif(new.MaxLength, old.MaxLength) IS NULL
          THEN NULL
        ELSE "$.MaxLength" END,
        old.MaxLength,
        CASE WHEN nullif(new.ExtData, old.ExtData) IS NULL
          THEN NULL
        ELSE "$.ExtData" END,
        old.ExtData
        )
        AS [Value]
    )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdateOfctloMask]
AFTER UPDATE OF [ctloMask]
ON [.classes]
FOR EACH ROW
BEGIN
  UPDATE [.objects]
  SET [ctlo] = new.[ctloMask]
  WHERE ClassID = new.ClassID;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterDelete]
AFTER DELETE
ON [.classes]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue]) VALUES (
    printf('@%s', old.ClassID),

    json_set('{}',
        CASE WHEN old.ClassName IS NULL THEN NULL ELSE '$.ClassName' END,
          old.ClassName,
          CASE WHEN old.SystemClass IS NULL THEN NULL ELSE '$.SystemClass' END,
          old.SystemClass,
          CASE WHEN old.DefaultScalarType IS NULL THEN NULL ELSE '$.DefaultScalarType' END,
          old.DefaultScalarType,
          CASE WHEN old.TitlePropertyID IS NULL THEN NULL ELSE '$.TitlePropertyID' END,
          old.TitlePropertyID,
          CASE WHEN old.SubTitleProperty IS NULL THEN NULL ELSE '$.SubTitleProperty' END,
          old.SubTitleProperty,
          CASE WHEN old.SchemaXML IS NULL THEN NULL ELSE '$.SchemaXML' END,
          old.SchemaXML,
          CASE WHEN old.SchemaOutdated IS NULL THEN NULL ELSE '$.SchemaOutdated' END,
          old.SchemaOutdated,
          CASE WHEN old.MinOccurences IS NULL THEN NULL ELSE '$.MinOccurences' END,
          old.MinOccurences,
          CASE WHEN old.MaxOccurences IS NULL THEN NULL ELSE '$.MaxOccurences' END,
          old.MaxOccurences,
          CASE WHEN old.DBViewName IS NULL THEN NULL ELSE '$.DBViewName' END,
          old.DBViewName,
          CASE WHEN old.ctloMask IS NULL THEN NULL ELSE '$.ctloMask' END,
          old.ctloMask,
          CASE WHEN old.ValidateRegex IS NULL THEN NULL ELSE '$.ValidateRegex' END,
          old.ValidateRegex,
          CASE WHEN old.MaxLength IS NULL THEN NULL ELSE '$.MaxLength' END,
          old.MaxLength,
          CASE WHEN old.ExtData IS NULL THEN NULL ELSE '$.ExtData' END,
          old.ExtData

    )
  );
END;

------------------------------------------------------------------------------------------
-- [.class_properties]
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.class_properties] (
  [ClassID]            INTEGER NOT NULL CONSTRAINT [fkClassPropertiesClassID] REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE CASCADE,
  [PropertyID]         INTEGER NOT NULL CONSTRAINT [fkClassPropertiesPropertyID] REFERENCES [.classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE CASCADE,
  [PropertyName]       TEXT(64),
  [TrackChanges]       BOOLEAN NOT NULL DEFAULT 1,
  [DefaultValue],
  [ctlo]               INTEGER NOT NULL DEFAULT 0,
  [ctloMask]           INTEGER NOT NULL DEFAULT 0,
  [DefaultDataType]    INTEGER,
  [MinOccurences]      INTEGER NOT NULL DEFAULT 0,
  [MaxOccurences]      INTEGER NOT NULL DEFAULT 1,
  [UNIQUE]             BOOLEAN NOT NULL DEFAULT 0,
  [ColumnAssigned]     CHAR,
  [AutoValue]          TEXT, -- TODO Comments: sequence ID, current date, guid, current date on insert
  [MaxLength]          INTEGER NOT NULL DEFAULT (-1),
  [TempColumnAssigned] CHAR,

  /*
  These 2 properties define 'reference' property.
  ReversePropertyID is optional and used for reversed access from referenced class.
  If not null, [.class_properties] table must contain record with combination ClassID=ReferencedClassID
  and PropertyID=ReversePropertyID
  */
  [ReferencedClassID]  INTEGER NULL,
  [ReversePropertyID]  INTEGER NULL,
  [INDEXED]            BOOLEAN NOT NULL DEFAULT 0,
  [ValidationRegex]    TEXT    NOT NULL DEFAULT '',

  /* Additional custom data*/
  [ExtData]            JSON1,

  /*
  ctlv is used for indexing and processing control. Possible values (the same as Values.ctlv):
    0 - Index
    1-3 - reference
        2(3 as bit 0 is set) - regular ref
        4(5) - ref: A -> B. When A deleted, delete B
        6(7) - when B deleted, delete A
        8(9) - when A or B deleted, delete counterpart
        10(11) - cannot delete A until this reference exists
        12(13) - cannot delete B until this reference exists
        14(15) - cannot delete A nor B until this reference exist

    16 - full text data
    32 - range data
    64 - DON'T track changes
  */
  [ctlv]               INTEGER NOT NULL DEFAULT (0),

  CONSTRAINT [chkClassPropertiesColumnAssigned] CHECK (ColumnAssigned IS NULL OR ColumnAssigned BETWEEN 'A' AND 'P'),
  CONSTRAINT [chkClassPropertiesAutoValue] CHECK (
    [AutoValue] IS NULL /* No auto value*/
    OR
    [AutoValue] IN (
      /* These values are used as instructions for view regeneration */
      'G', /* New Guid on insert */
      'T', /* CURRENT_TIMESTAMP on insert*/
      'N', /* CURRENT_TIMESTAMP on insert and update*/
      'I', /* Counter - increment on every update*/
      'U' /* Current user ID */
    )
    OR instr([AutoValue], 'H:') = 1
    /* 'H:column_chars' - Hash value (32-bit REAL) of 1 or more columns, specified by letters A - P. Normally used for indexing and fast lookup by group of columns. Example: H:CFJ */
  ),
  CONSTRAINT [sqlite_autoindex_ClassProperties_1] PRIMARY KEY ([ClassID], [PropertyID])
) WITHOUT ROWID;

CREATE UNIQUE INDEX IF NOT EXISTS [idxClassPropertiesColumnAssigned] ON [.class_properties] ([ClassID], [ColumnAssigned]) WHERE ColumnAssigned IS NOT NULL;


CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesAfterInsert]
AFTER INSERT
ON [.class_properties]
FOR EACH ROW
BEGIN
  UPDATE [.classes]
  SET SchemaOutdated = 1
  WHERE ClassID = new.ClassID;

  INSERT INTO [.change_log] ([KEY], [Value]) VALUES (
    printf('@%s/%s', new.ClassID, new.PropertyID),
    json_set('{}',

    CASE WHEN new.PropertyName IS NULL THEN NULL ELSE '$.PropertyName' END, new.[PropertyName],
       CASE WHEN new.TrackChanges IS NULL THEN NULL ELSE '$.TrackChanges' END, new.[TrackChanges],
       CASE WHEN new.DefaultValue IS NULL THEN NULL ELSE '$.DefaultValue' END, new.[DefaultValue],
       CASE WHEN new.DefaultDataType IS NULL THEN NULL ELSE '$.DefaultDataType' END, new.[DefaultDataType],
       CASE WHEN new.MinOccurences IS NULL THEN NULL ELSE '$.MinOccurences' END, new.[MinOccurences],
       CASE WHEN new.MaxOccurences IS NULL THEN NULL ELSE '$.MaxOccurences' END, new.[MaxOccurences],
       CASE WHEN new.[UNIQUE] IS NULL THEN NULL ELSE '$.Unique' END, new.[UNIQUE],
       CASE WHEN new.ColumnAssigned IS NULL THEN NULL ELSE '$.ColumnAssigned' END, new.[ColumnAssigned],
       CASE WHEN new.AutoValue IS NULL THEN NULL ELSE '$.AutoValue' END, new.[AutoValue],
       CASE WHEN new.MaxLength IS NULL THEN NULL ELSE '$.MaxLength' END, new.[MaxLength],
       CASE WHEN new.TempColumnAssigned IS NULL THEN NULL ELSE '$.TempColumnAssigned' END, new.[TempColumnAssigned],
       CASE WHEN new.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, new.[ctlo],
       CASE WHEN new.ctloMask IS NULL THEN NULL ELSE '$.ctloMask' END, new.[ctloMask],
       CASE WHEN new.ctlv IS NULL THEN NULL ELSE '$.ctlv' END, new.[ctlv],
       CASE WHEN new.ReferencedClassID IS NULL THEN NULL ELSE '$.ReferencedClassID' END, new.[ReferencedClassID],
       CASE WHEN new.ReversePropertyID IS NULL THEN NULL ELSE '$.ReversePropertyID' END, new.[ReversePropertyID],
       CASE WHEN new.ValidationRegex IS NULL THEN NULL ELSE '$.ValidationRegex' END, new.[ValidationRegex],
       CASE WHEN new.ExtData IS NULL THEN NULL ELSE '$.ExtData' END, new.[ExtData]
));


  -- Determine last unused column (A to P), if any
  -- This update might fire trigClassPropertiesColumnAssignedBecameNotNull
  UPDATE [.class_properties]
  SET TempColumnAssigned = coalesce([ColumnAssigned],
                                    nullif(char((SELECT coalesce(unicode(max(ColumnAssigned)), unicode('A') - 1)
                                                 FROM [.class_properties]
                                                 WHERE ClassID = new.ClassID AND PropertyID <> new.PropertyID AND
                                                       ColumnAssigned IS NOT NULL
                                                 ORDER BY ClassID, ColumnAssigned
                                                   DESC
                                                 LIMIT 1) + 1), 'Q')),
    [ColumnAssigned]     = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID AND new.[ColumnAssigned] IS NULL
        AND new.[MaxLength] BETWEEN 0 AND 255;

  -- Restore ColumnAssigned to refactor existing data (from Values to [.objects])
  UPDATE [.class_properties]
  SET ColumnAssigned = TempColumnAssigned, TempColumnAssigned = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID AND new.[MaxLength] BETWEEN 0 AND 255;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesColumnAssignedBecameNull]
AFTER UPDATE OF [ColumnAssigned]
ON [.class_properties]
FOR EACH ROW
  WHEN old.[ColumnAssigned] IS NOT NULL AND new.[ColumnAssigned] IS NULL
BEGIN
  UPDATE [.classes]
  SET SchemaOutdated = 1
  WHERE ClassID = new.ClassID;

  -- ColumnAssigned is set to null from letter.
  -- Need to copy data to Values table and reset column in [.objects]
  INSERT OR REPLACE INTO [.VALUES] ([ClassID], [ObjectID], [PropertyID], [PropIndex], [ctlv], [Value])
    SELECT
      new.[ClassID],
      [ObjectID],
      (SELECT [PropertyID]
       FROM [.class_properties]
       WHERE ClassID = new.[ClassID] AND [ColumnAssigned] = old.[ColumnAssigned] AND [ColumnAssigned] IS NOT NULL),
      0,
      new.ctlv,
      CASE
      WHEN old.ColumnAssigned = 'A'
        THEN A
      WHEN old.ColumnAssigned = 'B'
        THEN B
      WHEN old.ColumnAssigned = 'C'
        THEN C
      WHEN old.ColumnAssigned = 'D'
        THEN D
      WHEN old.ColumnAssigned = 'E'
        THEN E
      WHEN old.ColumnAssigned = 'F'
        THEN F
      WHEN old.ColumnAssigned = 'G'
        THEN G
      WHEN old.ColumnAssigned = 'H'
        THEN H
      WHEN old.ColumnAssigned = 'I'
        THEN I
      WHEN old.ColumnAssigned = 'J'
        THEN J
      WHEN old.ColumnAssigned = 'K'
        THEN K
      WHEN old.ColumnAssigned = 'L'
        THEN L
      WHEN old.ColumnAssigned = 'M'
        THEN M
      WHEN old.ColumnAssigned = 'N'
        THEN N
      WHEN old.ColumnAssigned = 'O'
        THEN O
      WHEN old.ColumnAssigned = 'P'
        THEN P
      ELSE NULL
      END
    FROM [.objects]
    WHERE [ClassID] = new.[ClassID];

  UPDATE [.objects]
  SET
    A = CASE WHEN old.ColumnAssigned = 'A'
      THEN NULL
        ELSE A END,
    B = CASE WHEN old.ColumnAssigned = 'B'
      THEN NULL
        ELSE A END,
    C = CASE WHEN old.ColumnAssigned = 'C'
      THEN NULL
        ELSE A END,
    D = CASE WHEN old.ColumnAssigned = 'D'
      THEN NULL
        ELSE A END,
    E = CASE WHEN old.ColumnAssigned = 'E'
      THEN NULL
        ELSE A END,
    F = CASE WHEN old.ColumnAssigned = 'F'
      THEN NULL
        ELSE A END,
    G = CASE WHEN old.ColumnAssigned = 'G'
      THEN NULL
        ELSE A END,
    H = CASE WHEN old.ColumnAssigned = 'H'
      THEN NULL
        ELSE A END,
    I = CASE WHEN old.ColumnAssigned = 'I'
      THEN NULL
        ELSE A END,
    J = CASE WHEN old.ColumnAssigned = 'J'
      THEN NULL
        ELSE A END,
    K = CASE WHEN old.ColumnAssigned = 'K'
      THEN NULL
        ELSE A END,
    L = CASE WHEN old.ColumnAssigned = 'L'
      THEN NULL
        ELSE A END,
    M = CASE WHEN old.ColumnAssigned = 'M'
      THEN NULL
        ELSE A END,
    N = CASE WHEN old.ColumnAssigned = 'N'
      THEN NULL
        ELSE A END,
    O = CASE WHEN old.ColumnAssigned = 'O'
      THEN NULL
        ELSE A END,
    P = CASE WHEN old.ColumnAssigned = 'P'
      THEN NULL
        ELSE A END
  WHERE [ClassID] = new.[ClassID];
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesColumnAssignedChange]
AFTER UPDATE OF [ColumnAssigned]
ON [.class_properties]
FOR EACH ROW
  WHEN old.[ColumnAssigned] IS NOT NULL AND new.[ColumnAssigned] IS NOT NULL
BEGIN
  -- Force ColumnAssigned to be NULL to refactor existing data (from [.objects] to Values)
  UPDATE [.class_properties]
  SET TempColumnAssigned = new.[ColumnAssigned], ColumnAssigned = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID;

  -- Restore ColumnAssigned to refactor existing data (from Values to [.objects])
  UPDATE [.class_properties]
  SET ColumnAssigned = TempColumnAssigned, TempColumnAssigned = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassProperties_UpdateOfctlo]
AFTER UPDATE OF [ctlo], [ctloMask]
ON [.class_properties]
FOR EACH ROW
BEGIN
  UPDATE [.classes]
  SET ctloMask = (ctloMask & ~new.ctloMask) | new.ctlo
  WHERE ClassID = new.ClassID;
END;

/* General trigger after update of ClassProperties. Track Changes */
CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesAfterUpdate]
AFTER UPDATE ON [.class_properties]
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
         '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT) || '/' ||
         CAST(nullif(old.PropertyID, new.PropertyID) AS TEXT)           AS [OldKey],

        json_set('{}',
         CASE WHEN nullif(new.PropertyName, old.PropertyName) IS NULL THEN NULL ELSE '$.PropertyName' END, new.PropertyName,
          CASE WHEN nullif(new.TrackChanges, old.TrackChanges) IS NULL THEN NULL ELSE '$.TrackChanges' END, new.TrackChanges,
          CASE WHEN nullif(new.DefaultValue, old.DefaultValue) IS NULL THEN NULL ELSE '$.DefaultValue' END, new.DefaultValue,
          CASE WHEN nullif(new.DefaultDataType, old.DefaultDataType) IS NULL THEN NULL ELSE '$.DefaultDataType' END, new.DefaultDataType,
          CASE WHEN nullif(new.MinOccurences, old.MinOccurences) IS NULL THEN NULL ELSE '$.MinOccurences' END, new.MinOccurences,
          CASE WHEN nullif(new.MaxOccurences, old.MaxOccurences) IS NULL THEN NULL ELSE '$.MaxOccurences' END, new.MaxOccurences,
          CASE WHEN nullif(new.[UNIQUE], old.[UNIQUE]) IS NULL THEN NULL ELSE '$.Unique' END, new.[UNIQUE],
          CASE WHEN nullif(new.ColumnAssigned, old.ColumnAssigned) IS NULL THEN NULL ELSE '$.ColumnAssigned' END, new.ColumnAssigned,
          CASE WHEN nullif(new.AutoValue, old.AutoValue) IS NULL THEN NULL ELSE '$.AutoValue' END, new.AutoValue,
          CASE WHEN nullif(new.MaxLength, old.MaxLength) IS NULL THEN NULL ELSE '$.MaxLength' END, new.MaxLength,
          CASE WHEN nullif(new.TempColumnAssigned, old.TempColumnAssigned) IS NULL THEN NULL ELSE '$.TempColumnAssigned' END, new.TempColumnAssigned,
          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, new.ctlo,
          CASE WHEN nullif(new.ctloMask, old.ctloMask) IS NULL THEN NULL ELSE '$.ctloMask' END, new.ctloMask,
          CASE WHEN nullif(new.ReferencedClassID, old.ReferencedClassID) IS NULL THEN NULL ELSE '$.ReferencedClassID' END, new.ReferencedClassID,
          CASE WHEN nullif(new.ReversePropertyID, old.ReversePropertyID) IS NULL THEN NULL ELSE '$.ReversePropertyID' END, new.ReversePropertyID,
          CASE WHEN nullif(new.ctlv, old.ctlv) IS NULL THEN NULL ELSE '$.ctlv' END, new.ctlv,
          CASE WHEN nullif(new.ExtData, old.ExtData) IS NULL THEN NULL ELSE '$.ExtData' END, new.ExtData,
          CASE WHEN nullif(new.ValidationRegex, old.ValidationRegex) IS NULL THEN NULL ELSE '$.ValidationRegex' END, new.ValidationRegex,
          CASE WHEN nullif(new.MaxLength, old.MaxLength) IS NULL THEN NULL ELSE '$.MaxLength' END, new.MaxLength
               ) AS [OldValue],

         printf('@%s/%s', new.ClassID, new.PropertyID)                  AS [KEY],

         json_set('{}',
         CASE WHEN nullif(new.PropertyName, old.PropertyName) IS NULL THEN NULL ELSE '$.PropertyName' END, old.PropertyName,
          CASE WHEN nullif(new.TrackChanges, old.TrackChanges) IS NULL THEN NULL ELSE '$.TrackChanges' END, old.TrackChanges,
          CASE WHEN nullif(new.DefaultValue, old.DefaultValue) IS NULL THEN NULL ELSE '$.DefaultValue' END, old.DefaultValue,
          CASE WHEN nullif(new.DefaultDataType, old.DefaultDataType) IS NULL THEN NULL ELSE '$.DefaultDataType' END, old.DefaultDataType,
          CASE WHEN nullif(new.MinOccurences, old.MinOccurences) IS NULL THEN NULL ELSE '$.MinOccurences' END, old.MinOccurences,
          CASE WHEN nullif(new.MaxOccurences, old.MaxOccurences) IS NULL THEN NULL ELSE '$.MaxOccurences' END, old.MaxOccurences,
          CASE WHEN nullif(new.[UNIQUE], old.[UNIQUE]) IS NULL THEN NULL ELSE '$.Unique' END, old.[UNIQUE],
          CASE WHEN nullif(new.ColumnAssigned, old.ColumnAssigned) IS NULL THEN NULL ELSE '$.ColumnAssigned' END, old.ColumnAssigned,
          CASE WHEN nullif(new.AutoValue, old.AutoValue) IS NULL THEN NULL ELSE '$.AutoValue' END, old.AutoValue,
          CASE WHEN nullif(new.MaxLength, old.MaxLength) IS NULL THEN NULL ELSE '$.MaxLength' END, old.MaxLength,
          CASE WHEN nullif(new.TempColumnAssigned, old.TempColumnAssigned) IS NULL THEN NULL ELSE '$.TempColumnAssigned' END, old.TempColumnAssigned,
          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo,
          CASE WHEN nullif(new.ctloMask, old.ctloMask) IS NULL THEN NULL ELSE '$.ctloMask' END, old.ctloMask,
          CASE WHEN nullif(new.ReferencedClassID, old.ReferencedClassID) IS NULL THEN NULL ELSE '$.ReferencedClassID' END, old.ReferencedClassID,
          CASE WHEN nullif(new.ReversePropertyID, old.ReversePropertyID) IS NULL THEN NULL ELSE '$.ReversePropertyID' END, old.ReversePropertyID,
          CASE WHEN nullif(new.ctlv, old.ctlv) IS NULL THEN NULL ELSE '$.ctlv' END, old.ctlv,
          CASE WHEN nullif(new.ExtData, old.ExtData) IS NULL THEN NULL ELSE '$.ExtData' END, old.ExtData,
          CASE WHEN nullif(new.ValidationRegex, old.ValidationRegex) IS NULL THEN NULL ELSE '$.ValidationRegex' END, old.ValidationRegex,
          CASE WHEN nullif(new.MaxLength, old.MaxLength) IS NULL THEN NULL ELSE '$.MaxLength' END, old.MaxLength
               ) AS [Value]
      )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [KEY])) IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesColumnAssignedBecameNotNull]
AFTER UPDATE OF [ColumnAssigned]
ON [.class_properties]
FOR EACH ROW
  WHEN new.[ColumnAssigned] IS NOT NULL AND old.[ColumnAssigned] IS NULL
BEGIN
  UPDATE [.classes]
  SET SchemaOutdated = 1
  WHERE ClassID = new.ClassID;

  -- Copy attributes from [.values] table to [.objects] table, based on ColumnAssigned
  -- Only primitive values (not references: ctlv = 0) and (XML) attributes (PropIndex = 0) are processed
  -- Copy attributes from Values table to [.objects] table, based on ColumnAssigned
  -- Only primitive values (not references: ctlv = 0) and attributes (PropIndex = 0) are processed
  UPDATE [.objects]
  SET
    A = CASE WHEN new.[ColumnAssigned] = 'A'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE A END,

    B = CASE WHEN new.[ColumnAssigned] = 'B'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE B END,

    C = CASE WHEN new.[ColumnAssigned] = 'C'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE C END,

    D = CASE WHEN new.[ColumnAssigned] = 'D'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE D END,

    E = CASE WHEN new.[ColumnAssigned] = 'E'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE E END,

    F = CASE WHEN new.[ColumnAssigned] = 'F'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE F END,

    G = CASE WHEN new.[ColumnAssigned] = 'G'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE G END,

    H = CASE WHEN new.[ColumnAssigned] = 'H'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE H END,

    I = CASE WHEN new.[ColumnAssigned] = 'I'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE I END,

    J = CASE WHEN new.[ColumnAssigned] = 'J'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE J END,

    K = CASE WHEN new.[ColumnAssigned] = 'K'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE K END,

    L = CASE WHEN new.[ColumnAssigned] = 'L'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE L END,

    M = CASE WHEN new.[ColumnAssigned] = 'M'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE M END,

    N = CASE WHEN new.[ColumnAssigned] = 'N'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE N END,

    O = CASE WHEN new.[ColumnAssigned] = 'O'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE O END,

    P = CASE WHEN new.[ColumnAssigned] = 'P'
      THEN (SELECT [Value]
            FROM [.VALUES] v
            WHERE
              v.ObjectID = [.objects].ObjectID AND
              v.PropertyID = new.PropertyID
              AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
            LIMIT 1)
        ELSE P END
  WHERE ClassID = new.ClassID;

  -- Indirectly update aggregated control settings on class level (through ctloMask)
  UPDATE [.class_properties]
  SET
    ctlo     = (SELECT (1 << idx) | (1 << (idx + 16)) << (1 << (idx + 32))
                FROM (SELECT (unicode(new.[ColumnAssigned]) - unicode('A') + 1) AS idx)),
    ctloMask = (SELECT (ctlv & 1) << idx | /* Indexed*/
                       ((ctlv & 16) <> 0) << (idx + 16) | /* Full text search */
                       ((ctlv & 32) <> 0) << (idx + 32) /* Range data */
                FROM (SELECT (unicode(new.[ColumnAssigned]) - unicode('A') + 1) AS idx))
  WHERE [ClassID] = new.[ClassID] AND [PropertyID] = new.[PropertyID];

  -- Delete copied attributes from Values table
  DELETE FROM [.VALUES]
  WHERE ObjectID = (SELECT ObjectID
                    FROM [.objects]
                    WHERE ClassID = new.ClassID)
        AND PropertyID = new.PropertyID AND PropIndex = 0 AND (ctlv & 14) = 0;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesAfterDelete]
AFTER DELETE
ON [.class_properties]
FOR EACH ROW
BEGIN
  UPDATE [.classes]
  SET SchemaOutdated = 1
  WHERE ClassID = old.ClassID;

  INSERT INTO [.change_log] ([OldKey], [OldValue]) VALUES (
    printf('@%s/%s', old.ClassID, old.PropertyID),
    json_set('{}',
  CASE WHEN old.PropertyName IS NULL THEN NULL ELSE '$.PropertyName' END, old.PropertyName,
      CASE WHEN old.TrackChanges IS NULL THEN NULL ELSE '$.TrackChanges' END, old.TrackChanges,
      CASE WHEN old.DefaultValue IS NULL THEN NULL ELSE '$.DefaultValue' END, old.DefaultValue,
      CASE WHEN old.DefaultDataType IS NULL THEN NULL ELSE '$.DefaultDataType' END, old.DefaultDataType,
      CASE WHEN old.MinOccurences IS NULL THEN NULL ELSE '$.MinOccurences' END, old.MinOccurences,
      CASE WHEN old.MaxOccurences IS NULL THEN NULL ELSE '$.MaxOccurences' END, old.MaxOccurences,
      CASE WHEN old.[UNIQUE] IS NULL THEN NULL ELSE '$.Unique' END, old.[UNIQUE],
      CASE WHEN old.ColumnAssigned IS NULL THEN NULL ELSE '$.ColumnAssigned' END, old.ColumnAssigned,
      CASE WHEN old.AutoValue IS NULL THEN NULL ELSE '$.AutoValue' END, old.AutoValue,
      CASE WHEN old.MaxLength IS NULL THEN NULL ELSE '$.MaxLength' END, old.MaxLength,
      CASE WHEN old.TempColumnAssigned IS NULL THEN NULL ELSE '$.TempColumnAssigned' END, old.TempColumnAssigned,
      CASE WHEN old.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo,
      CASE WHEN old.ctloMask IS NULL THEN NULL ELSE '$.ctloMask' END, old.ctloMask,
      CASE WHEN old.ctlv IS NULL THEN NULL ELSE '$.ctlv' END, old.ctlv,
      CASE WHEN old.ReferencedClassID IS NULL THEN NULL ELSE '$.ReferencedClassID' END, old.ReferencedClassID,
      CASE WHEN old.ReversePropertyID IS NULL THEN NULL ELSE '$.ReversePropertyID' END, old.ReversePropertyID,
      CASE WHEN old.ExtData IS NULL THEN NULL ELSE '$.ExtData' END, old.ExtData,
      CASE WHEN old.MaxLength IS NULL THEN NULL ELSE '$.MaxLength' END, old.MaxLength)
  );

  -- ColumnAssigned is set to null from letter.
  -- Need to copy data to Values table and reset column in [.objects]
  INSERT OR REPLACE INTO [.VALUES] ([ClassID], [ObjectID], [PropertyID], [PropIndex], [ctlv], [Value])
    SELECT
      old.[ClassID],
      [ObjectID],
      (SELECT [PropertyID]
       FROM [.class_properties]
       WHERE ClassID = old.[ClassID] AND [ColumnAssigned] = old.[ColumnAssigned] AND [ColumnAssigned] IS NOT NULL),
      0,
      old.ctlv,
      CASE
      WHEN old.ColumnAssigned = 'A'
        THEN A
      WHEN old.ColumnAssigned = 'B'
        THEN B
      WHEN old.ColumnAssigned = 'C'
        THEN C
      WHEN old.ColumnAssigned = 'D'
        THEN D
      WHEN old.ColumnAssigned = 'E'
        THEN E
      WHEN old.ColumnAssigned = 'F'
        THEN F
      WHEN old.ColumnAssigned = 'G'
        THEN G
      WHEN old.ColumnAssigned = 'H'
        THEN H
      WHEN old.ColumnAssigned = 'I'
        THEN I
      WHEN old.ColumnAssigned = 'J'
        THEN J
      WHEN old.ColumnAssigned = 'K'
        THEN K
      WHEN old.ColumnAssigned = 'L'
        THEN L
      WHEN old.ColumnAssigned = 'M'
        THEN M
      WHEN old.ColumnAssigned = 'N'
        THEN N
      WHEN old.ColumnAssigned = 'O'
        THEN O
      WHEN old.ColumnAssigned = 'P'
        THEN P
      ELSE NULL
      END
    FROM [.objects]
    WHERE [ClassID] = old.[ClassID];

  UPDATE [.objects]
  SET
    A = CASE WHEN old.ColumnAssigned = 'A'
      THEN NULL
        ELSE A END,
    B = CASE WHEN old.ColumnAssigned = 'B'
      THEN NULL
        ELSE A END,
    C = CASE WHEN old.ColumnAssigned = 'C'
      THEN NULL
        ELSE A END,
    D = CASE WHEN old.ColumnAssigned = 'D'
      THEN NULL
        ELSE A END,
    E = CASE WHEN old.ColumnAssigned = 'E'
      THEN NULL
        ELSE A END,
    F = CASE WHEN old.ColumnAssigned = 'F'
      THEN NULL
        ELSE A END,
    G = CASE WHEN old.ColumnAssigned = 'G'
      THEN NULL
        ELSE A END,
    H = CASE WHEN old.ColumnAssigned = 'H'
      THEN NULL
        ELSE A END,
    I = CASE WHEN old.ColumnAssigned = 'I'
      THEN NULL
        ELSE A END,
    J = CASE WHEN old.ColumnAssigned = 'J'
      THEN NULL
        ELSE A END,
    K = CASE WHEN old.ColumnAssigned = 'K'
      THEN NULL
        ELSE A END,
    L = CASE WHEN old.ColumnAssigned = 'L'
      THEN NULL
        ELSE A END,
    M = CASE WHEN old.ColumnAssigned = 'M'
      THEN NULL
        ELSE A END,
    N = CASE WHEN old.ColumnAssigned = 'N'
      THEN NULL
        ELSE A END,
    O = CASE WHEN old.ColumnAssigned = 'O'
      THEN NULL
        ELSE A END,
    P = CASE WHEN old.ColumnAssigned = 'P'
      THEN NULL
        ELSE A END
  WHERE [ClassID] = old.[ClassID];
END;


--------------------------------------------------------------------------------------------
-- vw_class_properties
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.vw_class_properties] AS
  SELECT
    cp.ClassID,
    c.ClassName,
    PropertyID,
    cp.ctloMask,
    cp.ctlo,
    cp.ctlv,
    cp.ColumnAssigned,

    /* Computed PropertyName */
    coalesce(PropertyName, (SELECT ClassName
                            FROM [.classes]
                            WHERE ClassID = cp.PropertyID
                            LIMIT 1)) AS PropertyName,

    [UNIQUE],
    [DefaultValue],
    [AutoValue],
    (ctlv & 14)                       AS [ReferenceKind],
    (ctlv & 16) <> 0                  AS FullTextData,
    (ctlv & 32) <> 0                  AS RangeData,
    (ctlv & 64) = 0                   AS TrackChanges,
    (ctlv & 1) <> 1                   AS [INDEXED]

  FROM [.class_properties] cp JOIN [.classes] c ON c.ClassID = cp.ClassID;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesEasyInsert]
INSTEAD OF INSERT ON [.vw_class_properties]
FOR EACH ROW
BEGIN
  -- Note that we do not set ColumnAssigned on insert for the sake of performance
  INSERT INTO [.class_properties] ([ClassID], [PropertyID], [PropertyName], [ctlv], [DefaultValue], [AutoValue])
  VALUES (
    new.[ClassID], new.[PropertyID], nullif(new.[PropertyName],
                                            (SELECT [ClassName]
                                             FROM [.classes]
                                             WHERE [ClassID] = new.[PropertyID]
                                             LIMIT 1)),
    new.[INDEXED] |
    (CASE WHEN new.[ReferenceKind] <> 0
      THEN 1 | new.[ReferenceKind]
     ELSE 0 END)
    | (CASE WHEN new.[FullTextData]
      THEN 16
       ELSE 0 END)
    | (CASE WHEN new.[RangeData]
      THEN 32
       ELSE 0 END)
    | (CASE WHEN new.[TrackChanges]
      THEN 0
       ELSE 64 END),
    new.[DefaultValue], new.[AutoValue]
  );

  -- Set ColumnAssigned if it is not yet set and new value is not null
  UPDATE [.class_properties]
  SET [ColumnAssigned] = new.[ColumnAssigned]
  WHERE [ClassID] = new.[ClassID] AND [PropertyID] = new.[PropertyID] AND new.[ColumnAssigned] IS NOT NULL
        AND [ColumnAssigned] IS NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesEasyUpdate]
INSTEAD OF UPDATE ON [.vw_class_properties]
FOR EACH ROW
BEGIN
UPDATE [.class_properties]
SET
  [ClassID]      = new.[ClassID], [PropertyID] = new.[PropertyID], [PropertyName] = nullif(new.[PropertyName],
                                                                                           (SELECT [ClassName]
                                                                                            FROM [.classes]
                                                                                            WHERE
                                                                                              [ClassID] =
                                                                                              new.[PropertyID]
                                                                                            LIMIT 1)),
  [ctlv]         = new.[INDEXED] |
                   (CASE WHEN new.[ReferenceKind] <> 0
                     THEN 1 | new.[ReferenceKind]
                    ELSE 0 END)
                   | (CASE WHEN new.[FullTextData]
    THEN 16
                      ELSE 0 END)
                   | (CASE WHEN new.[RangeData]
    THEN 32
                      ELSE 0 END)
                   | (CASE WHEN new.[TrackChanges]
    THEN 0
                      ELSE 64 END),
  [DefaultValue] = new.[DefaultValue],
  [AutoValue]    = new.[AutoValue]
WHERE [ClassID] = old.[ClassID] AND [PropertyID] = old.[PropertyID];
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesEasyDelete]
INSTEAD OF DELETE ON [.vw_class_properties]
FOR EACH ROW
BEGIN
DELETE FROM [.class_properties]
WHERE [ClassID] = old.[ClassID] AND [PropertyID] = old.[PropertyID];
END;

------------------------------------------------------------------------------------------
-- .full_text_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.full_text_data] USING fts4 (

  [PropertyID],
  [ClassID],
  [ObjectID],
  [PropertyIndex],
  [Value],

  tokenize=unicode61
);

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
    WHERE new.[ColumnAssigned] IS NOT NULL AND new.ctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND
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
    new.oldctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND typeof(new.[oldValue]) = 'text'
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
    WHERE new.[ColumnAssigned] IS NOT NULL AND new.ctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND
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
    old.oldctlo & (1 << (17 + unicode(old.[ColumnAssigned]) - unicode('A'))) AND typeof(old.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', old.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';
END;

------------------------------------------------------------------------------------------
-- [.objects]
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.objects] (
  [ObjectID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassID]  INTEGER NOT NULL CONSTRAINT [fkObjectsClassIDToClasses] REFERENCES [.classes] ([ClassID]) ON DELETE CASCADE ON UPDATE CASCADE,

  /*
  This is bit mask which regulates index storage.
  Bit 0: this object is a WEAK object and must be auto deleted after last reference to this object gets deleted.
  Bits 1-16: columns A-P should be indexed for fast lookup. These bits are checked by partial indexes
  Bits 17-32: columns A-P should be indexed for full text search
  Bits 33-48: columns A-P should be treated as range values and indexed for range (spatial search) search
  Bit 49: DON'T track changes
  Bit 50: Schema is not validated. Normally, this bit is set when object was referenced in other object
  but it was not defined in the schema

  */
  [ctlo]     INTEGER,
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
  [K],
  [L],
  [M],
  [N],
  [O],
  [P]
);

CREATE INDEX IF NOT EXISTS [idxObjectsByClassID] ON [.objects] ([ClassID]);

CREATE INDEX IF NOT EXISTS [idxObjectsByA] ON [.objects] ([ClassID], [A]) WHERE (ctlo AND (1 << 1)) <> 0 AND [A] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByB] ON [.objects] ([ClassID], [B]) WHERE (ctlo AND (1 << 2)) <> 0 AND [B] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByC] ON [.objects] ([ClassID], [C]) WHERE (ctlo AND (1 << 3)) <> 0 AND [C] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByD] ON [.objects] ([ClassID], [D]) WHERE (ctlo AND (1 << 4)) <> 0 AND [D] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByE] ON [.objects] ([ClassID], [E]) WHERE (ctlo AND (1 << 5)) <> 0 AND [E] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByF] ON [.objects] ([ClassID], [F]) WHERE (ctlo AND (1 << 6)) <> 0 AND [F] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByG] ON [.objects] ([ClassID], [G]) WHERE (ctlo AND (1 << 7)) <> 0 AND [G] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByH] ON [.objects] ([ClassID], [H]) WHERE (ctlo AND (1 << 8)) <> 0 AND [H] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByI] ON [.objects] ([ClassID], [I]) WHERE (ctlo AND (1 << 9)) <> 0 AND [I] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByJ] ON [.objects] ([ClassID], [J]) WHERE (ctlo AND (1 << 10)) <> 0 AND [J] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByK] ON [.objects] ([ClassID], [K]) WHERE (ctlo AND (1 << 11)) <> 0 AND [K] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByL] ON [.objects] ([ClassID], [L]) WHERE (ctlo AND (1 << 12)) <> 0 AND [L] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByM] ON [.objects] ([ClassID], [M]) WHERE (ctlo AND (1 << 13)) <> 0 AND [M] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByN] ON [.objects] ([ClassID], [N]) WHERE (ctlo AND (1 << 14)) <> 0 AND [N] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByO] ON [.objects] ([ClassID], [O]) WHERE (ctlo AND (1 << 15)) <> 0 AND [O] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByP] ON [.objects] ([ClassID], [P]) WHERE (ctlo AND (1 << 16)) <> 0 AND [P] IS NOT NULL;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterInsert]
AFTER INSERT
ON [.objects]
FOR EACH ROW
BEGIN
  -- ??? force ctlo. WIll it work?
  UPDATE [.objects]
  SET ctlo = coalesce(new.ctlo, (SELECT [ctlo]
                                 FROM [.classes]
                                 WHERE [ClassID] = new.[ClassID]))
  WHERE ObjectID = new.[ObjectID];

  INSERT INTO [.change_log] ([KEY], [Value])
    SELECT
      printf('@%s.%s', new.[ClassID], new.[ObjectID]),
      json_set('{}',
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
        CASE WHEN new.K IS NULL THEN NULL ELSE '$.K' END, new.K,
        CASE WHEN new.L IS NULL THEN NULL ELSE '$.L' END, new.L,
        CASE WHEN new.M IS NULL THEN NULL ELSE '$.M' END, new.M,
        CASE WHEN new.N IS NULL THEN NULL ELSE '$.N' END, new.N,
        CASE WHEN new.O IS NULL THEN NULL ELSE '$.O' END, new.O,
        CASE WHEN new.P IS NULL THEN NULL ELSE '$.P' END, new.P,
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
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'K', new.[K]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'L', new.[L]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'M', new.[M]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'N', new.[N]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'O', new.[O]
    );
  INSERT INTO [.vw_object_column_data] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'P', new.[P]
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
         '@' || CAST(nullif(old.ClassID, new.ClassID) AS TEXT) || '.' ||
         CAST(nullif(old.ObjectID, new.[ObjectID]) AS TEXT) AS [OldKey],

        json_set('{}',
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
          CASE WHEN nullif(new.K, old.K) IS NULL THEN NULL ELSE '$.K' END, new.K,
            CASE WHEN nullif(new.L, old.L) IS NULL THEN NULL ELSE '$.L' END, new.L,
          CASE WHEN nullif(new.M, old.M) IS NULL THEN NULL ELSE '$.M' END, new.M,
            CASE WHEN nullif(new.N, old.N) IS NULL THEN NULL ELSE '$.N' END, new.N,
          CASE WHEN nullif(new.O, old.O) IS NULL THEN NULL ELSE '$.O' END, new.O,
            CASE WHEN nullif(new.P, old.P) IS NULL THEN NULL ELSE '$.P' END, new.P,
          CASE WHEN nullif(new.ctlo, old.ctlo) IS NULL THEN NULL ELSE '$.ctlo' END, new.ctlo
         )                                                  AS [OldValue],
         printf('@%s.%s', new.[ClassID], new.[ObjectID])    AS [KEY],
         json_set('{}',
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
          CASE WHEN nullif(new.K, old.K) IS NULL THEN NULL ELSE '$.K' END, old.K,
            CASE WHEN nullif(new.L, old.L) IS NULL THEN NULL ELSE '$.L' END, old.L,
          CASE WHEN nullif(new.M, old.M) IS NULL THEN NULL ELSE '$.M' END, old.M,
            CASE WHEN nullif(new.N, old.N) IS NULL THEN NULL ELSE '$.N' END, old.N,
          CASE WHEN nullif(new.O, old.O) IS NULL THEN NULL ELSE '$.O' END, old.O,
            CASE WHEN nullif(new.P, old.P) IS NULL THEN NULL ELSE '$.P' END, old.P,
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
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'K', [oldValue] = old.[K],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'K', [Value] = new.[K],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'L', [oldValue] = old.[L],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'L', [Value] = new.[L],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'M', [oldValue] = old.[M],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'M', [Value] = new.[M],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'N', [oldValue] = old.[N],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'N', [Value] = new.[N],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'O', [oldValue] = old.[O],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'O', [Value] = new.[O],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [.vw_object_column_data]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'P', [oldValue] = old.[P],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'P', [Value] = new.[P],
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
  UPDATE [.VALUES]
  SET ObjectID = new.[ObjectID], ClassID = new.ClassID
  WHERE ObjectID = old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID OR new.ClassID <> old.ClassID);

  -- and shifted values
  UPDATE [.VALUES]
  SET ObjectID = (1 << 62) | new.[ObjectID], ClassID = new.ClassID
  WHERE ObjectID = (1 << 62) | old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID OR new.ClassID <> old.ClassID);

  -- Update back references
  UPDATE [.VALUES]
  SET [Value] = new.[ObjectID]
  WHERE [Value] = old.ObjectID AND ctlv IN (0, 10) AND new.[ObjectID] <> old.ObjectID;
END;

/*
CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdateOfctlo]
AFTER UPDATE OF [ctlo]
ON [.objects]
FOR EACH ROW
BEGIN
-- A-P: delete from [.full_text_data]

-- A-P: insert into [.full_text_data]

-- A-P: delete from [.range_data]

-- A-P: insert into [.range_data]
END;
*/

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterDelete]
AFTER DELETE
ON [.objects]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s', old.[ClassID], old.[ObjectID]),
      json_set('{}',
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
        CASE WHEN old.K IS NULL THEN NULL ELSE '$.K' END, old.K,
          CASE WHEN old.L IS NULL THEN NULL ELSE '$.L' END, old.L,
        CASE WHEN old.M IS NULL THEN NULL ELSE '$.M' END, old.M,
          CASE WHEN old.N IS NULL THEN NULL ELSE '$.N' END, old.N,
        CASE WHEN old.O IS NULL THEN NULL ELSE '$.O' END, old.O,
          CASE WHEN old.P IS NULL THEN NULL ELSE '$.P' END, old.P,
        CASE WHEN old.ctlo IS NULL THEN NULL ELSE '$.ctlo' END, old.ctlo
      )

    WHERE old.[ctlo] IS NULL OR old.[ctlo] & (1 << 49);

  -- Delete all objects that are referenced from this object and marked for cascade delete (ctlv = 10)
  DELETE FROM [.objects]
  WHERE ObjectID IN (SELECT Value
                     FROM [.VALUES]
                     WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID) AND ctlv = 10);

  -- Delete all reversed references
  DELETE FROM [.VALUES]
  WHERE [Value] = ObjectID AND [ctlv] IN (0, 10);

  -- Delete all Values
  DELETE FROM [.VALUES]
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
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'K';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'L';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'M';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'N';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'O';
  DELETE FROM [.vw_object_column_data]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'P';

END;

------------------------------------------------------------------------------------------
-- .range_data
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [.range_data] USING rtree (
  [id],
  [ClassID0], [ClassID1],
  [ObjectID0], [ObjectID1],
  [PropertyID0], [PropertyID1],
  [PropertyIndex0], [PropertyIndex1],
  [StartValue], [EndValue]
);

------------------------------------------------------------------------------------------
-- Values
-- This table stores EAV individual values in a canonical form - one DB row per value
-- Also, this table keeps list of object-to-object references. Direct reference is ObjectID.PropertyID -> Value
-- where Value is ID of referenced object.
-- Reversed reference is from Value -> ObjectID.PropertyID
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [.VALUES] (
  [ObjectID]   INTEGER NOT NULL,
  [PropertyID] INTEGER NOT NULL,
  [PropIndex]  INTEGER NOT NULL DEFAULT 0,
  [Value]              NOT NULL,
  [ClassID]    INTEGER NOT NULL,

  /*
  ctlv is used for index control. Possible values (the same as [.class_properties].ctlv):
      0 - Index
      1-3 - reference
          2(3 as bit 0 is set) - regular ref
          4(5) - ref: A -> B. When A deleted, delete B
          6(7) - when B deleted, delete A
          8(9) - when A or B deleted, delete counterpart
          10(11) - cannot delete A until this reference exists
          12(13) - cannot delete B until this reference exists
          14(15) - cannot delete A nor B until this reference exist

      16 - full text data
      32 - range data
      64 - DON'T track changes
  */
  [ctlv]       INTEGER,
  CONSTRAINT [] PRIMARY KEY ([ObjectID], [ClassID], [PropertyID], [PropIndex])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxClassReversedRefs] ON [.VALUES] ([Value], [PropertyID]) WHERE [ctlv] & 14;

CREATE INDEX IF NOT EXISTS [idxValuesByClassPropValue] ON [.VALUES] ([PropertyID], [ClassID], [Value]) WHERE ([ctlv] & 1);

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterInsert]
AFTER INSERT
ON [.VALUES]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([KEY], [Value])
    SELECT
      printf('@%s.%s/%s[%s]#%s',
             new.[ClassID], new.[ObjectID], new.[PropertyID], new.PropIndex,
             new.ctlv),
      new.[Value]
    WHERE (new.[ctlv] & 64) <> 64;

  INSERT INTO [.full_text_data] ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
    SELECT
      printf('#%s#', new.[PropertyID]),
      printf('#%s#', new.[ClassID]),
      printf('#%s#', new.[ObjectID]),
      printf('#%s#', new.[PropIndex]),
      new.[Value]
    WHERE new.ctlv & 16 AND typeof(new.[Value]) = 'text';

  -- process range data
END;

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterUpdate]
AFTER UPDATE
ON [.VALUES]
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
         printf('%s%s%s%s%s',
                '@' || CAST(nullif(old.[ClassID], new.[ClassID]) AS TEXT),
                '.' || CAST(nullif(old.[ObjectID], new.[ObjectID]) AS TEXT),
                '/' || CAST(nullif(old.[PropertyID], new.[PropertyID]) AS TEXT),
                '[' || CAST(nullif(old.[PropIndex], new.[PropIndex]) AS TEXT) || ']',
                '#' || CAST(nullif(old.[ctlv], new.[ctlv]) AS TEXT)
         )                                                         AS [OldKey],
         old.[Value]                                               AS [OldValue],
         printf('@%s.%s/%s[%s]%s',
                new.[ClassID], new.[ObjectID], new.[PropertyID], new.PropIndex,
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

END;

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterDelete]
AFTER DELETE
ON [.VALUES]
FOR EACH ROW
BEGIN
  INSERT INTO [.change_log] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s/%s[%s]',
             old.[ClassID], old.[ObjectID], old.[PropertyID],
             old.PropIndex),
      old.[Value]
    WHERE (old.[ctlv] & 64) <> 64;

  -- Delete weak referenced object in case this Value record was last reference to that object
  DELETE FROM [.objects]
  WHERE old.ctlv IN (3) AND ObjectID = old.Value AND
        (ctlo & 1) = 1 AND (SELECT count(*)
                            FROM [.VALUES]
                            WHERE [Value] = ObjectID AND ctlv IN (3)) = 0;

  -- Process full text data based on ctlv
  DELETE FROM [.full_text_data]
  WHERE
    old.[ctlv] & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ClassID] MATCH printf('#%s#', old.[ClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);

  -- Process range data based on ctlv
END;

--------------------------------------------------------------------------------------------
-- .ValuesEasy
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [.ValuesEasy] AS
  SELECT
    NULL AS [ClassName],
    NULL AS [HostID],
    NULL AS [ObjectID],
    NULL AS [PropertyName],
    NULL AS [PropertyIndex],
    NULL AS [Value];

CREATE TRIGGER IF NOT EXISTS trigValuesEasy_Insert INSTEAD OF INSERT
ON [.ValuesEasy]
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO [.objects] (ClassID, ObjectID, ctlo, A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P)
    SELECT
      c.ClassID,
      (new.HostID << 31) | new.[ObjectID],

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
           ELSE J END),

      K = (CASE WHEN p.[ColumnAssigned] = 'K'
        THEN new.[Value]
           ELSE K END),

      L = (CASE WHEN p.[ColumnAssigned] = 'L'
        THEN new.[Value]
           ELSE L END),

      M = (CASE WHEN p.[ColumnAssigned] = 'M'
        THEN new.[Value]
           ELSE M END),

      N = (CASE WHEN p.[ColumnAssigned] = 'N'
        THEN new.[Value]
           ELSE N END),

      O = (CASE WHEN p.[ColumnAssigned] = 'O'
        THEN new.[Value]
           ELSE O END),

      P = (CASE WHEN p.[ColumnAssigned] = 'P'
        THEN new.[Value]
           ELSE P END)
    FROM [.classes] c, [.vw_class_properties] p
    WHERE c.[ClassID] = p.[ClassID] AND c.ClassName = new.ClassName AND p.PropertyName = new.PropertyName
          AND (p.[ctlv] & 14) = 0 AND p.ColumnAssigned IS NOT NULL AND new.PropertyIndex = 0;

  INSERT OR REPLACE INTO [.VALUES] (ObjectID, ClassID, PropertyID, PropIndex, [Value], ctlv)
    SELECT
      CASE WHEN new.PropertyIndex > 20
        THEN new.[ObjectID] | (1 << 62)
      ELSE new.[ObjectID] END,
      c.ClassID,
      p.PropertyID,
      new.PropertyIndex,
      new.[Value],
      p.[ctlv]
    FROM [.classes] c, [.vw_class_properties] p
    WHERE c.[ClassID] = p.[ClassID] AND c.ClassName = new.ClassName AND p.PropertyName = new.PropertyName AND
          p.ColumnAssigned IS NULL;
END;

--------------------------------------------------------------------------------------------
-- .values_view - wraps access to .values table by providing separate HostID and ObjectID columns
--------------------------------------------------------------------------------------------
create view if not exists [.values_view] as
select ClassID, [ObjectID] >> 31 as HostID,
                    ([ObjectID] & 2147483647) as ObjectID, ctlv, PropertyID, PropIndex, [Value]
from [.values];

create trigger if not exists values_view_Insert instead of insert on [.values_view]
for each row
begin
    insert into [.values]
    (
    ClassID, [ObjectID], ctlv, PropertyID, PropIndex, [Value]
    )
    values (
    new.ClassID, new.[ObjectID] << 31 | (new.[ObjectID] & 2147483647), new.ctlv,
    new.PropertyID, new.PropIndex, new.[Value]
    );
end;

create trigger if not exists values_view_Update instead of update on [.values_view]
for each row
begin
    update [.values] set
    ClassID = new.ClassID,
     [ObjectID] = new.[ObjectID] << 31 | (new.[ObjectID] & 2147483647),
     ctlv = new.ctlv,
    PropertyID = new.PropertyID, PropIndex = new.PropIndex, [Value] = new.[Value]
    where [ObjectID] = old.[ObjectID] << 31 | (old.[ObjectID] & 2147483647)
    and [PropertyID] = old.[PropertyID] and [PropIndex] = old.[PropIndex];
end;

create trigger if not exists values_view_Delete instead of delete on [.values_view]
for each row
begin
    delete from [.values]
   where [ObjectID] = old.[ObjectID] << 31 | (old.[ObjectID] & 2147483647)
       and [PropertyID] = old.[PropertyID] and [PropIndex] = old.[PropIndex];
end;

