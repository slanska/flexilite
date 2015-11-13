PRAGMA page_size = 8192;
PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = 1;
PRAGMA encoding = 'UTF-8';
PRAGMA recursive_triggers = 1;

------------------------------------------------------------------------------------------
-- AccessRules
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [AccessRules] (
  [UserRoleID] GUID NOT NULL,
  [ItemType]   CHAR NOT NULL,
  [Access]     CHAR NOT NULL,
  [ItemID]     INT  NOT NULL,
  CONSTRAINT [sqlite_autoindex_AccessRules_1] PRIMARY KEY ([UserRoleID], [ItemType], [ItemID])
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS [idxAccessRulesByItemID] ON [AccessRules] ([ItemID]);

------------------------------------------------------------------------------------------
-- ChangeLog
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [ChangeLog] (
  [ID]        INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [TimeStamp] DATETIME NOT NULL DEFAULT (julianday('now')),
  [OldKey],
  [OldValue],
  [Key],
  [Value],

-- TODO Implement function
  [ChangedBy] GUID              -- DEFAULT (GetCurrentUserID())
);

CREATE INDEX IF NOT EXISTS [idxChangeLogByNew] ON [ChangeLog] ([Key]) WHERE [Key] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxChangeLogByOld] ON [ChangeLog] ([OldKey]) WHERE [OldKey] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxChangeLogByChangedBy] ON [ChangeLog] ([ChangedBy], [TimeStamp]) WHERE ChangedBy IS NOT NULL;

------------------------------------------------------------------------------------------
-- Classes
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [Classes] (
  [ClassID]           INTEGER  NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassName]         TEXT(64) NOT NULL,
-- [ClassTitle] TEXT NOT NULL,
  [SchemaID]          GUID     NOT NULL DEFAULT (randomblob(16)),
  [SystemClass]       BOOL     NOT NULL DEFAULT 0,
  [DefaultScalarType] TEXT     NOT NULL DEFAULT 'String',
  [TitlePropertyID]   INTEGER CONSTRAINT [fkClassesTitleToClasses] REFERENCES [Classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE RESTRICT,
  [SubTitleProperty]  INTEGER CONSTRAINT [fkClassesSubTitleToClasses] REFERENCES [Classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE RESTRICT,
  [SchemaXML]         TEXT,
  [SchemaOutdated]    BOOLEAN  NOT NULL DEFAULT 0,
  [MinOccurences]     INTEGER  NOT NULL DEFAULT 0,
  [MaxOccurences]     INTEGER  NOT NULL DEFAULT ((1 << 32) - 1),
  [DBViewName]        TEXT,
  [ctloMask]          INTEGER  NOT NULL DEFAULT (0), -- Aggregated value for all indexing for assigned columns (A-P). Updated by trigger on ClassProperty update

  CONSTRAINT [chkClasses_DefaultScalarType] CHECK (DefaultScalarType IN
                                                   ('String', 'Integer', 'Number', 'Boolean', 'Date', 'DateTime', 'Time', 'Guid',
                                                    'BLOB', 'Timespan', 'RangeOfIntegers', 'RangeOfNumbers', 'RangeOfDateTimes'))
);

CREATE UNIQUE INDEX IF NOT EXISTS [idxClasses_byClassName] ON [Classes] ([ClassName]);

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterInsert]
AFTER INSERT
ON [Classes]
FOR EACH ROW
BEGIN
  INSERT INTO ChangeLog ([Key], [Value]) VALUES (
    printf('@%s', new.ClassID),
    '{ ' ||
    '"ClassName": ' || quote(new.ClassName) ||
    ', "SystemClass": ' || quote(new.SystemClass) ||
    ', "DefaultScalarType": ' || quote(new.DefaultScalarType) ||
    ', "TitlePropertyID": ' || quote(new.TitlePropertyID) ||
    ', "SubTitleProperty": ' || quote(new.SubTitleProperty) ||
    ', "SchemaXML": ' || quote(new.SchemaXML) ||
    ', "SchemaOutdated": ' || quote(new.SchemaOutdated) ||
    ', "MinOccurences": ' || quote(new.MinOccurences) ||
    ', "MaxOccurences": ' || quote(new.MaxOccurences) ||
    ', "DBViewName": ' || quote(new.DBViewName) ||
    ', "ctloMask": ' || quote(new.ctloMask) ||
    ' }'
  );
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdate]
AFTER UPDATE
ON [Classes]
FOR EACH ROW
BEGIN
  INSERT INTO ChangeLog ([OldKey], [OldValue], [Key], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [Key],
      [Value]
    FROM (
      SELECT
        '@' || cast(nullif(old.ClassID, new.ClassID) AS TEXT)                             AS [OldKey],
        printf('{%s%s%s%s%s%s%s%s%s%s%s}',
               ' "ClassName": ' || nullif(quote(old.ClassName), quote(new.ClassName)) || ', ',
               '"SystemClass": ' || nullif(quote(old.SystemClass), quote(new.SystemClass)) || ', ',
               '"DefaultScalarType": ' || nullif(quote(old.DefaultScalarType), quote(new.DefaultScalarType)) || ', ',
               '"TitlePropertyID": ' || nullif(quote(old.TitlePropertyID), quote(new.TitlePropertyID)) || ', ',
               '"SubTitleProperty": ' || nullif(quote(old.SubTitleProperty), quote(new.SubTitleProperty)) || ', ',
               '"SchemaXML": ' || nullif(quote(old.SchemaXML), quote(new.SchemaXML)) || ', ',
               '"SchemaOutdated": ' || nullif(quote(old.SchemaOutdated), quote(new.SchemaOutdated)) || ', ',
               '"MinOccurences": ' || nullif(quote(old.MinOccurences), quote(new.MinOccurences)) || ', ',
               '"MaxOccurences": ' || nullif(quote(old.MaxOccurences), quote(new.MaxOccurences)) || ', ',
               '"DBViewName": ' || nullif(quote(old.DBViewName), quote(new.DBViewName)) || ', ',
               '"ctloMask": ' || nullif(quote(old.ctloMask), quote(new.ctloMask)) || ' '
        )                                                                                 AS [OldValue],
        '@' || cast(new.ClassID AS TEXT)                                                  AS [Key],
        printf('{%s%s%s%s%s%s%s%s%s%s%s}',
               ' "ClassName": ' || nullif(quote(new.ClassName), quote(new.ClassName)) || ', ',
               '"SystemClass": ' || nullif(quote(new.SystemClass), quote(old.SystemClass)) || ', ',
               '"DefaultScalarType": ' || nullif(quote(new.DefaultScalarType), quote(old.DefaultScalarType)) || ', ',
               '"TitlePropertyID": ' || nullif(quote(new.TitlePropertyID), quote(old.TitlePropertyID)) || ', ',
               '"SubTitleProperty": ' || nullif(quote(new.SubTitleProperty), quote(old.SubTitleProperty)) || ', ',
               '"SchemaXML": ' || nullif(quote(new.SchemaXML), quote(old.SchemaXML)) || ', ',
               '"SchemaOutdated": ' || nullif(quote(new.SchemaOutdated), quote(old.SchemaOutdated)) || ', ',
               '"MinOccurences": ' || nullif(quote(new.MinOccurences), quote(old.MinOccurences)) || ', ',
               '"MaxOccurences": ' || nullif(quote(new.MaxOccurences), quote(old.MaxOccurences)) || ', ',
               '"DBViewName": ' || nullif(quote(new.DBViewName), quote(old.DBViewName)) || ', ',
               '"ctloMask": ' || nullif(quote(new.ctloMask), quote(old.ctloMask)) || ' ') AS [Value]
    )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [Key])) IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterUpdateOfctloMask]
