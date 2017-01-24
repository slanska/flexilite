
--------------------------------------------------------------------------------------------
-- Init default data
--------------------------------------------------------------------------------------------

-- Make sure that there is ID sequence for Objects table
INSERT INTO sqlite_sequence (name, seq) SELECT
                                          'Objects',
                                          0
                                        WHERE NOT exists(SELECT 1
                                                         FROM sqlite_sequence
                                                         WHERE name = 'Objects');

INSERT INTO [.classes] ([ClassName], [SystemClass]) VALUES ('$Application', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('$DBView', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('$UIView', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('$SitePage', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('$SitePageSection', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('Text', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('Culture', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('TextID', 1);

INSERT INTO Classes ([ClassName], [SystemClass]) VALUES ('$TranslatedText', 1);

-- Other system classes
-- $Users
-- $Roles


INSERT INTO ClassProperties ([ClassID], [PropertyID], [ColumnAssigned])
  SELECT
    ClassID,
    (SELECT ClassID
     FROM Classes
     WHERE ClassName = 'TextID'),
    'A'
  FROM Classes
  WHERE ClassName = '$TranslatedText';

INSERT INTO ClassProperties ([ClassID], [PropertyID], [ColumnAssigned])
  SELECT
    ClassID,
    (SELECT ClassID
     FROM Classes
     WHERE ClassName = 'Culture'),
    'B'
  FROM Classes
  WHERE ClassName = '$TranslatedText';

INSERT INTO ClassProperties ([ClassID], [PropertyID], [ColumnAssigned])
  SELECT
    ClassID,
    (SELECT ClassID
     FROM Classes
     WHERE ClassName = 'Text'),
    'C'
  FROM Classes
  WHERE ClassName = '$TranslatedText';

--------------------------------------------------------------------------------------------
-- izTranslatedText helper view. Sample for auto-generated user helper views
--------------------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS izTranslatedText AS
  SELECT
    ObjectID >> 31          AS HostID,
    (ObjectID & 2147483647) AS ObjectID,
    A                       AS TextID,
    B                       AS Culture,
    C                       AS Text
  FROM Objects
  WHERE ClassID = 9;

CREATE TRIGGER IF NOT EXISTS [izTranslatedText_Insert]
INSTEAD OF INSERT
ON [izTranslatedText]
FOR EACH ROW
BEGIN
  INSERT INTO Objects (ObjectID, ClassID, A, B, C)
    SELECT
      coalesce(new.HostID >> 31, [NextID] << 31) | coalesce(new.ObjectID, [NextID]),
      9,
      new.TextID,
      new.Culture,
      new.Text
    FROM (SELECT ([seq] & 2147483647) + 1 AS [NextID]
          FROM sqlite_sequence
          WHERE name = 'Objects');
END;

CREATE TRIGGER IF NOT EXISTS [izTranslatedText_Update]
INSTEAD OF UPDATE
ON [izTranslatedText]
FOR EACH ROW
BEGIN
  UPDATE Objects
  SET ObjectID = (new.ObjectID | (new.HostID << 31)), A = new.TextID, B = new.Culture, C = new.Text
  WHERE ObjectID = (old.ObjectID | (old.HostID << 31));
END;

CREATE TRIGGER IF NOT EXISTS [izTranslatedText_Delete]
INSTEAD OF DELETE
ON [izTranslatedText]
FOR EACH ROW
BEGIN
  DELETE FROM Objects
  WHERE ObjectID = (old.ObjectID | (old.HostID << 31));
END;