AFTER UPDATE OF [ctloMask]
ON [Classes]
FOR EACH ROW
BEGIN
  UPDATE [Objects]
  SET [ctlo] = new.[ctloMask]
  WHERE ClassID = new.ClassID;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassesAfterDelete]
AFTER DELETE
ON [Classes]
FOR EACH ROW
BEGIN
  INSERT INTO ChangeLog ([OldKey], [OldValue]) VALUES (
    printf('@%s', old.ClassID),
    '{ ' ||
    '"ClassName": ' || quote(old.ClassName) ||
    ', "SystemClass": ' || quote(old.SystemClass) ||
    ', "DefaultScalarType": ' || quote(old.DefaultScalarType) ||
    ', "TitlePropertyID": ' || quote(old.TitlePropertyID) ||
    ', "SubTitleProperty": ' || quote(old.SubTitleProperty) ||
    ', "SchemaXML": ' || quote(old.SchemaXML) ||
    ', "SchemaOutdated": ' || quote(old.SchemaOutdated) ||
    ', "MinOccurences": ' || quote(old.MinOccurences) ||
    ', "MaxOccurences": ' || quote(old.MaxOccurences) ||
    ', "DBViewName": ' || quote(old.DBViewName) ||
    ', "ctloMask": ' || quote(old.ctloMask) ||
    ' }'
  );
END;

------------------------------------------------------------------------------------------
-- ClassProperties
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [ClassProperties] (
  [ClassID]            INTEGER NOT NULL CONSTRAINT [fkClassPropertiesClassID] REFERENCES [Classes] ([ClassID]) ON DELETE CASCADE ON UPDATE CASCADE,
  [PropertyID]         INTEGER NOT NULL CONSTRAINT [fkClassPropertiesPropertyID] REFERENCES [Classes] ([ClassID]) ON DELETE RESTRICT ON UPDATE CASCADE,
  [PropertyName]       TEXT(64),
  [TrackChanges]       BOOLEAN NOT NULL DEFAULT 1,
  [DefaultValue],
  [ctlo]               INTEGER NOT NULL DEFAULT 0,
  [ctloMask]           INTEGER NOT NULL DEFAULT 0,
  [DefaultDataType]    INTEGER,
  [MinOccurences]      INTEGER NOT NULL DEFAULT 0,
  [MaxOccurences]      INTEGER NOT NULL DEFAULT 1,
  [Unique]             BOOLEAN NOT NULL DEFAULT 0,
  [ColumnAssigned]     CHAR,
  [AutoValue]          TEXT,
  [MaxLength]          INTEGER NOT NULL DEFAULT (-1),
  [TempColumnAssigned] CHAR,

  /*
  These 2 properties define 'reference' property.
  ReversePropertyID is optional and used for reversed access from referenced class.
  If not null, ClassProperties table must contain record with combination ClassID=ReferencedClassID
  and PropertyID=ReversePropertyID
  */
  [ReferencedClassID] INTEGER NULL,
  [ReversePropertyID] INTEGER NULL,

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

CREATE UNIQUE INDEX IF NOT EXISTS [idxClassPropertiesColumnAssigned] ON [ClassProperties] ([ClassID], [ColumnAssigned]) WHERE ColumnAssigned IS NOT NULL;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesAfterDelete]
AFTER DELETE
ON [ClassProperties]
FOR EACH ROW
BEGIN
  UPDATE Classes
  SET SchemaOutdated = 1
  WHERE ClassID = old.ClassID;

  INSERT INTO ChangeLog ([OldKey], [OldValue]) VALUES (
    printf('@%s/%s', old.ClassID, old.PropertyID),
    '{ ' ||
    '"PropertyName": ' || quote(old.[PropertyName]) ||
    '"TrackChanges": ' || quote(old.[TrackChanges]) ||
    '"DefaultValue": ' || quote(old.[DefaultValue]) ||
    '"DefaultDataType": ' || quote(old.[DefaultDataType]) ||
    '"MinOccurences": ' || quote(old.[MinOccurences]) ||
    '"MaxOccurences": ' || quote(old.[MaxOccurences]) ||
    '"Unique": ' || quote(old.[Unique]) ||
    '"ColumnAssigned": ' || quote(old.[ColumnAssigned]) ||
    '"AutoValue": ' || quote(old.[AutoValue]) ||
    '"MaxLength": ' || quote(old.[MaxLength]) ||
    '"TempColumnAssigned": ' || quote(old.[TempColumnAssigned]) ||
    '"ctlo": ' || quote(old.[ctlo]) ||
    '"ctloMask": ' || quote(old.[ctloMask]) ||
    '"ctlv": ' || quote(old.[ctlv]) ||
    '"ReferencedClassID": ' || quote(old.ReferencedClassID) ||
    '"ReversePropertyID": ' || quote(old.ReversePropertyID) ||
    ' }'
  );

-- ColumnAssigned is set to null from letter.
-- Need to copy data to Values table and reset column in Objects
  INSERT OR REPLACE INTO [Values] ([ClassID], [ObjectID], [PropertyID], [PropIndex], [ctlv], [Value])
    SELECT
      old.[ClassID],
      [ObjectID],
      (SELECT [PropertyID]
       FROM [ClassProperties]
       WHERE ClassID = old.[ClassID] AND [ColumnAssigned] = old.[ColumnAssigned] AND [ColumnAssigned] IS NOT NULL),
      0,
      old.ctlv,
      CASE
      WHEN old.ColumnAssigned = 'A' THEN A
      WHEN old.ColumnAssigned = 'B' THEN B
      WHEN old.ColumnAssigned = 'C' THEN C
      WHEN old.ColumnAssigned = 'D' THEN D
      WHEN old.ColumnAssigned = 'E' THEN E
      WHEN old.ColumnAssigned = 'F' THEN F
      WHEN old.ColumnAssigned = 'G' THEN G
      WHEN old.ColumnAssigned = 'H' THEN H
      WHEN old.ColumnAssigned = 'I' THEN I
      WHEN old.ColumnAssigned = 'J' THEN J
      WHEN old.ColumnAssigned = 'K' THEN K
      WHEN old.ColumnAssigned = 'L' THEN L
      WHEN old.ColumnAssigned = 'M' THEN M
      WHEN old.ColumnAssigned = 'N' THEN N
      WHEN old.ColumnAssigned = 'O' THEN O
      WHEN old.ColumnAssigned = 'P' THEN P
      ELSE NULL
      END
    FROM [Objects]
    WHERE [ClassID] = old.[ClassID];

  UPDATE [Objects]
  SET
    A = CASE WHEN old.ColumnAssigned = 'A' THEN NULL
        ELSE A END,
    B = CASE WHEN old.ColumnAssigned = 'B' THEN NULL
        ELSE A END,
    C = CASE WHEN old.ColumnAssigned = 'C' THEN NULL
        ELSE A END,
    D = CASE WHEN old.ColumnAssigned = 'D' THEN NULL
        ELSE A END,
    E = CASE WHEN old.ColumnAssigned = 'E' THEN NULL
        ELSE A END,
    F = CASE WHEN old.ColumnAssigned = 'F' THEN NULL
        ELSE A END,
    G = CASE WHEN old.ColumnAssigned = 'G' THEN NULL
        ELSE A END,
    H = CASE WHEN old.ColumnAssigned = 'H' THEN NULL
        ELSE A END,
    I = CASE WHEN old.ColumnAssigned = 'I' THEN NULL
        ELSE A END,
    J = CASE WHEN old.ColumnAssigned = 'J' THEN NULL
        ELSE A END,
    K = CASE WHEN old.ColumnAssigned = 'K' THEN NULL
        ELSE A END,
    L = CASE WHEN old.ColumnAssigned = 'L' THEN NULL
        ELSE A END,
    M = CASE WHEN old.ColumnAssigned = 'M' THEN NULL
        ELSE A END,
    N = CASE WHEN old.ColumnAssigned = 'N' THEN NULL
        ELSE A END,
    O = CASE WHEN old.ColumnAssigned = 'O' THEN NULL
        ELSE A END,
    P = CASE WHEN old.ColumnAssigned = 'P' THEN NULL
        ELSE A END
  WHERE [ClassID] = old.[ClassID];
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesAfterInsert]
AFTER INSERT
ON [ClassProperties]
FOR EACH ROW
BEGIN
  UPDATE Classes
  SET SchemaOutdated = 1
  WHERE ClassID = new.ClassID;

  INSERT INTO ChangeLog ([Key], [Value]) VALUES (
    printf('@%s/%s', new.ClassID, new.PropertyID),
    '{ ' ||
    '"PropertyName": ' || quote(new.[PropertyName]) || ', ' ||
    '"TrackChanges": ' || quote(new.[TrackChanges]) || ', ' ||
    '"DefaultValue": ' || quote(new.[DefaultValue]) || ', ' ||
    '"DefaultDataType": ' || quote(new.[DefaultDataType]) || ', ' ||
    '"MinOccurences": ' || quote(new.[MinOccurences]) || ', ' ||
    '"MaxOccurences": ' || quote(new.[MaxOccurences]) || ', ' ||
    '"Unique": ' || quote(new.[Unique]) || ', ' ||
    '"ColumnAssigned": ' || quote(new.[ColumnAssigned]) || ', ' ||
    '"AutoValue": ' || quote(new.[AutoValue]) || ', ' ||
    '"MaxLength": ' || quote(new.[MaxLength]) || ', ' ||
    '"TempColumnAssigned": ' || quote(new.[TempColumnAssigned]) || ', ' ||
    '"ctlo": ' || quote(new.[ctlo]) || ', ' ||
    '"ctloMask": ' || quote(new.[ctloMask]) || ', ' ||
    '"ctlv": ' || quote(new.[ctlv]) ||
    '"ReferencedClassID": ' ||  quote(new.ReferencedClassID) ||
    '"ReversePropertyID": ' || quote(new.ReversePropertyID) ||
    ' }'
  );

-- Determine last unused column (A to P), if any
-- This update might fire trigClassPropertiesColumnAssignedBecameNotNull
  UPDATE ClassProperties
  SET TempColumnAssigned = coalesce([ColumnAssigned],
                                    nullif(char((SELECT coalesce(unicode(max(ColumnAssigned)), unicode('A') - 1)
                                                 FROM ClassProperties
                                                 WHERE ClassID = new.ClassID AND PropertyID <> new.PropertyID AND
                                                       ColumnAssigned IS NOT NULL
                                                 ORDER BY ClassID, ColumnAssigned
                                                   DESC
                                                 LIMIT 1) + 1), 'Q')),
    [ColumnAssigned]     = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID AND new.[ColumnAssigned] IS NULL
        AND new.[MaxLength] BETWEEN 0 AND 255;

-- Restore ColumnAssigned to refactor existing data (from Values to Objects)
  UPDATE ClassProperties
  SET ColumnAssigned = TempColumnAssigned, TempColumnAssigned = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID AND new.[MaxLength] BETWEEN 0 AND 255;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesColumnAssignedBecameNull]
AFTER UPDATE OF [ColumnAssigned]
ON [ClassProperties]
FOR EACH ROW
  WHEN old.[ColumnAssigned] IS NOT NULL AND new.[ColumnAssigned] IS NULL
BEGIN
  UPDATE Classes
  SET SchemaOutdated = 1
  WHERE ClassID = new.ClassID;

-- ColumnAssigned is set to null from letter.
-- Need to copy data to Values table and reset column in Objects
  INSERT OR REPLACE INTO [Values] ([ClassID], [ObjectID], [PropertyID], [PropIndex], [ctlv], [Value])
    SELECT
      new.[ClassID],
      [ObjectID],
      (SELECT [PropertyID]
       FROM [ClassProperties]
       WHERE ClassID = new.[ClassID] AND [ColumnAssigned] = old.[ColumnAssigned] AND [ColumnAssigned] IS NOT NULL),
      0,
      new.ctlv,
      CASE
      WHEN old.ColumnAssigned = 'A' THEN A
      WHEN old.ColumnAssigned = 'B' THEN B
      WHEN old.ColumnAssigned = 'C' THEN C
      WHEN old.ColumnAssigned = 'D' THEN D
      WHEN old.ColumnAssigned = 'E' THEN E
      WHEN old.ColumnAssigned = 'F' THEN F
      WHEN old.ColumnAssigned = 'G' THEN G
      WHEN old.ColumnAssigned = 'H' THEN H
      WHEN old.ColumnAssigned = 'I' THEN I
      WHEN old.ColumnAssigned = 'J' THEN J
      WHEN old.ColumnAssigned = 'K' THEN K
      WHEN old.ColumnAssigned = 'L' THEN L
      WHEN old.ColumnAssigned = 'M' THEN M
      WHEN old.ColumnAssigned = 'N' THEN N
      WHEN old.ColumnAssigned = 'O' THEN O
      WHEN old.ColumnAssigned = 'P' THEN P
      ELSE NULL
      END
    FROM [Objects]
    WHERE [ClassID] = new.[ClassID];

  UPDATE [Objects]
  SET
    A = CASE WHEN old.ColumnAssigned = 'A' THEN NULL
        ELSE A END,
    B = CASE WHEN old.ColumnAssigned = 'B' THEN NULL
        ELSE A END,
    C = CASE WHEN old.ColumnAssigned = 'C' THEN NULL
        ELSE A END,
    D = CASE WHEN old.ColumnAssigned = 'D' THEN NULL
        ELSE A END,
    E = CASE WHEN old.ColumnAssigned = 'E' THEN NULL
        ELSE A END,
    F = CASE WHEN old.ColumnAssigned = 'F' THEN NULL
        ELSE A END,
    G = CASE WHEN old.ColumnAssigned = 'G' THEN NULL
        ELSE A END,
    H = CASE WHEN old.ColumnAssigned = 'H' THEN NULL
        ELSE A END,
    I = CASE WHEN old.ColumnAssigned = 'I' THEN NULL
        ELSE A END,
    J = CASE WHEN old.ColumnAssigned = 'J' THEN NULL
        ELSE A END,
    K = CASE WHEN old.ColumnAssigned = 'K' THEN NULL
        ELSE A END,
    L = CASE WHEN old.ColumnAssigned = 'L' THEN NULL
        ELSE A END,
    M = CASE WHEN old.ColumnAssigned = 'M' THEN NULL
        ELSE A END,
    N = CASE WHEN old.ColumnAssigned = 'N' THEN NULL
        ELSE A END,
    O = CASE WHEN old.ColumnAssigned = 'O' THEN NULL
        ELSE A END,
    P = CASE WHEN old.ColumnAssigned = 'P' THEN NULL
        ELSE A END
  WHERE [ClassID] = new.[ClassID];
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesColumnAssignedChange]
AFTER UPDATE OF [ColumnAssigned]
ON [ClassProperties]
FOR EACH ROW
  WHEN old.[ColumnAssigned] IS NOT NULL AND new.[ColumnAssigned] IS NOT NULL
BEGIN
-- Force ColumnAssigned to be NULL to refactor existing data (from Objects to Values)
  UPDATE ClassProperties
  SET TempColumnAssigned = new.[ColumnAssigned], ColumnAssigned = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID;

-- Restore ColumnAssigned to refactor existing data (from Values to Objects)
  UPDATE ClassProperties
  SET ColumnAssigned = TempColumnAssigned, TempColumnAssigned = NULL
  WHERE ClassID = new.ClassID AND PropertyID = new.PropertyID;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassProperties_UpdateOfctlo]
AFTER UPDATE OF [ctlo], [ctloMask]
ON [ClassProperties]
FOR EACH ROW
BEGIN
  UPDATE Classes
  SET ctloMask = (ctloMask & ~new.ctloMask) | new.ctlo
  WHERE ClassID = new.ClassID;
END;

/* General trigger after update of ClassProperties. Track Changes */
CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesAfterUpdate]
AFTER UPDATE ON [ClassProperties]
FOR EACH ROW
BEGIN
  INSERT INTO ChangeLog ([OldKey], [OldValue], [Key], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [Key],
      [Value]
    FROM
      (SELECT
         '@' || cast(nullif(old.ClassID, new.ClassID) AS TEXT) || '/' ||
         cast(nullif(old.PropertyID, new.PropertyID) AS TEXT)           AS [OldKey],
         printf('{%s%s%s%s%s%s%s%s%s%s%s%s%s%s}',
                '"PropertyName": ' || nullif(quote(old.PropertyName), quote(new.PropertyName)) || ', ',
                '"TrackChanges": ' || nullif(quote(old.TrackChanges), quote(new.TrackChanges)) || ', ',
                '"DefaultValue": ' || nullif(quote(old.DefaultValue), quote(new.DefaultValue)) || ', ',
                '"DefaultDataType": ' || nullif(quote(old.DefaultDataType), quote(new.DefaultDataType)) || ', ',
                '"MinOccurences": ' || nullif(quote(old.MinOccurences), quote(new.MinOccurences)) || ', ',
                '"MaxOccurences": ' || nullif(quote(old.MaxOccurences), quote(new.MaxOccurences)) || ', ',
                '"Unique": ' || nullif(quote(old.[Unique]), quote(new.[Unique])) || ', ',
                '"ColumnAssigned": ' || nullif(quote(old.ColumnAssigned), quote(new.[ColumnAssigned])) || ', ',
                '"AutoValue": ' || nullif(quote(old.AutoValue), quote(new.AutoValue)) || ', ',
                '"MaxLength": ' || nullif(quote(old.MaxLength), quote(new.MaxLength)) || ', ',
                '"TempColumnAssigned": ' || nullif(quote(old.TempColumnAssigned), quote(new.TempColumnAssigned)) ||
                ', ',
                '"ctlo": ' || nullif(quote(old.ctlo), quote(new.ctlo)) || ', ',
                '"ctloMask": ' || nullif(quote(old.ctloMask), quote(new.ctloMask)) || ', ',
                '"ReferencedClassID": ' || nullif(quote(old.ReferencedClassID), quote(new.ReferencedClassID)) || ', ',
                '"ReversePropertyID": ' || nullif(quote(old.ReversePropertyID), quote(new.ReversePropertyID)) || ', ',
                '"ctlv": ' || nullif(quote(old.ctlv), quote(new.ctlv))) AS [OldValue],

         printf('@%s/%s', new.ClassID, new.PropertyID)                  AS [Key],

         printf('{%s%s%s%s%s%s%s%s%s%s%s%s%s%s}',
                '"PropertyName": ' || nullif(quote(new.PropertyName), quote(old.PropertyName)) || ', ',
                '"TrackChanges": ' || nullif(quote(new.TrackChanges), quote(old.TrackChanges)) || ', ',
                '"DefaultValue": ' || nullif(quote(new.DefaultValue), quote(old.DefaultValue)) || ', ',
                '"DefaultDataType": ' || nullif(quote(new.DefaultDataType), quote(old.DefaultDataType)) || ', ',
                '"MinOccurences": ' || nullif(quote(new.MinOccurences), quote(old.MinOccurences)) || ', ',
                '"MaxOccurences": ' || nullif(quote(new.MaxOccurences), quote(old.MaxOccurences)) || ', ',
                '"Unique": ' || nullif(quote(new.[Unique]), quote(old.[Unique])) || ', ',
                '"ColumnAssigned": ' || nullif(quote(new.[ColumnAssigned]), quote(old.ColumnAssigned)) || ', ',
                '"AutoValue": ' || nullif(quote(new.AutoValue), quote(old.AutoValue)) || ', ',
                '"MaxLength": ' || nullif(quote(new.MaxLength), quote(old.MaxLength)) || ', ',
                '"TempColumnAssigned": ' || nullif(quote(new.TempColumnAssigned), quote(old.TempColumnAssigned)) ||
                ', ',
                '"ReferencedClassID": ' || nullif(quote(new.ReferencedClassID), quote(old.ReferencedClassID)) || ', ',
                '"ReversePropertyID": ' || nullif(quote(new.ReversePropertyID), quote(old.ReversePropertyID)) || ', ',

                '"ctlo": ' || nullif(quote(new.ctlo), quote(old.ctlo)) || ', ',
                '"ctloMask": ' || nullif(quote(new.ctloMask), quote(old.ctloMask)) || ', ',
                '"ctlv": ' || nullif(quote(new.ctlv), quote(old.ctlv))) AS [Value]
      )
    WHERE [OldValue] <> [Value] OR (nullif([OldKey], [Key])) IS NOT NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesColumnAssignedBecameNotNull]
AFTER UPDATE OF [ColumnAssigned]
ON [ClassProperties]
FOR EACH ROW
  WHEN new.[ColumnAssigned] IS NOT NULL AND old.[ColumnAssigned] IS NULL
BEGIN
  UPDATE Classes
  SET SchemaOutdated = 1
  WHERE ClassID = new.ClassID;

-- Copy attributes from Values table to Objects table, based on ColumnAssigned
-- Only primitive values (not references: ctlv = 0) and (XML) attributes (PropIndex = 0) are processed
-- Copy attributes from Values table to Objects table, based on ColumnAssigned
-- Only primitive values (not references: ctlv = 0) and attributes (PropIndex = 0) are processed
  UPDATE Objects
  SET
    A = CASE WHEN new.[ColumnAssigned] = 'A' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE A END,

    B = CASE WHEN new.[ColumnAssigned] = 'B' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE B END,

    C = CASE WHEN new.[ColumnAssigned] = 'C' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE C END,

    D = CASE WHEN new.[ColumnAssigned] = 'D' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE D END,

    E = CASE WHEN new.[ColumnAssigned] = 'E' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE E END,

    F = CASE WHEN new.[ColumnAssigned] = 'F' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE F END,

    G = CASE WHEN new.[ColumnAssigned] = 'G' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE G END,

    H = CASE WHEN new.[ColumnAssigned] = 'H' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE H END,

    I = CASE WHEN new.[ColumnAssigned] = 'I' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE I END,

    J = CASE WHEN new.[ColumnAssigned] = 'J' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE J END,

    K = CASE WHEN new.[ColumnAssigned] = 'K' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE K END,

    L = CASE WHEN new.[ColumnAssigned] = 'L' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE L END,

    M = CASE WHEN new.[ColumnAssigned] = 'M' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE M END,

    N = CASE WHEN new.[ColumnAssigned] = 'N' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE N END,

    O = CASE WHEN new.[ColumnAssigned] = 'O' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE O END,

    P = CASE WHEN new.[ColumnAssigned] = 'P' THEN (SELECT [Value]
                                                   FROM [Values] v
                                                   WHERE
                                                     v.ObjectID = Objects.ObjectID AND
                                                     v.PropertyID = new.PropertyID
                                                     AND v.PropIndex = 0 AND (v.ctlv & 14) = 0
                                                   LIMIT 1)
        ELSE P END
  WHERE ClassID = new.ClassID;

-- Indirectly update aggregated control settings on class level (through ctloMask)
  UPDATE [ClassProperties]
  SET
    ctlo     = (SELECT (1 << idx) | (1 << (idx + 16)) << (1 << (idx + 32))
                FROM (SELECT (unicode(new.[ColumnAssigned]) - unicode('A') + 1) AS idx)),
    ctloMask = (SELECT (ctlv & 1) << idx | /* Indexed*/
                       ((ctlv & 16) <> 0) << (idx + 16) | /* Full text search */
                       ((ctlv & 32) <> 0) << (idx + 32) /* Range data */
                FROM (SELECT (unicode(new.[ColumnAssigned]) - unicode('A') + 1) AS idx))
  WHERE [ClassID] = new.[ClassID] AND [PropertyID] = new.[PropertyID];

-- Delete copied attributes from Values table
  DELETE FROM [Values]
  WHERE ObjectID = (SELECT ObjectID
                    FROM [Objects]
                    WHERE ClassID = new.ClassID)
        AND PropertyID = new.PropertyID AND PropIndex = 0 AND (ctlv & 14) = 0;
END;

--------------------------------------------------------------------------------------------
-- ClassPropertiesEasy
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS ClassPropertiesEasy AS
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
                            FROM Classes
                            WHERE ClassID = cp.PropertyID
                            LIMIT 1)) AS PropertyName,

    [Unique],
    [DefaultValue],
    [AutoValue],
    (ctlv & 14)                       AS [ReferenceKind],
    (ctlv & 16) <> 0                  AS FullTextData,
    (ctlv & 32) <> 0                  AS RangeData,
    (ctlv & 64) = 0                   AS TrackChanges,
    (ctlv & 1) <> 1                   AS [Indexed]

  FROM ClassProperties cp JOIN Classes c ON c.ClassID = cp.ClassID;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesEasyInsert]
INSTEAD OF INSERT ON [ClassPropertiesEasy]
FOR EACH ROW
BEGIN
-- Note that we do not set ColumnAssigned on insert for the sake of performance
  INSERT INTO [ClassProperties] ([ClassID], [PropertyID], [PropertyName], [ctlv], [DefaultValue], [AutoValue])
  VALUES (
    new.[ClassID], new.[PropertyID], nullif(new.[PropertyName],
                                            (SELECT [ClassName]
                                             FROM [Classes]
                                             WHERE [ClassID] = new.[PropertyID]
                                             LIMIT 1)),
    new.[Indexed] |
    (CASE WHEN new.[ReferenceKind] <> 0 THEN 1 | new.[ReferenceKind]
     ELSE 0 END)
    | (CASE WHEN new.[FullTextData] THEN 16
       ELSE 0 END)
    | (CASE WHEN new.[RangeData] THEN 32
       ELSE 0 END)
    | (CASE WHEN new.[TrackChanges] THEN 0
       ELSE 64 END),
    new.[DefaultValue], new.[AutoValue]
  );

-- Set ColumnAssigned if it is not yet set and new value is not null
  UPDATE [ClassProperties]
  SET [ColumnAssigned] = new.[ColumnAssigned]
  WHERE [ClassID] = new.[ClassID] AND [PropertyID] = new.[PropertyID] AND new.[ColumnAssigned] IS NOT NULL
        AND [ColumnAssigned] IS NULL;
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesEasyUpdate]
INSTEAD OF UPDATE ON [ClassPropertiesEasy]
FOR EACH ROW
BEGIN
  UPDATE [ClassProperties]
  SET
    [ClassID]      = new.[ClassID], [PropertyID] = new.[PropertyID], [PropertyName] = nullif(new.[PropertyName],
                                                                                             (SELECT [ClassName]
                                                                                              FROM [Classes]
                                                                                              WHERE
                                                                                                [ClassID] =
                                                                                                new.[PropertyID]
                                                                                              LIMIT 1)),
    [ctlv]         = new.[Indexed] |
                     (CASE WHEN new.[ReferenceKind] <> 0 THEN 1 | new.[ReferenceKind]
                      ELSE 0 END)
                     | (CASE WHEN new.[FullTextData] THEN 16
                        ELSE 0 END)
                     | (CASE WHEN new.[RangeData] THEN 32
                        ELSE 0 END)
                     | (CASE WHEN new.[TrackChanges] THEN 0
                        ELSE 64 END),
    [DefaultValue] = new.[DefaultValue],
    [AutoValue]    = new.[AutoValue]
  WHERE [ClassID] = old.[ClassID] AND [PropertyID] = old.[PropertyID];
END;

CREATE TRIGGER IF NOT EXISTS [trigClassPropertiesEasyDelete]
INSTEAD OF DELETE ON [ClassPropertiesEasy]
FOR EACH ROW
BEGIN
  DELETE FROM [ClassProperties]
  WHERE [ClassID] = old.[ClassID] AND [PropertyID] = old.[PropertyID];
END;

------------------------------------------------------------------------------------------
-- FullTextData
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [FullTextData] USING fts4 (

[PropertyID],
[ClassID],
[ObjectID],
[PropertyIndex],
[Value],

tokenize=unicode61
);

------------------------------------------------------------------------------------------
-- FulTextDataByColumn
------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS [DummyObjectColumnData]
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
INSTEAD OF INSERT ON [DummyObjectColumnData]
FOR EACH ROW
BEGIN
  INSERT INTO FullTextData ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
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
INSTEAD OF UPDATE ON [DummyObjectColumnData]
FOR EACH ROW
BEGIN
-- Process full text data based on ctlo
  DELETE FROM FullTextData
  WHERE
    new.[ColumnAssigned] IS NOT NULL AND
    new.oldctlo & (1 << (17 + unicode(new.[ColumnAssigned]) - unicode('A'))) AND typeof(new.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', new.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', new.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', new.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';

  INSERT INTO FullTextData ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
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
INSTEAD OF DELETE ON [DummyObjectColumnData]
FOR EACH ROW
BEGIN
-- Process full text data based on ctlo
  DELETE FROM FullTextData
  WHERE
    old.[ColumnAssigned] IS NOT NULL AND
    old.oldctlo & (1 << (17 + unicode(old.[ColumnAssigned]) - unicode('A'))) AND typeof(old.[oldValue]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[ColumnAssigned])
    AND [ClassID] MATCH printf('#%s#', old.[oldClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[oldObjectID])
    AND [PropertyIndex] MATCH '#0#';
END;
------------------------------------------------------------------------------------------
-- Objects
------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS [Objects] (
  [ObjectID] INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  [ClassID]  INTEGER NOT NULL CONSTRAINT [fkObjectsClassIDToClasses] REFERENCES [Classes] ([ClassID]) ON DELETE CASCADE ON UPDATE CASCADE,

/*
This is bit mask which regulates index storage.
Bit 0: this object is a WEAK object and must be auto deleted after last reference to this object gets deleted.
Bits 1-16: columns A-P should be indexed for fast lookup. These bits are checked by partial indexes
Bits 17-32: columns A-P should be indexed for full text search
Bits 33-48: columns A-P should be treated as range values and indexed for range (spatial search) search
Bit 49: DON'T track changes
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

CREATE INDEX IF NOT EXISTS [idxObjectsByClassID] ON [Objects] ([ClassID]);

CREATE INDEX IF NOT EXISTS [idxObjectsByA] ON [Objects] ([ClassID], [A]) WHERE (ctlo AND (1 << 1)) <> 0 AND [A] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByB] ON [Objects] ([ClassID], [B]) WHERE (ctlo AND (1 << 2)) <> 0 AND [B] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByC] ON [Objects] ([ClassID], [C]) WHERE (ctlo AND (1 << 3)) <> 0 AND [C] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByD] ON [Objects] ([ClassID], [D]) WHERE (ctlo AND (1 << 4)) <> 0 AND [D] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByE] ON [Objects] ([ClassID], [E]) WHERE (ctlo AND (1 << 5)) <> 0 AND [E] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByF] ON [Objects] ([ClassID], [F]) WHERE (ctlo AND (1 << 6)) <> 0 AND [F] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByG] ON [Objects] ([ClassID], [G]) WHERE (ctlo AND (1 << 7)) <> 0 AND [G] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByH] ON [Objects] ([ClassID], [H]) WHERE (ctlo AND (1 << 8)) <> 0 AND [H] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByI] ON [Objects] ([ClassID], [I]) WHERE (ctlo AND (1 << 9)) <> 0 AND [I] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByJ] ON [Objects] ([ClassID], [J]) WHERE (ctlo AND (1 << 10)) <> 0 AND [J] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByK] ON [Objects] ([ClassID], [K]) WHERE (ctlo AND (1 << 11)) <> 0 AND [K] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByL] ON [Objects] ([ClassID], [L]) WHERE (ctlo AND (1 << 12)) <> 0 AND [L] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByM] ON [Objects] ([ClassID], [M]) WHERE (ctlo AND (1 << 13)) <> 0 AND [M] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByN] ON [Objects] ([ClassID], [N]) WHERE (ctlo AND (1 << 14)) <> 0 AND [N] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByO] ON [Objects] ([ClassID], [O]) WHERE (ctlo AND (1 << 15)) <> 0 AND [O] IS NOT NULL;

CREATE INDEX IF NOT EXISTS [idxObjectsByP] ON [Objects] ([ClassID], [P]) WHERE (ctlo AND (1 << 16)) <> 0 AND [P] IS NOT NULL;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterInsert]
AFTER INSERT
ON [Objects]
FOR EACH ROW
BEGIN
-- ??? force ctlo. WIll it work?
  UPDATE Objects
  SET ctlo = coalesce(new.ctlo, (SELECT [ctlo]
                                 FROM [Classes]
                                 WHERE [ClassID] = new.[ClassID]))
  WHERE ObjectID = new.[ObjectID];

  INSERT INTO [ChangeLog] ([Key], [Value])
    SELECT
      printf('@%s.%s', new.[ClassID], new.[ObjectID]),
      printf('{ %s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s }',
             '"A": ' || CASE WHEN new.A IS NULL THEN NULL
                        ELSE quote(new.A) END || ', ',
             '"B": ' || CASE WHEN new.B IS NULL THEN NULL
                        ELSE quote(new.B) END || ', ',
             '"C": ' || CASE WHEN new.C IS NULL THEN NULL
                        ELSE quote(new.C) END || ', ',
             '"D": ' || CASE WHEN new.D IS NULL THEN NULL
                        ELSE quote(new.D) END || ', ',
             '"E": ' || CASE WHEN new.E IS NULL THEN NULL
                        ELSE quote(new.E) END || ', ',
             '"F": ' || CASE WHEN new.F IS NULL THEN NULL
                        ELSE quote(new.F) END || ', ',
             '"G": ' || CASE WHEN new.G IS NULL THEN NULL
                        ELSE quote(new.G) END || ', ',
             '"H": ' || CASE WHEN new.H IS NULL THEN NULL
                        ELSE quote(new.H) END || ', ',
             '"I": ' || CASE WHEN new.I IS NULL THEN NULL
                        ELSE quote(new.I) END || ', ',
             '"J": ' || CASE WHEN new.J IS NULL THEN NULL
                        ELSE quote(new.J) END || ', ',
             '"K": ' || CASE WHEN new.K IS NULL THEN NULL
                        ELSE quote(new.K) END || ', ',
             '"L": ' || CASE WHEN new.L IS NULL THEN NULL
                        ELSE quote(new.L) END || ', ',
             '"M": ' || CASE WHEN new.M IS NULL THEN NULL
                        ELSE quote(new.M) END || ', ',
             '"N": ' || CASE WHEN new.N IS NULL THEN NULL
                        ELSE quote(new.N) END || ', ',
             '"O": ' || CASE WHEN new.O IS NULL THEN NULL
                        ELSE quote(new.O) END || ', ',
             '"P": ' || CASE WHEN new.P IS NULL THEN NULL
                        ELSE quote(new.P) END || ', ',
             '"ctlo": ' || CASE WHEN new.ctlo IS NULL THEN NULL
                           ELSE quote(new.ctlo) END)
    WHERE new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49);

-- Full text and range data using INSTEAD OF triggers of dummy view
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'A', new.[A]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'B', new.[B]
    );

  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'C', new.[C]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'D', new.[D]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'E', new.[E]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'F', new.[F]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'G', new.[G]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'H', new.[H]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'I', new.[I]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'J', new.[J]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'K', new.[K]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'L', new.[L]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'M', new.[M]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'N', new.[N]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'O', new.[O]
    );
  INSERT INTO [DummyObjectColumnData] ([ClassID], [ObjectID], [ctlo], [ColumnAssigned], [Value]) VALUES
    (
      new.[ClassID], new.[ObjectID], new.[ctlo], 'P', new.[P]
    );
END;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdate]
AFTER UPDATE
ON [Objects]
FOR EACH ROW
BEGIN
  INSERT INTO ChangeLog ([OldKey], [OldValue], [Key], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [Key],
      [Value]
    FROM
      (SELECT
         '@' || cast(nullif(old.ClassID, new.ClassID) AS TEXT) || '.' ||
         cast(nullif(old.ObjectID, new.[ObjectID]) AS TEXT) AS [OldKey],
         printf('{%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s}',
                ' "A": ' || nullif(quote(old.A), quote(new.A)) || ', ',
                ' "B": ' || nullif(quote(old.B), quote(new.B)) || ', ',
                ' "C": ' || nullif(quote(old.C), quote(new.C)) || ', ',
                ' "D": ' || nullif(quote(old.D), quote(new.D)) || ', ',
                ' "E": ' || nullif(quote(old.E), quote(new.E)) || ', ',
                ' "F": ' || nullif(quote(old.F), quote(new.F)) || ', ',
                ' "G": ' || nullif(quote(old.G), quote(new.G)) || ', ',
                ' "H": ' || nullif(quote(old.H), quote(new.H)) || ', ',
                ' "I": ' || nullif(quote(old.I), quote(new.I)) || ', ',
                ' "J": ' || nullif(quote(old.J), quote(new.J)) || ', ',
                ' "K": ' || nullif(quote(old.K), quote(new.K)) || ', ',
                ' "L": ' || nullif(quote(old.L), quote(new.L)) || ', ',
                ' "M": ' || nullif(quote(old.M), quote(new.M)) || ', ',
                ' "N": ' || nullif(quote(old.N), quote(new.N)) || ', ',
                ' "O": ' || nullif(quote(old.O), quote(new.O)) || ', ',
                ' "P": ' || nullif(quote(old.P), quote(new.P)) || ', ',
                ' "ctlo": ' || nullif(quote(old.ctlo), quote(new.ctlo)) || ' '
         )                                                  AS [OldValue],
         printf('@%s.%s', new.[ClassID], new.[ObjectID])    AS [Key],
         printf('{%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s}',
                ' "A": ' || nullif(quote(new.A), quote(old.A)) || ', ',
                ' "B": ' || nullif(quote(new.B), quote(old.B)) || ', ',
                ' "C": ' || nullif(quote(new.C), quote(old.C)) || ', ',
                ' "D": ' || nullif(quote(new.D), quote(old.D)) || ', ',
                ' "E": ' || nullif(quote(new.E), quote(old.E)) || ', ',
                ' "F": ' || nullif(quote(new.F), quote(old.F)) || ', ',
                ' "G": ' || nullif(quote(new.G), quote(old.G)) || ', ',
                ' "H": ' || nullif(quote(new.H), quote(old.H)) || ', ',
                ' "I": ' || nullif(quote(new.I), quote(old.I)) || ', ',
                ' "J": ' || nullif(quote(new.J), quote(old.J)) || ', ',
                ' "K": ' || nullif(quote(new.K), quote(old.K)) || ', ',
                ' "L": ' || nullif(quote(new.L), quote(old.L)) || ', ',
                ' "M": ' || nullif(quote(new.M), quote(old.M)) || ', ',
                ' "N": ' || nullif(quote(new.N), quote(old.N)) || ', ',
                ' "O": ' || nullif(quote(new.O), quote(old.O)) || ', ',
                ' "P": ' || nullif(quote(new.P), quote(old.P)) || ', ',
                ' "ctlo": ' || nullif(quote(new.ctlo), quote(old.ctlo)) || ' '
         )                                                  AS [Value]
      )
    WHERE (new.[ctlo] IS NULL OR new.[ctlo] & (1 << 49))
          AND ([OldValue] <> [Value] OR (nullif([OldKey], [Key])) IS NOT NULL);

-- Update columns' full text and range data using dummy view with INSTEAD OF triggers
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'A', [oldValue] = old.[A],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'A', [Value] = new.[A],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'B', [oldValue] = old.[B],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'B', [Value] = new.[B],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'C', [oldValue] = old.[C],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'C', [Value] = new.[C],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'D', [oldValue] = old.[D],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'D', [Value] = new.[D],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'E', [oldValue] = old.[E],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'E', [Value] = new.[E],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'F', [oldValue] = old.[F],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'F', [Value] = new.[F],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'G', [oldValue] = old.[G],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'G', [Value] = new.[G],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'H', [oldValue] = old.[H],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'H', [Value] = new.[H],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'I', [oldValue] = old.[I],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'I', [Value] = new.[I],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'J', [oldValue] = old.[J],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'J', [Value] = new.[J],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'K', [oldValue] = old.[K],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'K', [Value] = new.[K],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'L', [oldValue] = old.[L],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'L', [Value] = new.[L],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'M', [oldValue] = old.[M],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'M', [Value] = new.[M],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'N', [oldValue] = old.[N],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'N', [Value] = new.[N],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'O', [oldValue] = old.[O],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'O', [Value] = new.[O],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];
  UPDATE [DummyObjectColumnData]
  SET [oldClassID] = old.[ClassID], [oldObjectID] = old.[ObjectID], [ColumnAssigned] = 'P', [oldValue] = old.[P],
    [ClassID]      = new.[ClassID], [ObjectID] = new.[ObjectID], [ColumnAssigned] = 'P', [Value] = new.[P],
    [oldctlo]      = old.[ctlo], [ctlo] = new.[ctlo];

END;

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdateOfClassID_ObjectID]
AFTER UPDATE OF [ClassID], [ObjectID]
ON [Objects]
FOR EACH ROW
BEGIN
-- Force updating indexes for direct columns
  UPDATE Objects
  SET ctlo = new.ctlo
  WHERE ObjectID = new.[ObjectID];

-- Cascade update values
  UPDATE [Values]
  SET ObjectID = new.[ObjectID], ClassID = new.ClassID
  WHERE ObjectID = old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID OR new.ClassID <> old.ClassID);

-- and shifted values
  UPDATE [Values]
  SET ObjectID = (1 << 62) | new.[ObjectID], ClassID = new.ClassID
  WHERE ObjectID = (1 << 62) | old.ObjectID
        AND (new.[ObjectID] <> old.ObjectID OR new.ClassID <> old.ClassID);

-- Update back references
  UPDATE [Values]
  SET [Value] = new.[ObjectID]
  WHERE [Value] = old.ObjectID AND ctlv IN (0, 10) AND new.[ObjectID] <> old.ObjectID;
END;

/*
CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterUpdateOfctlo]
AFTER UPDATE OF [ctlo]
ON [Objects]
FOR EACH ROW
BEGIN
-- A-P: delete from FullTextData

-- A-P: insert into FullTextData

-- A-P: delete from RangeData

-- A-P: insert into RangeData
END;
*/

CREATE TRIGGER IF NOT EXISTS [trigObjectsAfterDelete]
AFTER DELETE
ON [Objects]
FOR EACH ROW
BEGIN
  INSERT INTO [ChangeLog] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s', old.[ClassID], old.[ObjectID]),
      printf('{%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s}',
             ' "A": ' || CASE WHEN old.A IS NULL THEN NULL
                         ELSE quote(old.A) END || ', ',
             ' "B": ' || CASE WHEN old.B IS NULL THEN NULL
                         ELSE quote(old.B) END || ', ',
             ' "C": ' || CASE WHEN old.C IS NULL THEN NULL
                         ELSE quote(old.C) END || ', ',
             ' "D": ' || CASE WHEN old.D IS NULL THEN NULL
                         ELSE quote(old.D) END || ', ',
             ' "E": ' || CASE WHEN old.E IS NULL THEN NULL
                         ELSE quote(old.E) END || ', ',
             ' "F": ' || CASE WHEN old.F IS NULL THEN NULL
                         ELSE quote(old.F) END || ', ',
             ' "G": ' || CASE WHEN old.G IS NULL THEN NULL
                         ELSE quote(old.G) END || ', ',
             ' "H": ' || CASE WHEN old.H IS NULL THEN NULL
                         ELSE quote(old.H) END || ', ',
             ' "I": ' || CASE WHEN old.I IS NULL THEN NULL
                         ELSE quote(old.I) END || ', ',
             ' "J": ' || CASE WHEN old.J IS NULL THEN NULL
                         ELSE quote(old.J) END || ', ',
             ' "K": ' || CASE WHEN old.K IS NULL THEN NULL
                         ELSE quote(old.K) END || ', ',
             ' "L": ' || CASE WHEN old.L IS NULL THEN NULL
                         ELSE quote(old.L) END || ', ',
             ' "M": ' || CASE WHEN old.M IS NULL THEN NULL
                         ELSE quote(old.M) END || ', ',
             ' "N": ' || CASE WHEN old.N IS NULL THEN NULL
                         ELSE quote(old.N) END || ', ',
             ' "O": ' || CASE WHEN old.O IS NULL THEN NULL
                         ELSE quote(old.O) END || ', ',
             ' "P": ' || CASE WHEN old.P IS NULL THEN NULL
                         ELSE quote(old.P) END || ', ',
             ' "ctlo": ' || CASE WHEN old.ctlo IS NULL THEN NULL
                            ELSE quote(old.ctlo) END
      )
    WHERE old.[ctlo] IS NULL OR old.[ctlo] & (1 << 49);

-- Delete all objects that are referenced from this object and marked for cascade delete (ctlv = 10)
  DELETE FROM Objects
  WHERE ObjectID IN (SELECT Value
                     FROM [Values]
                     WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID) AND ctlv = 10);

-- Delete all reversed references
  DELETE FROM [Values]
  WHERE [Value] = ObjectID AND [ctlv] IN (0, 10);

-- Delete all Values
  DELETE FROM [Values]
  WHERE ObjectID IN (old.ObjectID, (1 << 62) | old.ObjectID);

-- Delete full text and range data using dummy view with INSTEAD OF triggers
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'A';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'B';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'C';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'D';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'E';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'F';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'G';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'H';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'I';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'J';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'K';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'L';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'M';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'N';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'O';
  DELETE FROM [DummyObjectColumnData]
  WHERE [oldClassID] = old.[ClassID] AND [oldObjectID] = old.[ObjectID] AND [oldctlo] = old.[ctlo]
        AND [ColumnAssigned] = 'P';

END;

------------------------------------------------------------------------------------------
-- RangeData
------------------------------------------------------------------------------------------
CREATE VIRTUAL TABLE IF NOT EXISTS [RangeData] USING rtree (
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
CREATE TABLE IF NOT EXISTS [Values] (
  [ObjectID]   INTEGER NOT NULL,
  [PropertyID] INTEGER NOT NULL,
  [PropIndex]  INTEGER NOT NULL DEFAULT 0,
  [Value]              NOT NULL,
  [ClassID]    INTEGER NOT NULL,

/*
ctlv is used for index control. Possible values (the same as ClassProperties.ctlv):
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

CREATE INDEX IF NOT EXISTS [idxClassReversedRefs] ON [Values] ([Value], [PropertyID]) WHERE [ctlv] & 14;

CREATE INDEX IF NOT EXISTS [idxValuesByClassPropValue] ON [Values] ([PropertyID], [ClassID], [Value]) WHERE ([ctlv] & 1);

CREATE TRIGGER IF NOT EXISTS [trigValuesAfterInsert]
AFTER INSERT
ON [Values]
FOR EACH ROW
BEGIN
  INSERT INTO [ChangeLog] ([Key], [Value])
    SELECT
      printf('@%s.%s/%s[%s]#%s',
             new.[ClassID], new.[ObjectID], new.[PropertyID], new.PropIndex,
             new.ctlv),
      new.[Value]
    WHERE (new.[ctlv] & 64) <> 64;

  INSERT INTO FullTextData ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
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
ON [Values]
FOR EACH ROW
BEGIN
  INSERT INTO [ChangeLog] ([OldKey], [OldValue], [Key], [Value])
    SELECT
      [OldKey],
      [OldValue],
      [Key],
      [Value]
    FROM
      (SELECT
/* Each piece of old key is formatted independently so that for cases when old and new value is the same,
result will be null and will be placed to OldKey as empty string */
         printf('%s%s%s%s%s',
                '@' || cast(nullif(old.[ClassID], new.[ClassID]) AS TEXT),
                '.' || cast(nullif(old.[ObjectID], new.[ObjectID]) AS TEXT),
                '/' || cast(nullif(old.[PropertyID], new.[PropertyID]) AS TEXT),
                '[' || cast(nullif(old.[PropIndex], new.[PropIndex]) AS TEXT) || ']',
                '#' || cast(nullif(old.[ctlv], new.[ctlv]) AS TEXT)
         )                                                         AS [OldKey],
         old.[Value]                                               AS [OldValue],
         printf('@%s.%s/%s[%s]%s',
                new.[ClassID], new.[ObjectID], new.[PropertyID], new.PropIndex,
                '#' || cast(nullif(new.ctlv, old.[ctlv]) AS TEXT)) AS [Key],
         new.[Value]                                               AS [Value])
    WHERE (new.[ctlv] & 64) <> 64 AND ([OldValue] <> [Value] OR (nullif([OldKey], [Key])) IS NOT NULL);

-- Process full text data based on ctlv
  DELETE FROM FullTextData
  WHERE
    old.ctlv & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ClassID] MATCH printf('#%s#', old.[ClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);

  INSERT INTO FullTextData ([PropertyID], [ClassID], [ObjectID], [PropertyIndex], [Value])
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
ON [Values]
FOR EACH ROW
BEGIN
  INSERT INTO [ChangeLog] ([OldKey], [OldValue])
    SELECT
      printf('@%s.%s/%s[%s]',
             old.[ClassID], old.[ObjectID], old.[PropertyID],
             old.PropIndex),
      old.[Value]
    WHERE (old.[ctlv] & 64) <> 64;

-- Delete weak referenced object in case this Value record was last reference to that object
  DELETE FROM Objects
  WHERE old.ctlv IN (3) AND ObjectID = old.Value AND
        (ctlo & 1) = 1 AND (SELECT count(*)
                            FROM [Values]
                            WHERE [Value] = ObjectID AND ctlv IN (3)) = 0;

-- Process full text data based on ctlv
  DELETE FROM FullTextData
  WHERE
    old.[ctlv] & 16 AND typeof(old.[Value]) = 'text'
    AND [PropertyID] MATCH printf('#%s#', old.[PropertyID])
    AND [ClassID] MATCH printf('#%s#', old.[ClassID])
    AND [ObjectID] MATCH printf('#%s#', old.[ObjectID])
    AND [PropertyIndex] MATCH printf('#%s#', old.[PropIndex]);

-- Process range data based on ctlv
END;

--------------------------------------------------------------------------------------------
-- ValuesEasy
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS ValuesEasy AS
  SELECT
    NULL AS [ClassName],
    NULL AS [HostID],
    NULL AS [ObjectID],
    NULL AS [PropertyName],
    NULL AS [PropertyIndex],
    NULL AS [Value];

CREATE TRIGGER IF NOT EXISTS trigValuesEasy_Insert INSTEAD OF INSERT
ON [ValuesEasy]
FOR EACH ROW
BEGIN
  INSERT OR REPLACE INTO Objects (ClassID, ObjectID, ctlo, A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P)
    SELECT
      c.ClassID,
      (new.HostID << 31) | new.[ObjectID],

      ctlo = c.ctloMask,

      A = (CASE WHEN p.[ColumnAssigned] = 'A' THEN new.[Value]
           ELSE A END),

      B = (CASE WHEN p.[ColumnAssigned] = 'B' THEN new.[Value]
           ELSE B END),

      C = (CASE WHEN p.[ColumnAssigned] = 'C' THEN new.[Value]
           ELSE C END),

      D = (CASE WHEN p.[ColumnAssigned] = 'D' THEN new.[Value]
           ELSE D END),

      E = (CASE WHEN p.[ColumnAssigned] = 'E' THEN new.[Value]
           ELSE E END),

      F = (CASE WHEN p.[ColumnAssigned] = 'F' THEN new.[Value]
           ELSE F END),

      G = (CASE WHEN p.[ColumnAssigned] = 'G' THEN new.[Value]
           ELSE G END),

      H = (CASE WHEN p.[ColumnAssigned] = 'H' THEN new.[Value]
           ELSE H END),

      I = (CASE WHEN p.[ColumnAssigned] = 'I' THEN new.[Value]
           ELSE I END),

      J = (CASE WHEN p.[ColumnAssigned] = 'J' THEN new.[Value]
           ELSE J END),

      K = (CASE WHEN p.[ColumnAssigned] = 'K' THEN new.[Value]
           ELSE K END),

      L = (CASE WHEN p.[ColumnAssigned] = 'L' THEN new.[Value]
           ELSE L END),

      M = (CASE WHEN p.[ColumnAssigned] = 'M' THEN new.[Value]
           ELSE M END),

      N = (CASE WHEN p.[ColumnAssigned] = 'N' THEN new.[Value]
           ELSE N END),

      O = (CASE WHEN p.[ColumnAssigned] = 'O' THEN new.[Value]
           ELSE O END),

      P = (CASE WHEN p.[ColumnAssigned] = 'P' THEN new.[Value]
           ELSE P END)
    FROM Classes c, ClassPropertiesEasy p
    WHERE c.[ClassID] = p.[ClassID] AND c.ClassName = new.ClassName AND p.PropertyName = new.PropertyName
          AND (p.[ctlv] & 14) = 0 AND p.ColumnAssigned IS NOT NULL AND new.PropertyIndex = 0;

  INSERT OR REPLACE INTO [Values] (ObjectID, ClassID, PropertyID, PropIndex, [Value], ctlv)
    SELECT
      CASE WHEN new.PropertyIndex > 20 THEN new.[ObjectID] | (1 << 62)
      ELSE new.[ObjectID] END,
      c.ClassID,
      p.PropertyID,
      new.PropertyIndex,
      new.[Value],
      p.[ctlv]
    FROM Classes c, ClassPropertiesEasy p
    WHERE c.[ClassID] = p.[ClassID] AND c.ClassName = new.ClassName AND p.PropertyName = new.PropertyName AND
          p.ColumnAssigned IS NULL;
END;

